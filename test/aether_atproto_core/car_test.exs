defmodule AetherATProtoCore.CARTest do
  use ExUnit.Case, async: true
  doctest AetherATProtoCore.CAR

  alias AetherATProtoCore.CAR
  alias AetherATProtoCore.CAR.Block
  alias AetherATProtoCore.CID

  setup do
    {:ok, cid1} = CID.parse_cid("bafyreie5cvv4h45feadgeuwhbcutmh6t2ceseocckahdoe6uat64zmz454")
    {:ok, cid2} = CID.parse_cid("bafyreibvjvcv745gig4mvqs4hctx4zfkono4rjejm2ta6gtyzkqxfjeily")

    %{cid1: cid1, cid2: cid2}
  end

  describe "struct creation" do
    test "creates empty CAR", %{cid1: cid} do
      car = %CAR{roots: [cid]}

      assert car.version == 1
      assert car.roots == [cid]
      assert car.blocks == []
    end

    test "creates CAR with blocks", %{cid1: cid} do
      block = %Block{cid: cid, data: <<1, 2, 3>>}
      car = %CAR{roots: [cid], blocks: [block]}

      assert length(car.blocks) == 1
    end
  end

  describe "encode/1 and decode/1" do
    test "encodes and decodes empty CAR", %{cid1: cid} do
      car = %CAR{roots: [cid], blocks: []}

      {:ok, binary} = CAR.encode(car)
      assert is_binary(binary)

      {:ok, decoded} = CAR.decode(binary)
      assert decoded.version == 1
      assert length(decoded.roots) == 1
    end

    test "encodes and decodes CAR with single block", %{cid1: cid} do
      block = %Block{cid: cid, data: <<1, 2, 3>>}
      car = %CAR{roots: [cid], blocks: [block]}

      {:ok, binary} = CAR.encode(car)
      {:ok, decoded} = CAR.decode(binary)

      assert decoded.version == 1
      assert length(decoded.blocks) == 1
    end

    test "encodes and decodes CAR with multiple blocks", %{cid1: cid1, cid2: cid2} do
      blocks = [
        %Block{cid: cid1, data: <<1, 2, 3>>},
        %Block{cid: cid2, data: <<4, 5, 6, 7>>}
      ]

      car = %CAR{roots: [cid1], blocks: blocks}

      {:ok, binary} = CAR.encode(car)
      {:ok, decoded} = CAR.decode(binary)

      assert decoded.version == 1
      assert length(decoded.blocks) == 2
    end

    test "encodes and decodes CAR with large block data", %{cid1: cid} do
      large_data = :crypto.strong_rand_bytes(10_000)
      block = %Block{cid: cid, data: large_data}
      car = %CAR{roots: [cid], blocks: [block]}

      {:ok, binary} = CAR.encode(car)
      {:ok, decoded} = CAR.decode(binary)

      assert length(decoded.blocks) == 1
    end
  end

  describe "get_block/2" do
    test "retrieves block by CID", %{cid1: cid} do
      block = %Block{cid: cid, data: <<1, 2, 3>>}
      car = %CAR{blocks: [block]}

      assert {:ok, found} = CAR.get_block(car, cid)
      assert found.data == <<1, 2, 3>>
    end

    test "returns error for non-existent CID", %{cid1: cid1, cid2: cid2} do
      block = %Block{cid: cid1, data: <<1, 2, 3>>}
      car = %CAR{blocks: [block]}

      assert {:error, :not_found} = CAR.get_block(car, cid2)
    end

    test "finds correct block among multiple blocks", %{cid1: cid1, cid2: cid2} do
      blocks = [
        %Block{cid: cid1, data: <<1, 2, 3>>},
        %Block{cid: cid2, data: <<4, 5, 6>>}
      ]

      car = %CAR{blocks: blocks}

      assert {:ok, block1} = CAR.get_block(car, cid1)
      assert block1.data == <<1, 2, 3>>

      assert {:ok, block2} = CAR.get_block(car, cid2)
      assert block2.data == <<4, 5, 6>>
    end
  end

  describe "list_blocks/1" do
    test "returns empty list for CAR with no blocks" do
      car = %CAR{blocks: []}

      assert CAR.list_blocks(car) == []
    end

    test "returns all blocks", %{cid1: cid1, cid2: cid2} do
      blocks = [
        %Block{cid: cid1, data: <<1, 2, 3>>},
        %Block{cid: cid2, data: <<4, 5, 6>>}
      ]

      car = %CAR{blocks: blocks}

      listed = CAR.list_blocks(car)
      assert length(listed) == 2
    end
  end

  describe "integration scenarios" do
    test "repository export pattern", %{cid1: commit_cid, cid2: mst_cid} do
      # Simulate repository export
      commit_data = :erlang.term_to_binary(%{type: :commit})
      mst_data = :erlang.term_to_binary(%{type: :mst})

      blocks = [
        %Block{cid: commit_cid, data: commit_data},
        %Block{cid: mst_cid, data: mst_data}
      ]

      # First root is the commit
      car = %CAR{roots: [commit_cid], blocks: blocks}

      # Encode to file
      {:ok, binary} = CAR.encode(car)

      # Decode from file
      {:ok, decoded} = CAR.decode(binary)

      # Verify structure
      assert hd(decoded.roots) == commit_cid
      assert length(decoded.blocks) == 2

      # Retrieve blocks
      {:ok, commit_block} = CAR.get_block(decoded, commit_cid)
      {:ok, mst_block} = CAR.get_block(decoded, mst_cid)

      assert is_binary(commit_block.data)
      assert is_binary(mst_block.data)
    end

    test "handles empty repository", %{cid1: cid} do
      # Empty repo with just a root
      car = %CAR{roots: [cid], blocks: []}

      {:ok, binary} = CAR.encode(car)
      {:ok, decoded} = CAR.decode(binary)

      assert decoded.roots == [cid]
      assert decoded.blocks == []
    end

    test "handles repository with many blocks", %{cid1: cid} do
      # Generate many blocks
      blocks =
        for i <- 1..100 do
          %Block{cid: cid, data: <<i>>}
        end

      car = %CAR{roots: [cid], blocks: blocks}

      {:ok, binary} = CAR.encode(car)
      {:ok, decoded} = CAR.decode(binary)

      assert length(decoded.blocks) == 100
    end
  end
end
