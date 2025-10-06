defmodule AetherATProtoCore.Crypto.DPoPTest do
  use ExUnit.Case, async: true

  alias AetherATProtoCore.Crypto.DPoP

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
end
