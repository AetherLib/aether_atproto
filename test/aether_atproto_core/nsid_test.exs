defmodule AetherATProtoCore.NSIDTest do
  use ExUnit.Case, async: true
  doctest AetherATProtoCore.NSID

  alias AetherATProtoCore.NSID

  describe "parse_nsid/1" do
    test "parses valid NSIDs with simple names" do
      assert {:ok, %NSID{authority: "com.example", name: "fooBar"}} =
               NSID.parse_nsid("com.example.fooBar")

      assert {:ok, %NSID{authority: "app.bsky.feed", name: "post"}} =
               NSID.parse_nsid("app.bsky.feed.post")

      assert {:ok, %NSID{authority: "com.atproto.repo", name: "createRecord"}} =
               NSID.parse_nsid("com.atproto.repo.createRecord")
    end

    test "parses NSIDs with numeric authority segments" do
      assert {:ok, %NSID{authority: "com.example2", name: "foo"}} =
               NSID.parse_nsid("com.example2.foo")

      assert {:ok, %NSID{authority: "org.example.service9", name: "method"}} =
               NSID.parse_nsid("org.example.service9.method")
    end

    test "parses NSIDs with hyphens in authority" do
      assert {:ok, %NSID{authority: "com.my-company", name: "action"}} =
               NSID.parse_nsid("com.my-company.action")

      assert {:ok, %NSID{authority: "org.open-source.project", name: "task"}} =
               NSID.parse_nsid("org.open-source.project.task")
    end

    test "parses NSIDs with case-sensitive names" do
      assert {:ok, %NSID{authority: "com.example", name: "fooBar"}} =
               NSID.parse_nsid("com.example.fooBar")

      assert {:ok, %NSID{authority: "com.example", name: "FooBar"}} =
               NSID.parse_nsid("com.example.FooBar")

      assert {:ok, %NSID{authority: "com.example", name: "fooBarV2"}} =
               NSID.parse_nsid("com.example.fooBarV2")
    end

    test "parses real ATProto NSIDs" do
      real_nsids = [
        "com.atproto.repo.createRecord",
        "com.atproto.repo.getRecord",
        "com.atproto.repo.listRecords",
        "com.atproto.identity.resolveHandle",
        "app.bsky.feed.post",
        "app.bsky.feed.like",
        "app.bsky.actor.profile",
        "app.bsky.graph.follow"
      ]

      for nsid_string <- real_nsids do
        assert {:ok, %NSID{}} = NSID.parse_nsid(nsid_string)
      end
    end

    test "rejects NSIDs with too few segments" do
      assert {:error, :too_few_segments} = NSID.parse_nsid("com.example")
      assert {:error, :too_few_segments} = NSID.parse_nsid("example")
    end

    test "rejects NSIDs with uppercase in authority" do
      assert {:error, :invalid_authority_segment} = NSID.parse_nsid("Com.example.foo")
      assert {:error, :invalid_authority_segment} = NSID.parse_nsid("com.Example.foo")
    end

    test "rejects NSIDs with name starting with digit" do
      assert {:error, :invalid_name} = NSID.parse_nsid("com.example.3foo")
      assert {:error, :invalid_name} = NSID.parse_nsid("com.example.9bar")
    end

    test "rejects NSIDs with hyphens in name" do
      assert {:error, :invalid_name} = NSID.parse_nsid("com.example.foo-bar")
      assert {:error, :invalid_name} = NSID.parse_nsid("com.example.my-method")
    end

    test "rejects NSIDs with authority starting with digit" do
      assert {:error, :authority_starts_with_digit} = NSID.parse_nsid("9com.example.foo")
    end

    test "rejects NSIDs with authority segment starting/ending with hyphen" do
      assert {:error, :invalid_authority_segment} = NSID.parse_nsid("com.-example.foo")
      assert {:error, :invalid_authority_segment} = NSID.parse_nsid("com.example-.foo")
    end

    test "rejects NSIDs with special characters" do
      assert {:error, :invalid_authority_segment} = NSID.parse_nsid("com.exam_ple.foo")
      assert {:error, :invalid_name} = NSID.parse_nsid("com.example.foo_bar")
      assert {:error, :non_ascii} = NSID.parse_nsid("com.example.foo💩")
    end

    test "rejects NSIDs that are too long" do
      # Create NSID longer than 317 characters with valid structure
      # Need at least 3 segments, so create long multi-segment authority
      segment = String.duplicate("a", 63)
      # 63 * 5 + 4 dots + 3 for name = 322 chars
      long_authority = Enum.join(List.duplicate(segment, 5), ".")
      long_nsid = "#{long_authority}.foo"
      assert byte_size(long_nsid) > 317
      assert {:error, :too_long} = NSID.parse_nsid(long_nsid)
    end

    test "rejects NSIDs with authority longer than 253 characters" do
      # Create authority longer than 253 characters but total under 317
      # 62 * 4 + 3 dots = 251, one more segment pushes it over
      long_segment = String.duplicate("a", 62)
      long_authority = Enum.join(List.duplicate(long_segment, 4) ++ ["abc"], ".")
      assert byte_size(long_authority) > 253
      # Total length is 251 + 3 + 1 + 3 = 258 (under 317)
      total = "#{long_authority}.foo"
      assert byte_size(total) < 317
      assert {:error, :authority_too_long} = NSID.parse_nsid(total)
    end

    test "rejects NSIDs with segments longer than 63 characters" do
      long_segment = String.duplicate("a", 64)
      assert {:error, :invalid_authority_segment} = NSID.parse_nsid("com.#{long_segment}.foo")
      assert {:error, :name_too_long} = NSID.parse_nsid("com.example.#{long_segment}")
    end

    test "accepts NSIDs with segments exactly 63 characters" do
      segment_63 = String.duplicate("a", 63)
      assert {:ok, _} = NSID.parse_nsid("com.#{segment_63}.foo")
      assert {:ok, _} = NSID.parse_nsid("com.example.#{segment_63}")
    end

    test "rejects NSIDs with only one authority segment" do
      # "com.foo" has 2 segments total, which fails the minimum 3 segment check first
      assert {:error, :too_few_segments} = NSID.parse_nsid("com.foo")
    end

    test "rejects empty segments" do
      assert {:error, :invalid_authority_segment} = NSID.parse_nsid("com..example.foo")
      assert {:error, :invalid_authority_segment} = NSID.parse_nsid(".com.example.foo")
    end

    test "rejects non-string input" do
      assert {:error, :invalid_input} = NSID.parse_nsid(123)
      assert {:error, :invalid_input} = NSID.parse_nsid(nil)
      assert {:error, :invalid_input} = NSID.parse_nsid(%{})
    end
  end

  describe "parse_nsid!/1" do
    test "parses valid NSID" do
      assert %NSID{authority: "com.example", name: "foo"} =
               NSID.parse_nsid!("com.example.foo")
    end

    test "raises on invalid NSID" do
      assert_raise NSID.ParseError, ~r/Invalid NSID: too_few_segments/, fn ->
        NSID.parse_nsid!("com.example")
      end
    end

    test "returns NSID struct unchanged" do
      nsid = %NSID{authority: "com.example", name: "foo"}
      assert ^nsid = NSID.parse_nsid!(nsid)
    end

    test "raises on non-string, non-struct input" do
      assert_raise NSID.ParseError, ~r/Invalid NSID: invalid_input/, fn ->
        NSID.parse_nsid!(123)
      end
    end
  end

  describe "valid_nsid?/1" do
    test "returns true for valid NSIDs" do
      assert NSID.valid_nsid?("com.example.fooBar")
      assert NSID.valid_nsid?("app.bsky.feed.post")
      assert NSID.valid_nsid?("com.atproto.repo.createRecord")
    end

    test "returns false for invalid NSIDs" do
      refute NSID.valid_nsid?("com.example")
      refute NSID.valid_nsid?("com.example.3foo")
      refute NSID.valid_nsid?("Com.Example.foo")
      refute NSID.valid_nsid?("com.example.foo-bar")
    end

    test "returns true for NSID structs" do
      nsid = %NSID{authority: "com.example", name: "foo"}
      assert NSID.valid_nsid?(nsid)
    end

    test "returns false for non-string, non-struct input" do
      refute NSID.valid_nsid?(123)
      refute NSID.valid_nsid?(nil)
      refute NSID.valid_nsid?(%{})
    end
  end

  describe "nsid_to_string/1" do
    test "converts NSID struct to string" do
      nsid = %NSID{authority: "com.example", name: "fooBar"}
      assert NSID.nsid_to_string(nsid) == "com.example.fooBar"
    end

    test "returns string unchanged" do
      assert NSID.nsid_to_string("com.example.foo") == "com.example.foo"
    end

    test "handles multi-segment authorities" do
      nsid = %NSID{authority: "com.example.service", name: "method"}
      assert NSID.nsid_to_string(nsid) == "com.example.service.method"
    end
  end

  describe "authority/1" do
    test "extracts authority from NSID string" do
      assert NSID.authority("com.example.fooBar") == "com.example"
      assert NSID.authority("app.bsky.feed.post") == "app.bsky.feed"
      assert NSID.authority("com.atproto.repo.createRecord") == "com.atproto.repo"
    end

    test "extracts authority from NSID struct" do
      nsid = %NSID{authority: "com.example", name: "foo"}
      assert NSID.authority(nsid) == "com.example"
    end

    test "returns error for invalid NSID" do
      assert NSID.authority("invalid") == {:error, :invalid_nsid}
      assert NSID.authority("com.example") == {:error, :invalid_nsid}
    end
  end

  describe "name/1" do
    test "extracts name from NSID string" do
      assert NSID.name("com.example.fooBar") == "fooBar"
      assert NSID.name("app.bsky.feed.post") == "post"
      assert NSID.name("com.atproto.repo.createRecord") == "createRecord"
    end

    test "extracts name from NSID struct" do
      nsid = %NSID{authority: "com.example", name: "foo"}
      assert NSID.name(nsid) == "foo"
    end

    test "returns error for invalid NSID" do
      assert NSID.name("invalid") == {:error, :invalid_nsid}
      assert NSID.name("com.example") == {:error, :invalid_nsid}
    end
  end

  describe "edge cases" do
    test "handles minimum valid NSID" do
      # 3 segments total: 2 authority + 1 name
      assert {:ok, %NSID{authority: "a.b", name: "c"}} = NSID.parse_nsid("a.b.c")
    end

    test "handles maximum length segments" do
      segment_63 = String.duplicate("a", 63)
      name_63 = "A" <> String.duplicate("a", 62)

      assert {:ok, _} = NSID.parse_nsid("com.#{segment_63}.#{name_63}")
    end

    test "handles numeric characters in name" do
      assert {:ok, %NSID{name: "fooBar123"}} = NSID.parse_nsid("com.example.fooBar123")
      assert {:ok, %NSID{name: "v2"}} = NSID.parse_nsid("com.example.v2")
    end

    test "case sensitivity in name" do
      assert {:ok, %NSID{name: "FooBar"}} = NSID.parse_nsid("com.example.FooBar")
      assert {:ok, %NSID{name: "fooBar"}} = NSID.parse_nsid("com.example.fooBar")
      assert NSID.name("com.example.FooBar") != NSID.name("com.example.fooBar")
    end

    test "multiple authority segments" do
      assert {:ok, %NSID{authority: "com.example.service.v1", name: "method"}} =
               NSID.parse_nsid("com.example.service.v1.method")
    end
  end

  describe "pattern matching" do
    test "can pattern match on NSID struct" do
      {:ok, nsid} = NSID.parse_nsid("com.example.fooBar")

      assert %NSID{authority: authority, name: name} = nsid
      assert authority == "com.example"
      assert name == "fooBar"
    end

    test "can match specific authorities" do
      {:ok, nsid} = NSID.parse_nsid("app.bsky.feed.post")

      case nsid do
        %NSID{authority: "app.bsky.feed", name: "post"} -> :ok
        _ -> flunk("Should match specific authority and name")
      end
    end
  end

  describe "functional composition" do
    test "can chain with pipe operator" do
      result =
        "com.example.fooBar"
        |> NSID.parse_nsid()
        |> case do
          {:ok, nsid} -> NSID.authority(nsid)
          error -> error
        end

      assert result == "com.example"
    end

    test "works with Enum functions" do
      nsid_strings = [
        "com.example.foo",
        "com.example.bar",
        "invalid"
      ]

      valid_nsids =
        nsid_strings
        |> Enum.map(&NSID.parse_nsid/1)
        |> Enum.filter(&match?({:ok, _}, &1))
        |> Enum.map(fn {:ok, nsid} -> nsid end)

      assert length(valid_nsids) == 2
    end
  end

  describe "real-world ATProto usage" do
    test "validates all common Bluesky record types" do
      record_types = [
        "app.bsky.feed.post",
        "app.bsky.feed.like",
        "app.bsky.feed.repost",
        "app.bsky.actor.profile",
        "app.bsky.graph.follow",
        "app.bsky.graph.block"
      ]

      for type <- record_types do
        assert NSID.valid_nsid?(type), "#{type} should be valid"
      end
    end

    test "validates common ATProto XRPC methods" do
      methods = [
        "com.atproto.repo.createRecord",
        "com.atproto.repo.getRecord",
        "com.atproto.repo.listRecords",
        "com.atproto.repo.deleteRecord",
        "com.atproto.identity.resolveHandle",
        "com.atproto.server.createSession"
      ]

      for method <- methods do
        assert NSID.valid_nsid?(method), "#{method} should be valid"
      end
    end
  end
end
