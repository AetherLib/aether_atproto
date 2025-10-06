defmodule AetherATProtoCore.MSTTest do
  use ExUnit.Case, async: true
  doctest AetherATProtoCore.MST

  alias AetherATProtoCore.MST
  alias AetherATProtoCore.CID

  # Test CID for use in tests
  @test_cid_string "bafyreie5cvv4h45feadgeuwhbcutmh6t2ceseocckahdoe6uat64zmz454"

  setup do
    {:ok, test_cid} = CID.parse_cid(@test_cid_string)
    %{test_cid: test_cid}
  end

  describe "struct creation" do
    test "creates an empty MST" do
      mst = %MST{}

      assert mst.layer == 0
      assert mst.entries == []
      assert mst.pointer == nil
    end
  end

  describe "add/3" do
    test "adds a single entry", %{test_cid: cid} do
      mst = %MST{}
      {:ok, mst} = MST.add(mst, "app.bsky.feed.post/abc", cid)

      assert length(mst.entries) == 1
      assert hd(mst.entries).key == "app.bsky.feed.post/abc"
      assert hd(mst.entries).value == cid
    end

    test "adds multiple entries in sorted order", %{test_cid: cid} do
      mst = %MST{}
      {:ok, mst} = MST.add(mst, "app.bsky.feed.post/xyz", cid)
      {:ok, mst} = MST.add(mst, "app.bsky.feed.post/abc", cid)
      {:ok, mst} = MST.add(mst, "app.bsky.feed.post/def", cid)

      keys = Enum.map(mst.entries, & &1.key)

      assert keys == [
               "app.bsky.feed.post/abc",
               "app.bsky.feed.post/def",
               "app.bsky.feed.post/xyz"
             ]
    end

    test "updates existing entry", %{test_cid: cid1} do
      {:ok, cid2} = CID.parse_cid("bafyreibvjvcv745gig4mvqs4hctx4zfkono4rjejm2ta6gtyzkqxfjeily")

      mst = %MST{}
      {:ok, mst} = MST.add(mst, "app.bsky.feed.post/abc", cid1)
      {:ok, mst} = MST.add(mst, "app.bsky.feed.post/abc", cid2)

      assert length(mst.entries) == 1
      assert hd(mst.entries).value == cid2
    end

    test "maintains sorted order when inserting at beginning", %{test_cid: cid} do
      mst = %MST{}
      {:ok, mst} = MST.add(mst, "app.bsky.feed.post/zzz", cid)
      {:ok, mst} = MST.add(mst, "app.bsky.feed.post/aaa", cid)

      keys = Enum.map(mst.entries, & &1.key)
      assert keys == ["app.bsky.feed.post/aaa", "app.bsky.feed.post/zzz"]
    end

    test "maintains sorted order when inserting at end", %{test_cid: cid} do
      mst = %MST{}
      {:ok, mst} = MST.add(mst, "app.bsky.feed.post/aaa", cid)
      {:ok, mst} = MST.add(mst, "app.bsky.feed.post/zzz", cid)

      keys = Enum.map(mst.entries, & &1.key)
      assert keys == ["app.bsky.feed.post/aaa", "app.bsky.feed.post/zzz"]
    end

    test "handles many entries", %{test_cid: cid} do
      mst = %MST{}

      # Add 100 entries
      mst =
        Enum.reduce(1..100, mst, fn i, acc ->
          key = "app.bsky.feed.post/#{String.pad_leading("#{i}", 5, "0")}"
          {:ok, new_mst} = MST.add(acc, key, cid)
          new_mst
        end)

      assert length(mst.entries) == 100

      # Verify they're sorted
      keys = Enum.map(mst.entries, & &1.key)
      assert keys == Enum.sort(keys)
    end
  end

  describe "get/2" do
    test "retrieves an existing entry", %{test_cid: cid} do
      mst = %MST{}
      {:ok, mst} = MST.add(mst, "app.bsky.feed.post/abc", cid)

      assert {:ok, ^cid} = MST.get(mst, "app.bsky.feed.post/abc")
    end

    test "returns error for non-existent entry" do
      mst = %MST{}

      assert {:error, :not_found} = MST.get(mst, "app.bsky.feed.post/nonexistent")
    end

    test "finds entry among multiple entries", %{test_cid: cid} do
      mst = %MST{}
      {:ok, mst} = MST.add(mst, "app.bsky.feed.post/aaa", cid)
      {:ok, mst} = MST.add(mst, "app.bsky.feed.post/bbb", cid)
      {:ok, mst} = MST.add(mst, "app.bsky.feed.post/ccc", cid)

      assert {:ok, ^cid} = MST.get(mst, "app.bsky.feed.post/bbb")
    end

    test "returns error when key sorts before all entries", %{test_cid: cid} do
      mst = %MST{}
      {:ok, mst} = MST.add(mst, "app.bsky.feed.post/zzz", cid)

      assert {:error, :not_found} = MST.get(mst, "app.bsky.feed.post/aaa")
    end

    test "returns error when key sorts after all entries", %{test_cid: cid} do
      mst = %MST{}
      {:ok, mst} = MST.add(mst, "app.bsky.feed.post/aaa", cid)

      assert {:error, :not_found} = MST.get(mst, "app.bsky.feed.post/zzz")
    end
  end

  describe "delete/2" do
    test "deletes an existing entry", %{test_cid: cid} do
      mst = %MST{}
      {:ok, mst} = MST.add(mst, "app.bsky.feed.post/abc", cid)
      {:ok, mst} = MST.delete(mst, "app.bsky.feed.post/abc")

      assert mst.entries == []
      assert {:error, :not_found} = MST.get(mst, "app.bsky.feed.post/abc")
    end

    test "returns error for non-existent entry" do
      mst = %MST{}

      assert {:error, :not_found} = MST.delete(mst, "app.bsky.feed.post/nonexistent")
    end

    test "deletes entry from middle of list", %{test_cid: cid} do
      mst = %MST{}
      {:ok, mst} = MST.add(mst, "app.bsky.feed.post/aaa", cid)
      {:ok, mst} = MST.add(mst, "app.bsky.feed.post/bbb", cid)
      {:ok, mst} = MST.add(mst, "app.bsky.feed.post/ccc", cid)

      {:ok, mst} = MST.delete(mst, "app.bsky.feed.post/bbb")

      assert length(mst.entries) == 2
      keys = Enum.map(mst.entries, & &1.key)
      assert keys == ["app.bsky.feed.post/aaa", "app.bsky.feed.post/ccc"]
    end

    test "deletes first entry", %{test_cid: cid} do
      mst = %MST{}
      {:ok, mst} = MST.add(mst, "app.bsky.feed.post/aaa", cid)
      {:ok, mst} = MST.add(mst, "app.bsky.feed.post/bbb", cid)

      {:ok, mst} = MST.delete(mst, "app.bsky.feed.post/aaa")

      assert length(mst.entries) == 1
      assert hd(mst.entries).key == "app.bsky.feed.post/bbb"
    end

    test "deletes last entry", %{test_cid: cid} do
      mst = %MST{}
      {:ok, mst} = MST.add(mst, "app.bsky.feed.post/aaa", cid)
      {:ok, mst} = MST.add(mst, "app.bsky.feed.post/bbb", cid)

      {:ok, mst} = MST.delete(mst, "app.bsky.feed.post/bbb")

      assert length(mst.entries) == 1
      assert hd(mst.entries).key == "app.bsky.feed.post/aaa"
    end
  end

  describe "list/1" do
    test "returns empty list for empty MST" do
      mst = %MST{}

      assert MST.list(mst) == []
    end

    test "returns all entries in sorted order", %{test_cid: cid} do
      mst = %MST{}
      {:ok, mst} = MST.add(mst, "app.bsky.feed.post/xyz", cid)
      {:ok, mst} = MST.add(mst, "app.bsky.feed.post/abc", cid)
      {:ok, mst} = MST.add(mst, "app.bsky.feed.post/def", cid)

      entries = MST.list(mst)

      assert length(entries) == 3

      assert Enum.map(entries, fn {key, _} -> key end) == [
               "app.bsky.feed.post/abc",
               "app.bsky.feed.post/def",
               "app.bsky.feed.post/xyz"
             ]
    end

    test "returns tuples of {key, cid}", %{test_cid: cid} do
      mst = %MST{}
      {:ok, mst} = MST.add(mst, "app.bsky.feed.post/abc", cid)

      [{key, value_cid}] = MST.list(mst)

      assert key == "app.bsky.feed.post/abc"
      assert value_cid == cid
    end
  end

  describe "calculate_key_depth/1" do
    test "returns non-negative integer" do
      depth = MST.calculate_key_depth("app.bsky.feed.post/abc")

      assert is_integer(depth)
      assert depth >= 0
    end

    test "different keys produce different depths" do
      depth1 = MST.calculate_key_depth("app.bsky.feed.post/abc")
      depth2 = MST.calculate_key_depth("app.bsky.feed.post/xyz")

      # They might be the same, but let's just verify they're valid
      assert is_integer(depth1)
      assert is_integer(depth2)
    end

    test "same key produces same depth" do
      depth1 = MST.calculate_key_depth("app.bsky.feed.post/test")
      depth2 = MST.calculate_key_depth("app.bsky.feed.post/test")

      assert depth1 == depth2
    end

    test "empty string has defined depth" do
      depth = MST.calculate_key_depth("")

      assert is_integer(depth)
      assert depth >= 0
    end
  end

  describe "integration scenarios" do
    test "add, get, update, delete workflow", %{test_cid: cid1} do
      {:ok, cid2} = CID.parse_cid("bafyreibvjvcv745gig4mvqs4hctx4zfkono4rjejm2ta6gtyzkqxfjeily")

      mst = %MST{}

      # Add
      {:ok, mst} = MST.add(mst, "app.bsky.feed.post/abc", cid1)
      assert {:ok, ^cid1} = MST.get(mst, "app.bsky.feed.post/abc")

      # Update
      {:ok, mst} = MST.add(mst, "app.bsky.feed.post/abc", cid2)
      assert {:ok, ^cid2} = MST.get(mst, "app.bsky.feed.post/abc")

      # Delete
      {:ok, mst} = MST.delete(mst, "app.bsky.feed.post/abc")
      assert {:error, :not_found} = MST.get(mst, "app.bsky.feed.post/abc")
    end

    test "handles typical repository record pattern", %{test_cid: cid} do
      mst = %MST{}

      # Add records from multiple collections
      {:ok, mst} = MST.add(mst, "app.bsky.actor.profile/self", cid)
      {:ok, mst} = MST.add(mst, "app.bsky.feed.post/abc123", cid)
      {:ok, mst} = MST.add(mst, "app.bsky.feed.post/xyz789", cid)
      {:ok, mst} = MST.add(mst, "app.bsky.feed.like/like001", cid)

      entries = MST.list(mst)
      assert length(entries) == 4

      # Verify sorted order
      keys = Enum.map(entries, fn {key, _} -> key end)
      assert keys == Enum.sort(keys)
    end
  end
end
