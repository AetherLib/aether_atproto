defmodule AetherATProtoCore.DIDTest do
  use ExUnit.Case, async: true
  doctest AetherATProtoCore.DID

  import AetherATProtoCore.DIDFixtures

  describe "parse_did/1" do
    test "parses valid PLC DID" do
      did_string = plc_did()

      assert {:ok, %AetherATProtoCore.DID{}} = AetherATProtoCore.DID.parse_did(did_string)

      assert {:ok, %AetherATProtoCore.DID{method: "plc", identifier: "z72i7hdynmk24r6zlsdc6nxd"}} =
               AetherATProtoCore.DID.parse_did(did_string)
    end

    test "parses valid Web DID" do
      did_string = web_did()

      assert {:ok, %AetherATProtoCore.DID{}} = AetherATProtoCore.DID.parse_did(did_string)

      assert {:ok, %AetherATProtoCore.DID{method: "web", identifier: "example.com"}} =
               AetherATProtoCore.DID.parse_did(did_string)
    end

    test "parses valid Web DID with port" do
      did_string = web_did_with_port()

      assert {:ok, %AetherATProtoCore.DID{}} = AetherATProtoCore.DID.parse_did(did_string)

      assert {:ok, %AetherATProtoCore.DID{method: "web", identifier: "example.com:3000"}} =
               AetherATProtoCore.DID.parse_did(did_string)
    end

    test "parses valid Web DID with path" do
      did_string = "did:web:example.com:user"

      assert {:ok, %AetherATProtoCore.DID{}} = AetherATProtoCore.DID.parse_did(did_string)

      assert {:ok, %AetherATProtoCore.DID{method: "web", identifier: "example.com:user"}} =
               AetherATProtoCore.DID.parse_did(did_string)
    end

    test "parses valid Key DID" do
      did_string = key_did()

      assert {:ok, %AetherATProtoCore.DID{}} = AetherATProtoCore.DID.parse_did(did_string)

      assert {:ok,
              %AetherATProtoCore.DID{
                method: "key",
                identifier: "zQ3shokFTS3brHcDQrn82RUDfCZESWL1ZdCEJwekUDPQiYBme"
              }} = AetherATProtoCore.DID.parse_did(did_string)
    end

    test "parses DID with fragment" do
      did_string = web_did_with_fragment()

      assert {:ok, %AetherATProtoCore.DID{}} = AetherATProtoCore.DID.parse_did(did_string)

      assert {:ok,
              %AetherATProtoCore.DID{method: "web", identifier: "example.com", fragment: "key1"}} =
               AetherATProtoCore.DID.parse_did(did_string)
    end

    test "parses DID with query parameters" do
      did_string = web_did_with_query()

      assert {:ok, %AetherATProtoCore.DID{}} = AetherATProtoCore.DID.parse_did(did_string)

      assert {:ok,
              %AetherATProtoCore.DID{
                method: "web",
                identifier: "example.com",
                query: "version=1",
                params: %{"version" => "1"}
              }} = AetherATProtoCore.DID.parse_did(did_string)
    end

    test "parses DID with fragment and query parameters" do
      did_string = web_did_with_fragment_and_query()

      assert {:ok, %AetherATProtoCore.DID{}} = AetherATProtoCore.DID.parse_did(did_string)

      assert {:ok,
              %AetherATProtoCore.DID{
                method: "web",
                identifier: "example.com",
                query: "version=1",
                fragment: "key1",
                params: %{"version" => "1"}
              }} = AetherATProtoCore.DID.parse_did(did_string)
    end

    test "returns error for invalid DID format" do
      for invalid_did <- invalid_dids() do
        assert {:error, _} = AetherATProtoCore.DID.parse_did(invalid_did)
      end
    end

    test "returns error for unsupported method" do
      assert {:error, :unsupported_method} =
               AetherATProtoCore.DID.parse_did("did:unsupported:identifier")
    end

    test "returns error for invalid PLC identifier" do
      # Too short
      assert {:error, :invalid_identifier} = AetherATProtoCore.DID.parse_did("did:plc:abc123")
      # Invalid characters
      assert {:error, :invalid_identifier} =
               AetherATProtoCore.DID.parse_did("did:plc:z72i7hdynmk24r6zlsdc6nxd!")
    end

    test "returns error for invalid Web identifier" do
      # Invalid domain
      assert {:error, :invalid_identifier} =
               AetherATProtoCore.DID.parse_did("did:web:example..com")

      # Invalid characters
      assert {:error, :invalid_identifier} =
               AetherATProtoCore.DID.parse_did("did:web:example_com")
    end

    test "returns error for invalid Key identifier" do
      # Doesn't start with z
      assert {:error, :invalid_identifier} = AetherATProtoCore.DID.parse_did("did:key:abc123")
      # Invalid multibase characters
      assert {:error, :invalid_identifier} = AetherATProtoCore.DID.parse_did("did:key:z123!")
    end
  end

  describe "parse_did!/1" do
    test "returns DID struct for valid DID" do
      did_string = plc_did()

      did = AetherATProtoCore.DID.parse_did!(did_string)
      assert %AetherATProtoCore.DID{method: "plc", identifier: "z72i7hdynmk24r6zlsdc6nxd"} = did
    end

    test "raises ParseError for invalid DID" do
      assert_raise AetherATProtoCore.DID.ParseError, fn ->
        AetherATProtoCore.DID.parse_did!("invalid")
      end

      assert_raise AetherATProtoCore.DID.ParseError, fn ->
        AetherATProtoCore.DID.parse_did!("did:unsupported:test")
      end
    end

    test "returns DID struct when passed a DID struct" do
      did_struct = %AetherATProtoCore.DID{method: "plc", identifier: "test"}
      assert ^did_struct = AetherATProtoCore.DID.parse_did!(did_struct)
    end
  end

  describe "valid_did?/1" do
    test "returns true for valid DID strings" do
      assert AetherATProtoCore.DID.valid_did?(plc_did())
      assert AetherATProtoCore.DID.valid_did?(web_did())
      assert AetherATProtoCore.DID.valid_did?(key_did())
    end

    test "returns true for DID structs" do
      did_struct = %AetherATProtoCore.DID{method: "plc", identifier: "test"}
      assert AetherATProtoCore.DID.valid_did?(did_struct)
    end

    test "returns false for invalid inputs" do
      for invalid_did <- invalid_dids() do
        refute AetherATProtoCore.DID.valid_did?(invalid_did)
      end

      refute AetherATProtoCore.DID.valid_did?(nil)
      refute AetherATProtoCore.DID.valid_did?(123)
      refute AetherATProtoCore.DID.valid_did?(%{})
    end
  end

  describe "did_to_string/1" do
    test "returns string from DID struct" do
      did = %AetherATProtoCore.DID{method: "plc", identifier: "z72i7hdynmk24r6zlsdc6nxd"}

      assert AetherATProtoCore.DID.did_to_string(did) == "did:plc:z72i7hdynmk24r6zlsdc6nxd"
    end

    test "returns string with fragment" do
      did = %AetherATProtoCore.DID{method: "web", identifier: "example.com", fragment: "key1"}

      assert AetherATProtoCore.DID.did_to_string(did) == "did:web:example.com#key1"
    end

    test "returns string with query parameters" do
      did = %AetherATProtoCore.DID{method: "web", identifier: "example.com", query: "version=1"}

      assert AetherATProtoCore.DID.did_to_string(did) == "did:web:example.com?version=1"
    end

    test "returns string with both fragment and query" do
      did = %AetherATProtoCore.DID{
        method: "web",
        identifier: "example.com",
        query: "version=1",
        fragment: "key1"
      }

      assert AetherATProtoCore.DID.did_to_string(did) == "did:web:example.com?version=1#key1"
    end

    test "returns string when passed a string" do
      did_string = "did:plc:test"
      assert AetherATProtoCore.DID.did_to_string(did_string) == did_string
    end
  end

  describe "did_method/1" do
    test "returns method for DID strings" do
      assert AetherATProtoCore.DID.did_method(plc_did()) == "plc"
      assert AetherATProtoCore.DID.did_method(web_did()) == "web"
      assert AetherATProtoCore.DID.did_method(key_did()) == "key"
    end

    test "returns method for DID structs" do
      did = %AetherATProtoCore.DID{method: "plc", identifier: "test"}
      assert AetherATProtoCore.DID.did_method(did) == "plc"
    end

    test "returns error for invalid DID" do
      assert AetherATProtoCore.DID.did_method("invalid") == {:error, :invalid_did}
    end
  end

  describe "did_identifier/1" do
    test "returns identifier for DID strings" do
      assert AetherATProtoCore.DID.did_identifier(plc_did()) == "z72i7hdynmk24r6zlsdc6nxd"
      assert AetherATProtoCore.DID.did_identifier(web_did()) == "example.com"
    end

    test "returns identifier for DID structs" do
      did = %AetherATProtoCore.DID{method: "plc", identifier: "test"}
      assert AetherATProtoCore.DID.did_identifier(did) == "test"
    end

    test "returns error for invalid DID" do
      assert AetherATProtoCore.DID.did_identifier("invalid") == {:error, :invalid_did}
    end
  end

  describe "is_method?/2" do
    test "returns true for matching method" do
      assert AetherATProtoCore.DID.is_method?(plc_did(), "plc")
      assert AetherATProtoCore.DID.is_method?(web_did(), "web")
    end

    test "returns false for non-matching method" do
      refute AetherATProtoCore.DID.is_method?(plc_did(), "web")
      refute AetherATProtoCore.DID.is_method?(web_did(), "plc")
    end

    test "returns false for invalid DID" do
      refute AetherATProtoCore.DID.is_method?("invalid", "plc")
    end

    test "works with DID structs" do
      did = %AetherATProtoCore.DID{method: "plc", identifier: "test"}
      assert AetherATProtoCore.DID.is_method?(did, "plc")
      refute AetherATProtoCore.DID.is_method?(did, "web")
    end
  end

  describe "did_fragment/1" do
    test "returns fragment for DID strings" do
      assert AetherATProtoCore.DID.did_fragment(web_did_with_fragment()) == "key1"
    end

    test "returns nil for DID without fragment" do
      assert AetherATProtoCore.DID.did_fragment(web_did()) == nil
    end

    test "returns fragment for DID structs" do
      did = %AetherATProtoCore.DID{method: "web", identifier: "example.com", fragment: "key1"}
      assert AetherATProtoCore.DID.did_fragment(did) == "key1"
    end

    test "returns error for invalid DID" do
      assert AetherATProtoCore.DID.did_fragment("invalid") == {:error, :invalid_did}
    end
  end

  describe "did_params/1" do
    test "returns params for DID strings" do
      params = AetherATProtoCore.DID.did_params(web_did_with_query())
      assert params == %{"version" => "1"}
    end

    test "returns params with boolean values" do
      params = AetherATProtoCore.DID.did_params("did:web:example.com?flag")
      assert params == %{"flag" => true}
    end

    test "returns nil for DID without params" do
      assert AetherATProtoCore.DID.did_params(web_did()) == nil
    end

    test "returns params for DID structs" do
      did = %AetherATProtoCore.DID{
        method: "web",
        identifier: "example.com",
        params: %{"version" => "1"}
      }

      assert AetherATProtoCore.DID.did_params(did) == %{"version" => "1"}
    end

    test "returns error for invalid DID" do
      assert AetherATProtoCore.DID.did_params("invalid") == {:error, :invalid_did}
    end
  end

  describe "supported_method?/1" do
    test "returns true for supported methods" do
      assert AetherATProtoCore.DID.supported_method?("plc")
      assert AetherATProtoCore.DID.supported_method?("web")
      assert AetherATProtoCore.DID.supported_method?("key")
    end

    test "returns false for unsupported methods" do
      refute AetherATProtoCore.DID.supported_method?("unsupported")
      refute AetherATProtoCore.DID.supported_method?("ethr")
      refute AetherATProtoCore.DID.supported_method?("")
    end
  end

  describe "supported_methods/0" do
    test "returns list of supported methods" do
      methods = AetherATProtoCore.DID.supported_methods()
      assert is_list(methods)
      assert "plc" in methods
      assert "web" in methods
      assert "key" in methods
    end
  end

  describe "normalize/1" do
    test "normalizes DID to lowercase" do
      assert AetherATProtoCore.DID.normalize("DID:PLC:Z72I7HDYNMK24R6ZLSDC6NXD") ==
               "did:plc:z72i7hdynmk24r6zlsdc6nxd"

      assert AetherATProtoCore.DID.normalize("DID:WEB:EXAMPLE.COM") == "did:web:example.com"

      assert AetherATProtoCore.DID.normalize(
               "DID:KEY:ZQ3SHOKFTS3BRHCDQRN82RUDFCZESWL1ZDCEJWEKUDPQIYBME"
             ) ==
               "did:key:zq3shokfts3brhcdqrn82rudfczeswl1zdcejwekudpqiybme"
    end

    test "normalizes mixed case DIDs" do
      assert AetherATProtoCore.DID.normalize("Did:Plc:Z72i7Hdynmk24R6zlsdc6Nxd") ==
               "did:plc:z72i7hdynmk24r6zlsdc6nxd"

      assert AetherATProtoCore.DID.normalize("DiD:WeB:ExAmPlE.CoM") == "did:web:example.com"
    end

    test "preserves query and fragment during normalization" do
      # Query parameters and fragments should preserve their original case
      assert AetherATProtoCore.DID.normalize("DID:WEB:EXAMPLE.COM?VERSION=1#KEY1") ==
               "did:web:example.com?VERSION=1#KEY1"

      assert AetherATProtoCore.DID.normalize("did:web:example.com?version=1#key1") ==
               "did:web:example.com?version=1#key1"

      assert AetherATProtoCore.DID.normalize("DID:WEB:EXAMPLE.COM?param=Value#Fragment123") ==
               "did:web:example.com?param=Value#Fragment123"
    end

    test "returns original string for invalid DID" do
      assert AetherATProtoCore.DID.normalize("invalid") == "invalid"
      assert AetherATProtoCore.DID.normalize("did:invalid") == "did:invalid"
    end
  end

  describe "web_domain/1" do
    test "extracts domain from web DID" do
      assert AetherATProtoCore.DID.web_domain("did:web:example.com") == "example.com"
      assert AetherATProtoCore.DID.web_domain("did:web:example.com:3000") == "example.com"
      assert AetherATProtoCore.DID.web_domain("did:web:sub.example.com") == "sub.example.com"
      assert AetherATProtoCore.DID.web_domain("did:web:example.com:path") == "example.com"
    end

    test "returns error for non-web DID" do
      assert AetherATProtoCore.DID.web_domain(plc_did()) == {:error, :not_web_did}
    end

    test "returns error for invalid DID" do
      assert AetherATProtoCore.DID.web_domain("invalid") == {:error, :invalid_did}
    end

    test "works with DID structs" do
      did = %AetherATProtoCore.DID{method: "web", identifier: "example.com:3000"}
      assert AetherATProtoCore.DID.web_domain(did) == "example.com"

      plc_did = %AetherATProtoCore.DID{method: "plc", identifier: "test"}
      assert AetherATProtoCore.DID.web_domain(plc_did) == {:error, :not_web_did}
    end
  end

  # Integration test: real-world ATProto DIDs
  describe "real ATProto DIDs" do
    test "handles typical ATProto DIDs" do
      # These are examples of DIDs you might encounter in ATProto
      atproto_dids = [
        "did:plc:z72i7hdynmk24r6zlsdc6nxd",
        "did:web:bsky.app",
        "did:key:zQ3shokFTS3brHcDQrn82RUDfCZESWL1ZdCEJwekUDPQiYBme"
      ]

      for did <- atproto_dids do
        assert AetherATProtoCore.DID.valid_did?(did)

        {:ok, parsed} = AetherATProtoCore.DID.parse_did(did)
        assert parsed.method in ["plc", "web", "key"]
        assert is_binary(parsed.identifier)
        assert AetherATProtoCore.DID.did_to_string(parsed) == did
      end
    end
  end
end
