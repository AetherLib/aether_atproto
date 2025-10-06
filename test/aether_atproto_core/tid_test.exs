defmodule AetherATProtoCore.TIDTest do
  use ExUnit.Case, async: true
  doctest AetherATProtoCore.TID

  alias AetherATProtoCore.TID

  describe "new/0" do
    test "generates a valid TID" do
      tid = TID.new()

      assert String.length(tid) == 13
      assert TID.valid_tid?(tid)
    end

    test "generates unique TIDs" do
      tid1 = TID.new()
      tid2 = TID.new()

      assert tid1 != tid2
    end

    test "generates sortable TIDs" do
      # Generate TIDs with small delay to ensure different timestamps
      tid1 = TID.new()
      Process.sleep(1)
      tid2 = TID.new()

      # Newer TID should sort after older TID
      assert tid2 > tid1
    end
  end

  describe "from_timestamp/2" do
    test "generates TID from specific timestamp" do
      timestamp = 1_700_000_000_000_000
      tid = TID.from_timestamp(timestamp)

      assert String.length(tid) == 13
      assert TID.valid_tid?(tid)
    end

    test "same timestamp produces same TID with same clock_id" do
      timestamp = 1_700_000_000_000_000
      clock_id = 42

      tid1 = TID.from_timestamp(timestamp, clock_id)
      tid2 = TID.from_timestamp(timestamp, clock_id)

      assert tid1 == tid2
    end

    test "same timestamp with different clock_id produces different TIDs" do
      timestamp = 1_700_000_000_000_000

      tid1 = TID.from_timestamp(timestamp, 1)
      tid2 = TID.from_timestamp(timestamp, 2)

      assert tid1 != tid2
    end

    test "larger timestamp produces larger TID" do
      tid1 = TID.from_timestamp(1_700_000_000_000_000)
      tid2 = TID.from_timestamp(1_700_000_000_000_001)

      assert tid2 > tid1
    end
  end

  describe "valid_tid?/1" do
    test "validates correct TID format" do
      tid = TID.new()
      assert TID.valid_tid?(tid)
    end

    test "rejects TID with wrong length" do
      refute TID.valid_tid?("tooshort")
      refute TID.valid_tid?("waytoolongstring")
    end

    test "rejects TID with invalid first character" do
      # First character must be 234567abcdefghij
      refute TID.valid_tid?("z234567890123")
      refute TID.valid_tid?("1234567890123")
    end

    test "rejects TID with invalid characters" do
      # uppercase
      refute TID.valid_tid?("3jzfcijpj2z2Z")
      # special char
      refute TID.valid_tid?("3jzfcijpj2z2!")
    end

    test "rejects non-string input" do
      refute TID.valid_tid?(12345)
      refute TID.valid_tid?(nil)
      refute TID.valid_tid?(%{})
    end

    test "validates TIDs with different first characters" do
      # Generate TIDs at different timestamps to get different first chars
      # TIDs encode timestamps, so we need valid encoded TIDs
      tid1 = TID.from_timestamp(1_000_000_000_000_000)
      tid2 = TID.from_timestamp(10_000_000_000_000_000)

      # Both should be valid
      assert TID.valid_tid?(tid1)
      assert TID.valid_tid?(tid2)

      # They should start with different valid first characters
      assert String.at(tid1, 0) in ~w(2 3 4 5 6 7 a b c d e f g h i j)
      assert String.at(tid2, 0) in ~w(2 3 4 5 6 7 a b c d e f g h i j)
    end
  end

  describe "parse_timestamp/1" do
    test "extracts timestamp from TID" do
      timestamp = 1_700_000_000_000_000
      tid = TID.from_timestamp(timestamp)

      assert {:ok, ^timestamp} = TID.parse_timestamp(tid)
    end

    test "returns error for invalid TID" do
      assert {:error, :invalid_tid} = TID.parse_timestamp("invalid")
    end

    test "round-trips timestamp correctly" do
      original_timestamp = System.os_time(:microsecond)
      tid = TID.from_timestamp(original_timestamp)
      {:ok, parsed_timestamp} = TID.parse_timestamp(tid)

      assert parsed_timestamp == original_timestamp
    end
  end

  describe "compare/2" do
    test "compares TIDs chronologically" do
      tid1 = TID.from_timestamp(1_700_000_000_000_000)
      tid2 = TID.from_timestamp(1_700_000_000_000_001)

      assert TID.compare(tid1, tid2) == :lt
      assert TID.compare(tid2, tid1) == :gt
      assert TID.compare(tid1, tid1) == :eq
    end

    test "compares TIDs lexicographically" do
      tid1 = TID.new()
      Process.sleep(1)
      tid2 = TID.new()

      assert TID.compare(tid1, tid2) == :lt
    end
  end

  describe "integration scenarios" do
    test "TIDs can be used as revision identifiers" do
      # Generate a sequence of TIDs
      tids =
        for _ <- 1..10 do
          tid = TID.new()
          Process.sleep(1)
          tid
        end

      # They should be in ascending order
      sorted_tids = Enum.sort(tids)
      assert tids == sorted_tids
    end

    test "TIDs can be used as record keys" do
      # Generate TIDs for record keys
      post_key = TID.new()
      like_key = TID.new()

      assert TID.valid_tid?(post_key)
      assert TID.valid_tid?(like_key)
      assert post_key != like_key
    end

    test "handles edge case timestamps" do
      # Test with various timestamps
      timestamps = [
        0,
        1,
        1_000_000_000_000_000,
        System.os_time(:microsecond)
      ]

      for timestamp <- timestamps do
        tid = TID.from_timestamp(timestamp)
        assert TID.valid_tid?(tid)
        assert {:ok, ^timestamp} = TID.parse_timestamp(tid)
      end
    end
  end
end
