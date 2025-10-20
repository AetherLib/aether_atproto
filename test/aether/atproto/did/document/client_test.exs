defmodule Aether.ATProto.DID.Document.ClientTest do
  use ExUnit.Case, async: true
  doctest Aether.ATProto.DID.Document.Client

  alias Aether.ATProto.DID.Document.Client

  describe "resolve/1 - did:web" do
    test "returns error for invalid DID format" do
      assert {:error, "Invalid DID"} = Client.resolve("not a did")
    end

    test "returns error for unsupported method" do
      # Note: "did:key:z6Mkfriq..." is invalid because the identifier format is wrong
      # A valid did:key would be something like "did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK"
      assert {:error, "Invalid identifier"} = Client.resolve("did:key:z6Mkfriq...")
    end
  end

  describe "build_did_web_url/1" do
    test "builds URL for simple domain" do
      url = Client.build_did_web_url("example.com")
      assert url == "https://example.com/.well-known/did.json"
    end

    test "builds URL for domain with path" do
      url = Client.build_did_web_url("example.com:user:alice")
      assert url == "https://example.com/user/alice/did.json"
    end

    test "builds URL for domain with deeper path" do
      url = Client.build_did_web_url("example.com:users:team:alice")
      assert url == "https://example.com/users/team/alice/did.json"
    end
  end

  describe "integration with Aether.DID" do
    test "resolve rejects invalid DID format" do
      assert {:error, "Invalid DID"} = Client.resolve("not-a-did")
      assert {:error, "Invalid DID"} = Client.resolve("did:")
      assert {:error, "DID method-specific id must not be empty"} = Client.resolve("did:plc:")
    end
  end
end
