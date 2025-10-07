defmodule Aether.ATProto.Crypto.DPoP do
  @moduledoc """
  DPoP (Demonstrating Proof of Possession) implementation for AT Protocol OAuth.

  Handles generation of DPoP proofs and keys according to RFC 9449.
  """

  @doc """
  Generates a new ES256 key pair for DPoP.
  """
  def generate_key do
    jwk = JOSE.JWK.generate_key({:ec, "P-256"})
    JOSE.JWK.to_map(jwk) |> elem(1)
  end

  @doc """
  Calculates the JWK thumbprint (jkt) for a DPoP key.
  Used to verify the access token's cnf claim matches the DPoP proof.
  """
  def calculate_jkt(dpop_key) do
    dpop_key
    |> JOSE.JWK.from_map()
    |> JOSE.JWK.thumbprint()
  end

  @doc """
  Generates a DPoP proof JWT.

  ## Parameters
  - method: HTTP method (e.g., "GET", "POST")
  - url: Target URL
  - dpop_key: JWK map for signing
  - nonce: Optional nonce from authorization server
  - access_token: Optional access token (for resource requests)
  """
  def generate_proof(method, url, dpop_key, nonce \\ nil, access_token \\ nil) do
    jwk = JOSE.JWK.from_map(dpop_key)

    header = %{
      "typ" => "dpop+jwt",
      "alg" => "ES256",
      "jwk" => Map.take(dpop_key, ["kty", "crv", "x", "y"])
    }

    claims =
      %{
        "htm" => method,
        "htu" => url,
        "jti" => generate_jti(),
        "iat" => System.system_time(:second)
      }
      |> maybe_add_nonce(nonce)
      |> maybe_add_ath(access_token)

    {_modules, jwt} = JOSE.JWT.sign(jwk, header, claims)
    JOSE.JWS.compact(jwt) |> elem(1)
  end

  defp maybe_add_nonce(claims, nil), do: claims
  defp maybe_add_nonce(claims, nonce), do: Map.put(claims, "nonce", nonce)

  defp maybe_add_ath(claims, nil), do: claims

  defp maybe_add_ath(claims, access_token) do
    ath = :crypto.hash(:sha256, access_token) |> Base.url_encode64(padding: false)
    Map.put(claims, "ath", ath)
  end

  defp generate_jti do
    :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false)
  end

  @doc """
  Verifies a DPoP proof JWT (server-side validation).

  ## Parameters
  - dpop_jwt: The DPoP proof JWT from the client
  - method: Expected HTTP method (e.g., "POST")
  - url: Expected target URL
  - access_token: Optional access token to verify ath claim

  ## Returns
  - {:ok, dpop_key} - The JWK from the proof if valid
  - {:error, reason} - If verification fails
  """
  def verify_proof(dpop_jwt, method, url, access_token \\ nil) do
    with {:ok, header, claims} <- decode_and_parse(dpop_jwt),
         :ok <- verify_typ(header),
         {:ok, jwk} <- extract_jwk(header),
         :ok <- verify_signature(dpop_jwt, jwk),
         :ok <- verify_claims(claims, method, url, access_token) do
      # Return the JWK map (not the JOSE.JWK struct)
      {:ok, JOSE.JWK.to_map(jwk) |> elem(1)}
    end
  end

  @doc """
  Extracts the JWK thumbprint from a DPoP proof without full verification.
  Useful for quick binding checks.
  """
  def extract_jkt(dpop_jwt) do
    with {:ok, header, _claims} <- decode_and_parse(dpop_jwt),
         {:ok, jwk} <- extract_jwk(header) do
      {:ok, calculate_jkt(JOSE.JWK.to_map(jwk) |> elem(1))}
    end
  end

  # Private verification functions

  defp decode_and_parse(dpop_jwt) do
    case String.split(dpop_jwt, ".") do
      [header_b64, payload_b64, _sig_b64] ->
        with {:ok, header_json} <- Base.url_decode64(header_b64, padding: false),
             {:ok, header} <- Jason.decode(header_json),
             {:ok, payload_json} <- Base.url_decode64(payload_b64, padding: false),
             {:ok, claims} <- Jason.decode(payload_json) do
          {:ok, header, claims}
        else
          _ -> {:error, :invalid_jwt_format}
        end

      _ ->
        {:error, :invalid_jwt_format}
    end
  end

  defp verify_typ(%{"typ" => "dpop+jwt"}), do: :ok
  defp verify_typ(_), do: {:error, :invalid_typ}

  defp extract_jwk(%{"jwk" => jwk_map}) when is_map(jwk_map) do
    # Reconstruct JWK from the header
    try do
      {:ok, JOSE.JWK.from_map(jwk_map)}
    rescue
      _ -> {:error, :invalid_jwk}
    end
  end

  defp extract_jwk(_), do: {:error, :missing_jwk}

  defp verify_signature(dpop_jwt, jwk) do
    case JOSE.JWT.verify_strict(jwk, ["ES256"], dpop_jwt) do
      {true, _jwt, _jws} -> :ok
      {false, _, _} -> {:error, :invalid_signature}
    end
  end

  defp verify_claims(claims, method, url, access_token) do
    with :ok <- verify_htm(claims, method),
         :ok <- verify_htu(claims, url),
         :ok <- verify_iat(claims),
         :ok <- verify_jti(claims),
         :ok <- verify_ath(claims, access_token) do
      :ok
    end
  end

  defp verify_htm(%{"htm" => htm}, expected_method) when htm == expected_method, do: :ok
  defp verify_htm(_, _), do: {:error, :htm_mismatch}

  defp verify_htu(%{"htu" => htu}, expected_url) when htu == expected_url, do: :ok
  defp verify_htu(_, _), do: {:error, :htu_mismatch}

  defp verify_iat(%{"iat" => iat}) when is_integer(iat) do
    now = System.system_time(:second)

    # Accept timestamps within 60 seconds (past or future for clock skew)
    if abs(now - iat) < 60 do
      :ok
    else
      {:error, :invalid_timestamp}
    end
  end

  defp verify_iat(_), do: {:error, :missing_iat}

  defp verify_jti(%{"jti" => jti}) when is_binary(jti) and byte_size(jti) > 0, do: :ok
  defp verify_jti(_), do: {:error, :missing_jti}

  defp verify_ath(_claims, nil) do
    # If no access token expected, ath should not be present (token endpoint)
    # or can be present (resource server)
    :ok
  end

  defp verify_ath(%{"ath" => ath}, access_token) when is_binary(ath) do
    expected_ath =
      :crypto.hash(:sha256, access_token)
      |> Base.url_encode64(padding: false)

    if ath == expected_ath do
      :ok
    else
      {:error, :invalid_ath}
    end
  end

  defp verify_ath(_, access_token) when is_binary(access_token) do
    # Access token provided but no ath claim
    {:error, :missing_ath}
  end

  defp verify_ath(_, _), do: :ok
end
