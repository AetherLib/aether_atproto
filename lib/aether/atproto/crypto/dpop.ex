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
end
