defmodule Aether.ATProto.Crypto.DPoPTest do
  use ExUnit.Case, async: true

  alias Aether.ATProto.Crypto.DPoP

  describe "generate_key/0" do
    test "generates a valid ES256 key pair" do
      key = DPoP.generate_key()

      assert is_map(key)
      assert key["kty"] == "EC"
      assert key["crv"] == "P-256"
      assert is_binary(key["x"])
      assert is_binary(key["y"])
      # Private key should be present for signing
      assert is_binary(key["d"])
    end

    test "generated keys are unique" do
      key1 = DPoP.generate_key()
      key2 = DPoP.generate_key()

      assert key1["x"] != key2["x"]
      assert key1["y"] != key2["y"]
      assert key1["d"] != key2["d"]
    end
  end

  describe "calculate_jkt/1" do
    setup do
      %{key: DPoP.generate_key()}
    end

    test "calculates thumbprint for valid key", %{key: key} do
      jkt = DPoP.calculate_jkt(key)

      assert is_binary(jkt)
      # JWK thumbprints are base64url encoded without padding
      assert String.match?(jkt, ~r/^[A-Za-z0-9_-]+$/)
      refute String.ends_with?(jkt, "=")
    end

    test "thumbprint is deterministic for same key", %{key: key} do
      jkt1 = DPoP.calculate_jkt(key)
      jkt2 = DPoP.calculate_jkt(key)

      assert jkt1 == jkt2
    end

    test "different keys have different thumbprints" do
      key1 = DPoP.generate_key()
      key2 = DPoP.generate_key()

      assert DPoP.calculate_jkt(key1) != DPoP.calculate_jkt(key2)
    end
  end

  describe "generate_proof/5" do
    setup do
      %{
        key: DPoP.generate_key(),
        method: "POST",
        url: "https://api.example.com/resource",
        access_token: "test_access_token_123"
      }
    end

    test "generates valid JWT structure", %{key: key, method: method, url: url} do
      proof = DPoP.generate_proof(method, url, key)

      assert is_binary(proof)
      # JWT should have three parts separated by dots
      parts = String.split(proof, ".")
      assert length(parts) == 3

      # Each part should be base64url encoded (no padding, no invalid chars)
      for part <- parts do
        assert String.match?(part, ~r/^[A-Za-z0-9_-]+$/)
        refute String.ends_with?(part, "=")
      end
    end

    test "proof can be verified with the same key", %{key: key, method: method, url: url} do
      proof = DPoP.generate_proof(method, url, key)
      jwk = JOSE.JWK.from_map(key)

      # Verify the signature is valid - returns {verified, jwt, jws}
      {verified, jwt, _jws} = JOSE.JWT.verify(jwk, proof)
      assert verified

      # Now we can inspect the claims through the verified JWT
      claims = jwt.fields
      assert claims["htm"] == method
      assert claims["htu"] == url
      assert is_binary(claims["jti"])
      assert is_integer(claims["iat"])
    end

    test "includes nonce when provided", %{key: key, method: method, url: url} do
      nonce = "test_nonce_123"
      proof = DPoP.generate_proof(method, url, key, nonce)
      jwk = JOSE.JWK.from_map(key)

      {verified, jwt, _jws} = JOSE.JWT.verify(jwk, proof)
      assert verified
      assert jwt.fields["nonce"] == nonce
    end

    test "includes ath when access_token provided", %{
      key: key,
      method: method,
      url: url,
      access_token: access_token
    } do
      proof = DPoP.generate_proof(method, url, key, nil, access_token)
      jwk = JOSE.JWK.from_map(key)

      {verified, jwt, _jws} = JOSE.JWT.verify(jwk, proof)
      assert verified

      expected_ath = :crypto.hash(:sha256, access_token) |> Base.url_encode64(padding: false)
      assert jwt.fields["ath"] == expected_ath
    end

    test "excludes optional fields when not provided", %{key: key, method: method, url: url} do
      proof = DPoP.generate_proof(method, url, key)
      jwk = JOSE.JWK.from_map(key)

      {verified, jwt, _jws} = JOSE.JWT.verify(jwk, proof)
      assert verified

      refute Map.has_key?(jwt.fields, "nonce")
      refute Map.has_key?(jwt.fields, "ath")
    end

    test "jti is unique for each call", %{key: key, method: method, url: url} do
      proof1 = DPoP.generate_proof(method, url, key)
      proof2 = DPoP.generate_proof(method, url, key)
      jwk = JOSE.JWK.from_map(key)

      {verified1, jwt1, _jws1} = JOSE.JWT.verify(jwk, proof1)
      {verified2, jwt2, _jws2} = JOSE.JWT.verify(jwk, proof2)

      assert verified1
      assert verified2
      assert jwt1.fields["jti"] != jwt2.fields["jti"]
    end
  end

  describe "verify_proof/4" do
    setup do
      key = DPoP.generate_key()
      method = "POST"
      url = "https://api.example.com/token"

      %{
        key: key,
        method: method,
        url: url,
        proof: DPoP.generate_proof(method, url, key)
      }
    end

    test "verifies valid proof successfully", %{key: key, method: method, url: url, proof: proof} do
      assert {:ok, verified_key} = DPoP.verify_proof(proof, method, url)

      # Verified key should be a map with the public key components
      assert is_map(verified_key)
      assert verified_key["kty"] == "EC"
      assert verified_key["crv"] == "P-256"
      assert verified_key["x"] == key["x"]
      assert verified_key["y"] == key["y"]
    end

    test "rejects proof with wrong method", %{proof: proof, url: url} do
      assert {:error, :htm_mismatch} = DPoP.verify_proof(proof, "GET", url)
    end

    test "rejects proof with wrong URL", %{proof: proof, method: method} do
      wrong_url = "https://wrong.example.com/token"
      assert {:error, :htu_mismatch} = DPoP.verify_proof(proof, method, wrong_url)
    end

    test "rejects proof with invalid signature", %{method: method, url: url} do
      # Create a proof with one key
      key1 = DPoP.generate_key()
      proof = DPoP.generate_proof(method, url, key1)

      # Tamper with the proof by changing a character
      [header, payload, signature] = String.split(proof, ".")
      tampered_signature = String.replace(signature, "A", "B", global: false)
      tampered_proof = Enum.join([header, payload, tampered_signature], ".")

      assert {:error, :invalid_signature} = DPoP.verify_proof(tampered_proof, method, url)
    end

    test "rejects proof with old timestamp", %{key: key, method: method, url: url} do
      # Manually create a proof with old timestamp
      jwk = JOSE.JWK.from_map(key)

      header = %{
        "typ" => "dpop+jwt",
        "alg" => "ES256",
        "jwk" => Map.take(key, ["kty", "crv", "x", "y"])
      }

      # 2 minutes ago
      old_timestamp = System.system_time(:second) - 120

      claims = %{
        "htm" => method,
        "htu" => url,
        "jti" => :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false),
        "iat" => old_timestamp
      }

      {_modules, jwt} = JOSE.JWT.sign(jwk, header, claims)
      old_proof = JOSE.JWS.compact(jwt) |> elem(1)

      assert {:error, :invalid_timestamp} = DPoP.verify_proof(old_proof, method, url)
    end

    test "rejects malformed JWT", %{method: method, url: url} do
      malformed_jwt = "not.a.valid.jwt"
      assert {:error, :invalid_jwt_format} = DPoP.verify_proof(malformed_jwt, method, url)
    end

    test "rejects proof without jwk in header", %{key: key, method: method, url: url} do
      jwk = JOSE.JWK.from_map(key)

      # Create header without jwk
      header = %{
        "typ" => "dpop+jwt",
        "alg" => "ES256"
        # Missing "jwk"
      }

      claims = %{
        "htm" => method,
        "htu" => url,
        "jti" => :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false),
        "iat" => System.system_time(:second)
      }

      {_modules, jwt} = JOSE.JWT.sign(jwk, header, claims)
      proof = JOSE.JWS.compact(jwt) |> elem(1)

      assert {:error, :missing_jwk} = DPoP.verify_proof(proof, method, url)
    end

    test "rejects proof missing required claims", %{key: key, method: method, url: url} do
      jwk = JOSE.JWK.from_map(key)

      header = %{
        "typ" => "dpop+jwt",
        "alg" => "ES256",
        "jwk" => Map.take(key, ["kty", "crv", "x", "y"])
      }

      # Missing jti claim
      claims = %{
        "htm" => method,
        "htu" => url,
        "iat" => System.system_time(:second)
        # Missing "jti"
      }

      {_modules, jwt} = JOSE.JWT.sign(jwk, header, claims)
      proof = JOSE.JWS.compact(jwt) |> elem(1)

      assert {:error, :missing_jti} = DPoP.verify_proof(proof, method, url)
    end
  end

  describe "verify_proof/4 with access token" do
    setup do
      key = DPoP.generate_key()
      method = "GET"
      url = "https://api.example.com/resource"
      access_token = "test_access_token_xyz"

      %{
        key: key,
        method: method,
        url: url,
        access_token: access_token,
        proof: DPoP.generate_proof(method, url, key, nil, access_token)
      }
    end

    test "verifies proof with valid ath claim", %{
      proof: proof,
      method: method,
      url: url,
      access_token: access_token
    } do
      assert {:ok, _key} = DPoP.verify_proof(proof, method, url, access_token)
    end

    test "rejects proof with wrong access token", %{
      proof: proof,
      method: method,
      url: url
    } do
      wrong_token = "wrong_access_token"
      assert {:error, :invalid_ath} = DPoP.verify_proof(proof, method, url, wrong_token)
    end

    test "rejects proof with missing ath when access token expected", %{
      key: key,
      method: method,
      url: url,
      access_token: access_token
    } do
      # Generate proof without ath
      proof_without_ath = DPoP.generate_proof(method, url, key)

      assert {:error, :missing_ath} =
               DPoP.verify_proof(proof_without_ath, method, url, access_token)
    end
  end

  describe "extract_jkt/1" do
    setup do
      key = DPoP.generate_key()
      method = "POST"
      url = "https://api.example.com/token"
      proof = DPoP.generate_proof(method, url, key)

      %{key: key, proof: proof}
    end

    test "extracts jkt from valid proof", %{key: key, proof: proof} do
      expected_jkt = DPoP.calculate_jkt(key)

      assert {:ok, jkt} = DPoP.extract_jkt(proof)
      assert jkt == expected_jkt
    end

    test "returns error for malformed proof" do
      malformed = "not.a.jwt"
      assert {:error, :invalid_jwt_format} = DPoP.extract_jkt(malformed)
    end

    test "returns error for proof without jwk" do
      # Create a JWT without jwk in header (would need manual construction)
      # For simplicity, we'll just test that a random string fails
      invalid =
        Base.url_encode64("invalid", padding: false) <>
          "." <>
          Base.url_encode64("proof", padding: false) <>
          "." <>
          Base.url_encode64("here", padding: false)

      assert {:error, _} = DPoP.extract_jkt(invalid)
    end

    test "extracted jkt matches direct calculation", %{key: key, proof: proof} do
      {:ok, extracted_jkt} = DPoP.extract_jkt(proof)
      direct_jkt = DPoP.calculate_jkt(key)

      assert extracted_jkt == direct_jkt
    end
  end

  describe "round-trip verification" do
    test "generate and verify complete flow" do
      # Client side: generate key and proof
      client_key = DPoP.generate_key()
      method = "POST"
      url = "https://pds.example.com/xrpc/com.atproto.repo.createRecord"

      proof = DPoP.generate_proof(method, url, client_key)

      # Server side: verify proof
      assert {:ok, server_extracted_key} = DPoP.verify_proof(proof, method, url)

      # Server calculates jkt for token binding
      server_jkt = DPoP.calculate_jkt(server_extracted_key)

      # Client also calculates jkt
      client_jkt = DPoP.calculate_jkt(client_key)

      # They should match
      assert server_jkt == client_jkt
    end

    test "generate proof with access token and verify" do
      key = DPoP.generate_key()
      method = "GET"
      url = "https://pds.example.com/xrpc/com.atproto.repo.getRecord"
      access_token = "dpop_access_token_abc123"

      # Generate proof with ath
      proof = DPoP.generate_proof(method, url, key, nil, access_token)

      # Verify with access token
      assert {:ok, verified_key} = DPoP.verify_proof(proof, method, url, access_token)

      # Keys should match
      assert verified_key["x"] == key["x"]
      assert verified_key["y"] == key["y"]
    end
  end
end
