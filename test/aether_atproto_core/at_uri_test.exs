defmodule AetherATProtoCore.AtUriTest do
  use ExUnit.Case, async: true
  doctest AetherATProtoCore.AtUri

  alias AetherATProtoCore.AtUri

  describe "parse_at_uri/1" do
    test "parses AT URI with DID authority only" do
      assert {:ok, %AtUri{authority: "did:plc:z72i7hdynmk24r6zlsdc6nxd"}} =
               AtUri.parse_at_uri("at://did:plc:z72i7hdynmk24r6zlsdc6nxd")
    end

    test "parses AT URI with handle authority only" do
      assert {:ok, %AtUri{authority: "alice.bsky.social"}} =
               AtUri.parse_at_uri("at://alice.bsky.social")
    end

    test "parses AT URI with DID and collection" do
      assert {:ok,
              %AtUri{
                authority: "did:plc:z72i7hdynmk24r6zlsdc6nxd",
                collection: "app.bsky.feed.post"
              }} = AtUri.parse_at_uri("at://did:plc:z72i7hdynmk24r6zlsdc6nxd/app.bsky.feed.post")
    end

    test "parses AT URI with handle and collection" do
      assert {:ok, %AtUri{authority: "alice.bsky.social", collection: "app.bsky.feed.post"}} =
               AtUri.parse_at_uri("at://alice.bsky.social/app.bsky.feed.post")
    end

    test "parses complete AT URI with DID, collection, and rkey" do
      assert {:ok,
              %AtUri{
                authority: "did:plc:z72i7hdynmk24r6zlsdc6nxd",
                collection: "app.bsky.feed.post",
                rkey: "3jwdwj2ctlk26"
              }} =
               AtUri.parse_at_uri(
                 "at://did:plc:z72i7hdynmk24r6zlsdc6nxd/app.bsky.feed.post/3jwdwj2ctlk26"
               )
    end

    test "parses complete AT URI with handle, collection, and rkey" do
      assert {:ok,
              %AtUri{
                authority: "alice.bsky.social",
                collection: "app.bsky.feed.post",
                rkey: "123abc"
              }} = AtUri.parse_at_uri("at://alice.bsky.social/app.bsky.feed.post/123abc")
    end

    test "parses AT URI with fragment" do
      assert {:ok,
              %AtUri{
                authority: "alice.bsky.social",
                collection: "app.bsky.feed.post",
                rkey: "123",
                fragment: "anchor"
              }} = AtUri.parse_at_uri("at://alice.bsky.social/app.bsky.feed.post/123#anchor")
    end

    test "parses AT URI with fragment but no collection" do
      assert {:ok, %AtUri{authority: "alice.bsky.social", fragment: "section1"}} =
               AtUri.parse_at_uri("at://alice.bsky.social#section1")
    end

    test "parses AT URI with various valid rkey characters" do
      assert {:ok, %AtUri{rkey: "abc-123_456.789~test"}} =
               AtUri.parse_at_uri(
                 "at://alice.bsky.social/app.bsky.feed.post/abc-123_456.789~test"
               )
    end

    test "returns error for missing scheme" do
      assert {:error, :invalid_format} = AtUri.parse_at_uri("alice.bsky.social")
    end

    test "returns error for wrong scheme" do
      assert {:error, :invalid_format} = AtUri.parse_at_uri("https://alice.bsky.social")
    end

    test "returns error for missing authority" do
      assert {:error, :missing_authority} = AtUri.parse_at_uri("at://")
    end

    test "returns error for invalid DID authority" do
      assert {:error, :invalid_did} = AtUri.parse_at_uri("at://did:invalid:123")
    end

    test "returns error for invalid handle authority" do
      assert {:error, :invalid_handle} = AtUri.parse_at_uri("at://-invalid-handle")
    end

    test "returns error for invalid collection NSID" do
      assert {:error, :invalid_collection} =
               AtUri.parse_at_uri("at://alice.bsky.social/InvalidCollection")
    end

    test "returns error for collection without namespace" do
      assert {:error, :invalid_collection} =
               AtUri.parse_at_uri("at://alice.bsky.social/single")
    end

    test "returns error for invalid rkey" do
      assert {:error, :invalid_rkey} =
               AtUri.parse_at_uri("at://alice.bsky.social/app.bsky.feed.post/invalid space")
    end

    test "returns error for URI exceeding max length" do
      long_uri = "at://alice.bsky.social/" <> String.duplicate("a", 9000)
      assert {:error, :uri_too_long} = AtUri.parse_at_uri(long_uri)
    end

    test "returns error for non-string input" do
      assert {:error, :invalid_format} = AtUri.parse_at_uri(123)
      assert {:error, :invalid_format} = AtUri.parse_at_uri(nil)
    end
  end

  describe "parse_at_uri!/1" do
    test "returns struct for valid AT URI" do
      assert %AtUri{authority: "alice.bsky.social"} =
               AtUri.parse_at_uri!("at://alice.bsky.social")
    end

    test "raises exception for invalid AT URI" do
      assert_raise AtUri.ParseError, ~r/Invalid AT URI: invalid_format/, fn ->
        AtUri.parse_at_uri!("invalid")
      end
    end

    test "returns struct unchanged" do
      at_uri = %AtUri{authority: "alice.bsky.social"}
      assert ^at_uri = AtUri.parse_at_uri!(at_uri)
    end

    test "raises for invalid input type" do
      assert_raise AtUri.ParseError, ~r/Invalid AT URI: invalid_format/, fn ->
        AtUri.parse_at_uri!(123)
      end
    end
  end

  describe "valid_at_uri?/1" do
    test "returns true for valid AT URI string" do
      assert AtUri.valid_at_uri?("at://alice.bsky.social")
      assert AtUri.valid_at_uri?("at://did:plc:z72i7hdynmk24r6zlsdc6nxd/app.bsky.feed.post/123")
    end

    test "returns false for invalid AT URI string" do
      refute AtUri.valid_at_uri?("invalid")
      refute AtUri.valid_at_uri?("https://example.com")
      refute AtUri.valid_at_uri?("at://")
    end

    test "returns true for AtUri struct" do
      assert AtUri.valid_at_uri?(%AtUri{authority: "alice.bsky.social"})
    end

    test "returns false for non-string, non-struct input" do
      refute AtUri.valid_at_uri?(123)
      refute AtUri.valid_at_uri?(nil)
      refute AtUri.valid_at_uri?(%{authority: "test"})
    end
  end

  describe "at_uri_to_string/1" do
    test "converts authority-only AT URI to string" do
      at_uri = %AtUri{authority: "alice.bsky.social"}
      assert "at://alice.bsky.social" = AtUri.at_uri_to_string(at_uri)
    end

    test "converts AT URI with collection to string" do
      at_uri = %AtUri{authority: "alice.bsky.social", collection: "app.bsky.feed.post"}
      assert "at://alice.bsky.social/app.bsky.feed.post" = AtUri.at_uri_to_string(at_uri)
    end

    test "converts complete AT URI to string" do
      at_uri = %AtUri{
        authority: "alice.bsky.social",
        collection: "app.bsky.feed.post",
        rkey: "123"
      }

      assert "at://alice.bsky.social/app.bsky.feed.post/123" = AtUri.at_uri_to_string(at_uri)
    end

    test "converts AT URI with fragment to string" do
      at_uri = %AtUri{
        authority: "alice.bsky.social",
        collection: "app.bsky.feed.post",
        rkey: "123",
        fragment: "anchor"
      }

      assert "at://alice.bsky.social/app.bsky.feed.post/123#anchor" =
               AtUri.at_uri_to_string(at_uri)
    end

    test "converts AT URI with fragment but no collection to string" do
      at_uri = %AtUri{authority: "alice.bsky.social", fragment: "section"}
      assert "at://alice.bsky.social#section" = AtUri.at_uri_to_string(at_uri)
    end

    test "returns string unchanged" do
      assert "at://alice.bsky.social" = AtUri.at_uri_to_string("at://alice.bsky.social")
    end

    test "converts DID authority AT URI to string" do
      at_uri = %AtUri{
        authority: "did:plc:z72i7hdynmk24r6zlsdc6nxd",
        collection: "app.bsky.feed.post",
        rkey: "3jwdwj2ctlk26"
      }

      assert "at://did:plc:z72i7hdynmk24r6zlsdc6nxd/app.bsky.feed.post/3jwdwj2ctlk26" =
               AtUri.at_uri_to_string(at_uri)
    end
  end

  describe "authority/1" do
    test "extracts authority from AtUri struct" do
      at_uri = %AtUri{authority: "alice.bsky.social"}
      assert "alice.bsky.social" = AtUri.authority(at_uri)
    end

    test "extracts authority from string" do
      assert "alice.bsky.social" =
               AtUri.authority("at://alice.bsky.social/app.bsky.feed.post/123")
    end

    test "extracts DID authority from string" do
      assert "did:plc:z72i7hdynmk24r6zlsdc6nxd" =
               AtUri.authority("at://did:plc:z72i7hdynmk24r6zlsdc6nxd/app.bsky.feed.post/123")
    end

    test "returns error for invalid AT URI string" do
      assert {:error, :invalid_at_uri} = AtUri.authority("invalid")
    end
  end

  describe "collection/1" do
    test "extracts collection from AtUri struct" do
      at_uri = %AtUri{authority: "alice.bsky.social", collection: "app.bsky.feed.post"}
      assert "app.bsky.feed.post" = AtUri.collection(at_uri)
    end

    test "extracts collection from string" do
      assert "app.bsky.feed.post" =
               AtUri.collection("at://alice.bsky.social/app.bsky.feed.post/123")
    end

    test "returns nil when no collection present" do
      at_uri = %AtUri{authority: "alice.bsky.social"}
      assert nil == AtUri.collection(at_uri)
    end

    test "returns nil when parsing string without collection" do
      assert nil == AtUri.collection("at://alice.bsky.social")
    end

    test "returns error for invalid AT URI string" do
      assert {:error, :invalid_at_uri} = AtUri.collection("invalid")
    end
  end

  describe "rkey/1" do
    test "extracts rkey from AtUri struct" do
      at_uri = %AtUri{
        authority: "alice.bsky.social",
        collection: "app.bsky.feed.post",
        rkey: "123"
      }

      assert "123" = AtUri.rkey(at_uri)
    end

    test "extracts rkey from string" do
      assert "123" = AtUri.rkey("at://alice.bsky.social/app.bsky.feed.post/123")
    end

    test "returns nil when no rkey present" do
      at_uri = %AtUri{authority: "alice.bsky.social", collection: "app.bsky.feed.post"}
      assert nil == AtUri.rkey(at_uri)
    end

    test "returns nil when parsing string without rkey" do
      assert nil == AtUri.rkey("at://alice.bsky.social/app.bsky.feed.post")
    end

    test "returns error for invalid AT URI string" do
      assert {:error, :invalid_at_uri} = AtUri.rkey("invalid")
    end
  end

  describe "fragment/1" do
    test "extracts fragment from AtUri struct" do
      at_uri = %AtUri{authority: "alice.bsky.social", fragment: "anchor"}
      assert "anchor" = AtUri.fragment(at_uri)
    end

    test "extracts fragment from string" do
      assert "anchor" = AtUri.fragment("at://alice.bsky.social#anchor")
      assert "anchor" = AtUri.fragment("at://alice.bsky.social/app.bsky.feed.post/123#anchor")
    end

    test "returns nil when no fragment present" do
      at_uri = %AtUri{authority: "alice.bsky.social"}
      assert nil == AtUri.fragment(at_uri)
    end

    test "returns nil when parsing string without fragment" do
      assert nil == AtUri.fragment("at://alice.bsky.social")
    end

    test "returns error for invalid AT URI string" do
      assert {:error, :invalid_at_uri} = AtUri.fragment("invalid")
    end
  end

  describe "real-world AT URI examples" do
    test "parses Bluesky post URI" do
      uri = "at://did:plc:44ybard66vv44zksje25o7dz/app.bsky.feed.post/3jwdwj2ctlk26"

      assert {:ok,
              %AtUri{
                authority: "did:plc:44ybard66vv44zksje25o7dz",
                collection: "app.bsky.feed.post",
                rkey: "3jwdwj2ctlk26"
              }} = AtUri.parse_at_uri(uri)
    end

    test "parses Bluesky profile URI" do
      uri = "at://alice.bsky.social/app.bsky.actor.profile/self"

      assert {:ok,
              %AtUri{
                authority: "alice.bsky.social",
                collection: "app.bsky.actor.profile",
                rkey: "self"
              }} = AtUri.parse_at_uri(uri)
    end

    test "parses repository reference" do
      uri = "at://did:plc:z72i7hdynmk24r6zlsdc6nxd"

      assert {:ok, %AtUri{authority: "did:plc:z72i7hdynmk24r6zlsdc6nxd"}} =
               AtUri.parse_at_uri(uri)
    end
  end

  describe "round-trip conversion" do
    test "parse and convert back to string" do
      original = "at://alice.bsky.social/app.bsky.feed.post/123"
      {:ok, at_uri} = AtUri.parse_at_uri(original)
      assert ^original = AtUri.at_uri_to_string(at_uri)
    end

    test "round-trip with fragment" do
      original = "at://alice.bsky.social/app.bsky.feed.post/123#anchor"
      {:ok, at_uri} = AtUri.parse_at_uri(original)
      assert ^original = AtUri.at_uri_to_string(at_uri)
    end

    test "round-trip with DID" do
      original = "at://did:plc:z72i7hdynmk24r6zlsdc6nxd/app.bsky.feed.post/3jwdwj2ctlk26"
      {:ok, at_uri} = AtUri.parse_at_uri(original)
      assert ^original = AtUri.at_uri_to_string(at_uri)
    end
  end
end
