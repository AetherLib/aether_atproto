defmodule Aether.ATProto.DIDTest do
  use ExUnit.Case, async: true
  doctest Aether.ATProto.DID

  import Aether.ATProto.DIDFixtures

  describe "parse_did/1" do
    test "parses valid PLC DID" do
      did_string = plc_did()

      assert {:ok, %Aether.ATProto.DID{}} = Aether.ATProto.DID.parse(did_string)

      assert {:ok, %Aether.ATProto.DID{method: "plc", identifier: "z72i7hdynmk24r6zlsdc6nxd"}} =
               Aether.ATProto.DID.parse(did_string)
    end

    test "parses valid Web DID" do
      did_string = web_did()

      assert {:ok, %Aether.ATProto.DID{}} = Aether.ATProto.DID.parse(did_string)

      assert {:ok, %Aether.ATProto.DID{method: "web", identifier: "example.com"}} =
               Aether.ATProto.DID.parse(did_string)
    end

    test "parses valid Web DID with port" do
      did_string = web_did_with_port()

      assert {:ok, %Aether.ATProto.DID{}} = Aether.ATProto.DID.parse(did_string)

      assert {:ok, %Aether.ATProto.DID{method: "web", identifier: "example.com:3000"}} =
               Aether.ATProto.DID.parse(did_string)
    end

    test "parses valid Web DID with path" do
      did_string = "did:web:example.com:user"

      assert {:ok, %Aether.ATProto.DID{}} = Aether.ATProto.DID.parse(did_string)

      assert {:ok, %Aether.ATProto.DID{method: "web", identifier: "example.com:user"}} =
               Aether.ATProto.DID.parse(did_string)
    end

    test "parses valid Key DID" do
      did_string = key_did()

      assert {:ok, %Aether.ATProto.DID{}} = Aether.ATProto.DID.parse(did_string)

      assert {:ok,
              %Aether.ATProto.DID{
                method: "key",
                identifier: "zQ3shokFTS3brHcDQrn82RUDfCZESWL1ZdCEJwekUDPQiYBme"
              }} = Aether.ATProto.DID.parse(did_string)
    end

    test "parses DID with fragment" do
      did_string = web_did_with_fragment()

      assert {:ok, %Aether.ATProto.DID{}} = Aether.ATProto.DID.parse(did_string)

      assert {:ok,
              %Aether.ATProto.DID{method: "web", identifier: "example.com", fragment: "key1"}} =
               Aether.ATProto.DID.parse(did_string)
    end

    test "parses DID with query parameters" do
      did_string = web_did_with_query()

      assert {:ok, %Aether.ATProto.DID{}} = Aether.ATProto.DID.parse(did_string)

      assert {:ok,
              %Aether.ATProto.DID{
                method: "web",
                identifier: "example.com",
                query: "version=1",
                params: %{"version" => "1"}
              }} = Aether.ATProto.DID.parse(did_string)
    end

    test "parses DID with fragment and query parameters" do
      did_string = web_did_with_fragment_and_query()

      assert {:ok, %Aether.ATProto.DID{}} = Aether.ATProto.DID.parse(did_string)

      assert {:ok,
              %Aether.ATProto.DID{
                method: "web",
                identifier: "example.com",
                query: "version=1",
                fragment: "key1",
                params: %{"version" => "1"}
              }} = Aether.ATProto.DID.parse(did_string)
    end

    test "returns error for invalid DID format" do
      for invalid_did <- invalid_dids() do
        assert {:error, _} = Aether.ATProto.DID.parse(invalid_did)
      end
    end

    test "returns error for unsupported method" do
      assert {:error, "Unsupported method"} =
               Aether.ATProto.DID.parse("did:unsupported:identifier")
    end

    test "returns error for invalid PLC identifier" do
      # Too short
      assert {:error, "Invalid identifier"} = Aether.ATProto.DID.parse("did:plc:abc123")
      # Invalid characters
      assert {:error, "Disallowed character in DID at position 32"} =
               Aether.ATProto.DID.parse("did:plc:z72i7hdynmk24r6zlsdc6nxd!")
    end

    test "returns error for invalid Web identifier" do
      # Invalid domain
      assert {:error, "Invalid identifier"} =
               Aether.ATProto.DID.parse("did:web:example..com")

      # Invalid characters
      assert {:error, "Invalid identifier"} =
               Aether.ATProto.DID.parse("did:web:example_com")
    end

    test "returns error for invalid Key identifier" do
      # Doesn't start with z
      assert {:error, "Invalid identifier"} = Aether.ATProto.DID.parse("did:key:abc123")
      # Invalid multibase characters
      assert {:error, "Disallowed character in DID at position 12"} =
               Aether.ATProto.DID.parse("did:key:z123!")
    end
  end

  describe "parse_did!/1" do
    test "returns DID struct for valid DID" do
      did_string = plc_did()

      did = Aether.ATProto.DID.parse!(did_string)
      assert %Aether.ATProto.DID{method: "plc", identifier: "z72i7hdynmk24r6zlsdc6nxd"} = did
    end

    test "raises ParseError for invalid DID" do
      assert_raise Aether.ATProto.DID.ParseError, fn ->
        Aether.ATProto.DID.parse!("invalid")
      end

      assert_raise Aether.ATProto.DID.ParseError, fn ->
        Aether.ATProto.DID.parse!("did:unsupported:test")
      end
    end

    test "returns DID struct when passed a DID struct" do
      did_struct = %Aether.ATProto.DID{method: "plc", identifier: "test"}
      assert ^did_struct = Aether.ATProto.DID.parse!(did_struct)
    end
  end

  describe "valid?/1" do
    test "returns true for valid DID strings" do
      assert Aether.ATProto.DID.valid?(plc_did())
      assert Aether.ATProto.DID.valid?(web_did())
      assert Aether.ATProto.DID.valid?(key_did())
    end

    test "returns true for DID structs" do
      did_struct = %Aether.ATProto.DID{method: "plc", identifier: "test"}
      assert Aether.ATProto.DID.valid?(did_struct)
    end

    test "returns false for invalid inputs" do
      for invalid_did <- invalid_dids() do
        refute Aether.ATProto.DID.valid?(invalid_did)
      end

      refute Aether.ATProto.DID.valid?(nil)
      refute Aether.ATProto.DID.valid?(123)
      refute Aether.ATProto.DID.valid?(%{})
    end
  end

  describe "did_to_string/1" do
    test "returns string from DID struct" do
      did = %Aether.ATProto.DID{method: "plc", identifier: "z72i7hdynmk24r6zlsdc6nxd"}

      assert Aether.ATProto.DID.to_string(did) == "did:plc:z72i7hdynmk24r6zlsdc6nxd"
    end

    test "returns string with fragment" do
      did = %Aether.ATProto.DID{method: "web", identifier: "example.com", fragment: "key1"}

      assert Aether.ATProto.DID.to_string(did) == "did:web:example.com#key1"
    end

    test "returns string with query parameters" do
      did = %Aether.ATProto.DID{method: "web", identifier: "example.com", query: "version=1"}

      assert Aether.ATProto.DID.to_string(did) == "did:web:example.com?version=1"
    end

    test "returns string with both fragment and query" do
      did = %Aether.ATProto.DID{
        method: "web",
        identifier: "example.com",
        query: "version=1",
        fragment: "key1"
      }

      assert Aether.ATProto.DID.to_string(did) == "did:web:example.com?version=1#key1"
    end

    test "returns string when passed a string" do
      did_string = "did:plc:test"
      assert Aether.ATProto.DID.to_string(did_string) == did_string
    end
  end

  describe "method/1" do
    test "returns method for DID strings" do
      assert Aether.ATProto.DID.method(plc_did()) == "plc"
      assert Aether.ATProto.DID.method(web_did()) == "web"
      assert Aether.ATProto.DID.method(key_did()) == "key"
    end

    test "returns method for DID structs" do
      did = %Aether.ATProto.DID{method: "plc", identifier: "test"}
      assert Aether.ATProto.DID.method(did) == "plc"
    end

    test "returns error for invalid DID" do
      assert {:error, "Invalid DID Method"} == Aether.ATProto.DID.method("invalid")
    end
  end

  describe "identifier/1" do
    test "returns identifier for DID strings" do
      assert Aether.ATProto.DID.identifier(plc_did()) == "z72i7hdynmk24r6zlsdc6nxd"
      assert Aether.ATProto.DID.identifier(web_did()) == "example.com"
    end

    test "returns identifier for DID structs" do
      did = %Aether.ATProto.DID{method: "plc", identifier: "test"}
      assert Aether.ATProto.DID.identifier(did) == "test"
    end

    test "returns error for invalid DID" do
      assert {:error, "Invalid DID Identifier"} == Aether.ATProto.DID.identifier("invalid")
    end
  end

  describe "is_method?/2" do
    test "returns true for matching method" do
      assert Aether.ATProto.DID.is_method?(plc_did(), "plc")
      assert Aether.ATProto.DID.is_method?(web_did(), "web")
    end

    test "returns false for non-matching method" do
      refute Aether.ATProto.DID.is_method?(plc_did(), "web")
      refute Aether.ATProto.DID.is_method?(web_did(), "plc")
    end

    test "returns false for invalid DID" do
      refute Aether.ATProto.DID.is_method?("invalid", "plc")
    end

    test "works with DID structs" do
      did = %Aether.ATProto.DID{method: "plc", identifier: "test"}
      assert Aether.ATProto.DID.is_method?(did, "plc")
      refute Aether.ATProto.DID.is_method?(did, "web")
    end
  end

  describe "fragment/1" do
    test "returns fragment for DID strings" do
      assert Aether.ATProto.DID.fragment(web_did_with_fragment()) == "key1"
    end

    test "returns nil for DID without fragment" do
      assert Aether.ATProto.DID.fragment(web_did()) == nil
    end

    test "returns fragment for DID structs" do
      did = %Aether.ATProto.DID{method: "web", identifier: "example.com", fragment: "key1"}
      assert Aether.ATProto.DID.fragment(did) == "key1"
    end

    test "returns error for invalid DID" do
      assert {:error, "Invalid DID Fragment"} == Aether.ATProto.DID.fragment("invalid")
    end
  end

  describe "params/1" do
    test "returns params for DID strings" do
      params = Aether.ATProto.DID.params(web_did_with_query())
      assert params == %{"version" => "1"}
    end

    test "returns params with boolean values" do
      params = Aether.ATProto.DID.params("did:web:example.com?flag")
      assert params == %{"flag" => true}
    end

    test "returns nil for DID without params" do
      assert Aether.ATProto.DID.params(web_did()) == nil
    end

    test "returns params for DID structs" do
      did = %Aether.ATProto.DID{
        method: "web",
        identifier: "example.com",
        params: %{"version" => "1"}
      }

      assert Aether.ATProto.DID.params(did) == %{"version" => "1"}
    end

    test "returns error for invalid DID" do
      assert {:error, "Invalid DID Params"} == Aether.ATProto.DID.params("invalid")
    end
  end

  describe "supported_method?/1" do
    test "returns true for supported methods" do
      assert Aether.ATProto.DID.supported_method?("plc")
      assert Aether.ATProto.DID.supported_method?("web")
      assert Aether.ATProto.DID.supported_method?("key")
    end

    test "returns false for unsupported methods" do
      refute Aether.ATProto.DID.supported_method?("unsupported")
      refute Aether.ATProto.DID.supported_method?("ethr")
      refute Aether.ATProto.DID.supported_method?("")
    end
  end

  describe "supported_methods/0" do
    test "returns list of supported methods" do
      methods = Aether.ATProto.DID.supported_methods()
      assert is_list(methods)
      assert "plc" in methods
      assert "web" in methods
      assert "key" in methods
    end
  end

  describe "normalize/1" do
    test "normalizes DID to lowercase" do
      assert Aether.ATProto.DID.normalize("DID:PLC:Z72I7HDYNMK24R6ZLSDC6NXD") ==
               "did:plc:z72i7hdynmk24r6zlsdc6nxd"

      assert Aether.ATProto.DID.normalize("DID:WEB:EXAMPLE.COM") == "did:web:example.com"

      assert Aether.ATProto.DID.normalize(
               "DID:KEY:ZQ3SHOKFTS3BRHCDQRN82RUDFCZESWL1ZDCEJWEKUDPQIYBME"
             ) ==
               "did:key:zq3shokfts3brhcdqrn82rudfczeswl1zdcejwekudpqiybme"
    end

    test "normalizes mixed case DIDs" do
      assert Aether.ATProto.DID.normalize("Did:Plc:Z72i7Hdynmk24R6zlsdc6Nxd") ==
               "did:plc:z72i7hdynmk24r6zlsdc6nxd"

      assert Aether.ATProto.DID.normalize("DiD:WeB:ExAmPlE.CoM") == "did:web:example.com"
    end

    test "preserves query and fragment during normalization" do
      # Query parameters and fragments should preserve their original case
      assert Aether.ATProto.DID.normalize("DID:WEB:EXAMPLE.COM?VERSION=1#KEY1") ==
               "did:web:example.com?VERSION=1#KEY1"

      assert Aether.ATProto.DID.normalize("did:web:example.com?version=1#key1") ==
               "did:web:example.com?version=1#key1"

      assert Aether.ATProto.DID.normalize("DID:WEB:EXAMPLE.COM?param=Value#Fragment123") ==
               "did:web:example.com?param=Value#Fragment123"
    end

    test "returns original string for invalid DID" do
      assert Aether.ATProto.DID.normalize("invalid") == "invalid"
      assert Aether.ATProto.DID.normalize("did:invalid") == "did:invalid"
    end
  end

  describe "web_domain/1" do
    test "extracts domain from web DID" do
      assert Aether.ATProto.DID.web_domain("did:web:example.com") == "example.com"
      assert Aether.ATProto.DID.web_domain("did:web:example.com:3000") == "example.com"
      assert Aether.ATProto.DID.web_domain("did:web:sub.example.com") == "sub.example.com"
      assert Aether.ATProto.DID.web_domain("did:web:example.com:path") == "example.com"
    end

    test "returns error for non-web DID" do
      assert {:error, "Invalid DID Web domain"} == Aether.ATProto.DID.web_domain(plc_did())
    end

    test "returns error for invalid DID" do
      assert {:error, "Invalid DID"} == Aether.ATProto.DID.web_domain("invalid")
    end

    test "works with DID structs" do
      did = %Aether.ATProto.DID{method: "web", identifier: "example.com:3000"}
      assert Aether.ATProto.DID.web_domain(did) == "example.com"

      plc_did = %Aether.ATProto.DID{method: "plc", identifier: "test"}
      assert {:error, "Invalid DID Web domain"} == Aether.ATProto.DID.web_domain(plc_did)
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
        assert Aether.ATProto.DID.valid?(did)

        {:ok, parsed} = Aether.ATProto.DID.parse(did)
        assert parsed.method in ["plc", "web", "key"]
        assert is_binary(parsed.identifier)
        assert Aether.ATProto.DID.to_string(parsed) == did
      end
    end
  end
end
