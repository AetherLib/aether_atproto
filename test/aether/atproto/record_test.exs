defmodule Aether.ATProto.RecordTest do
  use ExUnit.Case, async: true
  doctest Aether.ATProto.Record

  alias Aether.ATProto.Record

  describe "struct creation" do
    test "creates record with type and data" do
      record = %Record{
        type: "app.bsky.feed.post",
        data: %{"text" => "Hello"}
      }

      assert record.type == "app.bsky.feed.post"
      assert record.data == %{"text" => "Hello"}
      assert record.cid == nil
    end

    test "creates record with CID" do
      record = %Record{
        type: "app.bsky.feed.post",
        data: %{"text" => "Hello"},
        cid: "bafyreib2rxk3rybk"
      }

      assert record.cid == "bafyreib2rxk3rybk"
    end
  end

  describe "from_map/1" do
    test "parses map with $type field" do
      map = %{
        "$type" => "app.bsky.feed.post",
        "text" => "Hello, world!",
        "createdAt" => "2024-01-15T12:00:00Z"
      }

      assert {:ok, record} = Record.from_map(map)
      assert record.type == "app.bsky.feed.post"
      assert record.data["text"] == "Hello, world!"
      assert record.data["createdAt"] == "2024-01-15T12:00:00Z"
      refute Map.has_key?(record.data, "$type")
    end

    test "parses map with $cid field" do
      map = %{
        "$type" => "app.bsky.feed.post",
        "$cid" => "bafyreib2rxk3rybk",
        "text" => "Hello"
      }

      assert {:ok, record} = Record.from_map(map)
      assert record.cid == "bafyreib2rxk3rybk"
      refute Map.has_key?(record.data, "$cid")
    end

    test "parses map with cid field (without $)" do
      map = %{
        "$type" => "app.bsky.feed.post",
        "cid" => "bafyreib2rxk3rybk",
        "text" => "Hello"
      }

      assert {:ok, record} = Record.from_map(map)
      assert record.cid == "bafyreib2rxk3rybk"
      refute Map.has_key?(record.data, "cid")
    end

    test "returns error for missing $type" do
      map = %{"text" => "Hello"}
      assert {:error, :missing_type} = Record.from_map(map)
    end

    test "returns error for invalid type format" do
      map = %{"$type" => "InvalidType", "text" => "Hello"}
      assert {:error, :invalid_type} = Record.from_map(map)
    end

    test "returns error for type without namespace" do
      map = %{"$type" => "post", "text" => "Hello"}
      assert {:error, :invalid_type} = Record.from_map(map)
    end
  end

  describe "to_map/1" do
    test "converts record to map with $type" do
      record = %Record{
        type: "app.bsky.feed.post",
        data: %{"text" => "Hello", "createdAt" => "2024-01-15T12:00:00Z"}
      }

      map = Record.to_map(record)

      assert map["$type"] == "app.bsky.feed.post"
      assert map["text"] == "Hello"
      assert map["createdAt"] == "2024-01-15T12:00:00Z"
    end

    test "includes cid when present" do
      record = %Record{
        type: "app.bsky.feed.post",
        data: %{"text" => "Hello"},
        cid: "bafyreib2rxk3rybk"
      }

      map = Record.to_map(record)

      assert map["$type"] == "app.bsky.feed.post"
      assert map["cid"] == "bafyreib2rxk3rybk"
      assert map["text"] == "Hello"
    end

    test "excludes cid when nil" do
      record = %Record{
        type: "app.bsky.feed.post",
        data: %{"text" => "Hello"},
        cid: nil
      }

      map = Record.to_map(record)

      assert map["$type"] == "app.bsky.feed.post"
      refute Map.has_key?(map, "cid")
    end
  end

  describe "valid_type?/1" do
    test "validates correct NSID format" do
      assert Record.valid_type?("app.bsky.feed.post")
      assert Record.valid_type?("com.example.myapp.record")
      assert Record.valid_type?("io.github.user.custom")
    end

    test "rejects invalid formats" do
      refute Record.valid_type?("InvalidType")
      refute Record.valid_type?("single")
      refute Record.valid_type?("no-namespace")
      refute Record.valid_type?("UPPERCASE.NOT.ALLOWED")
    end

    test "rejects non-string input" do
      refute Record.valid_type?(123)
      refute Record.valid_type?(nil)
      refute Record.valid_type?(%{})
    end
  end

  describe "put_in_data/3" do
    test "updates existing field" do
      record = %Record{
        type: "app.bsky.feed.post",
        data: %{"text" => "Original", "likes" => 10}
      }

      updated = Record.put_in_data(record, "text", "Updated")

      assert updated.data["text"] == "Updated"
      assert updated.data["likes"] == 10
      assert updated.type == record.type
    end

    test "adds new field" do
      record = %Record{
        type: "app.bsky.feed.post",
        data: %{"text" => "Hello"}
      }

      updated = Record.put_in_data(record, "likes", 42)

      assert updated.data["text"] == "Hello"
      assert updated.data["likes"] == 42
    end

    test "returns new record (immutable)" do
      record = %Record{
        type: "app.bsky.feed.post",
        data: %{"text" => "Original"}
      }

      updated = Record.put_in_data(record, "text", "Updated")

      # Original unchanged
      assert record.data["text"] == "Original"
      # New record updated
      assert updated.data["text"] == "Updated"
    end
  end

  describe "get_from_data/3" do
    test "gets existing field" do
      record = %Record{
        type: "app.bsky.feed.post",
        data: %{"text" => "Hello", "likes" => 10}
      }

      assert Record.get_from_data(record, "text") == "Hello"
      assert Record.get_from_data(record, "likes") == 10
    end

    test "returns nil for missing field" do
      record = %Record{
        type: "app.bsky.feed.post",
        data: %{"text" => "Hello"}
      }

      assert Record.get_from_data(record, "missing") == nil
    end

    test "returns default for missing field" do
      record = %Record{
        type: "app.bsky.feed.post",
        data: %{"text" => "Hello"}
      }

      assert Record.get_from_data(record, "likes", 0) == 0
      assert Record.get_from_data(record, "count", 100) == 100
    end
  end

  describe "round-trip conversion" do
    test "from_map and to_map are reversible" do
      original_map = %{
        "$type" => "app.bsky.feed.post",
        "text" => "Hello, world!",
        "createdAt" => "2024-01-15T12:00:00Z",
        "likes" => 42
      }

      {:ok, record} = Record.from_map(original_map)
      result_map = Record.to_map(record)

      assert result_map["$type"] == original_map["$type"]
      assert result_map["text"] == original_map["text"]
      assert result_map["createdAt"] == original_map["createdAt"]
      assert result_map["likes"] == original_map["likes"]
    end

    test "round-trip with CID" do
      original_map = %{
        "$type" => "app.bsky.feed.post",
        "text" => "Hello",
        "cid" => "bafyreib2rxk3rybk"
      }

      {:ok, record} = Record.from_map(original_map)
      result_map = Record.to_map(record)

      assert result_map["$type"] == original_map["$type"]
      assert result_map["text"] == original_map["text"]
      assert result_map["cid"] == original_map["cid"]
    end
  end

  describe "pattern matching" do
    test "can pattern match on type" do
      record = %Record{
        type: "app.bsky.feed.post",
        data: %{"text" => "Hello"}
      }

      case record do
        %Record{type: "app.bsky.feed.post"} -> :ok
        _ -> flunk("Pattern match failed")
      end
    end

    test "can pattern match on data fields via extraction" do
      record = %Record{
        type: "app.bsky.feed.post",
        data: %{"text" => "Hello", "likes" => 10}
      }

      %Record{data: %{"text" => text, "likes" => likes}} = record

      assert text == "Hello"
      assert likes == 10
    end

    test "can update with standard struct syntax" do
      record = %Record{
        type: "app.bsky.feed.post",
        data: %{"text" => "Original"}
      }

      updated = %{record | data: Map.put(record.data, "text", "Updated")}

      assert updated.data["text"] == "Updated"
      assert record.data["text"] == "Original"
    end
  end

  describe "real-world ATProto records" do
    test "parses Bluesky post record" do
      post_map = %{
        "$type" => "app.bsky.feed.post",
        "text" => "Hello from Elixir!",
        "createdAt" => "2024-01-15T12:00:00.000Z",
        "langs" => ["en"]
      }

      assert {:ok, record} = Record.from_map(post_map)
      assert record.type == "app.bsky.feed.post"
      assert record.data["text"] == "Hello from Elixir!"
      assert record.data["langs"] == ["en"]
    end

    test "parses Bluesky profile record" do
      profile_map = %{
        "$type" => "app.bsky.actor.profile",
        "displayName" => "Alice",
        "description" => "Elixir developer",
        "avatar" => %{
          "$type" => "blob",
          "ref" => %{"$link" => "bafyreib2rxk3rybk"},
          "mimeType" => "image/jpeg",
          "size" => 12345
        }
      }

      assert {:ok, record} = Record.from_map(profile_map)
      assert record.type == "app.bsky.actor.profile"
      assert record.data["displayName"] == "Alice"
      assert is_map(record.data["avatar"])
    end

    test "parses Bluesky follow record" do
      follow_map = %{
        "$type" => "app.bsky.graph.follow",
        "subject" => "did:plc:z72i7hdynmk24r6zlsdc6nxd",
        "createdAt" => "2024-01-15T12:00:00.000Z"
      }

      assert {:ok, record} = Record.from_map(follow_map)
      assert record.type == "app.bsky.graph.follow"
      assert String.starts_with?(record.data["subject"], "did:")
    end
  end

  describe "functional idioms" do
    test "chaining updates with pipe" do
      record =
        %Record{type: "app.bsky.feed.post", data: %{"text" => "Original"}}
        |> Record.put_in_data("text", "Updated")
        |> Record.put_in_data("likes", 10)
        |> Record.put_in_data("reposts", 5)

      assert record.data["text"] == "Updated"
      assert record.data["likes"] == 10
      assert record.data["reposts"] == 5
    end

    test "using with for transformation pipeline" do
      map = %{
        "$type" => "app.bsky.feed.post",
        "text" => "Hello",
        "likes" => 0
      }

      result =
        with {:ok, record} <- Record.from_map(map),
             updated = Record.put_in_data(record, "likes", 10),
             final_map = Record.to_map(updated) do
          {:ok, final_map}
        end

      assert {:ok, final_map} = result
      assert final_map["likes"] == 10
    end
  end
end
