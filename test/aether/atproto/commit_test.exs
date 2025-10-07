defmodule Aether.ATProto.CommitTest do
  use ExUnit.Case, async: true
  doctest Aether.ATProto.Commit

  alias Aether.ATProto.Commit
  alias Aether.ATProto.CID
  alias Aether.ATProto.TID

  setup do
    {:ok, mst_cid} = CID.parse_cid("bafyreie5cvv4h45feadgeuwhbcutmh6t2ceseocckahdoe6uat64zmz454")
    {:ok, prev_cid} = CID.parse_cid("bafyreibvjvcv745gig4mvqs4hctx4zfkono4rjejm2ta6gtyzkqxfjeily")

    %{mst_cid: mst_cid, prev_cid: prev_cid}
  end

  describe "create/3" do
    test "creates a new unsigned commit", %{mst_cid: cid} do
      commit = Commit.create("did:plc:abc123", cid)

      assert commit.did == "did:plc:abc123"
      assert commit.version == 3
      assert commit.data == cid
      assert TID.valid_tid?(commit.rev)
      assert commit.prev == nil
      assert commit.sig == nil
    end

    test "accepts custom revision", %{mst_cid: cid} do
      custom_rev = TID.new()
      commit = Commit.create("did:plc:abc123", cid, rev: custom_rev)

      assert commit.rev == custom_rev
    end

    test "accepts prev option", %{mst_cid: cid, prev_cid: prev_cid} do
      commit = Commit.create("did:plc:abc123", cid, prev: prev_cid)

      assert commit.prev == prev_cid
    end
  end

  describe "create_next/4" do
    test "creates commit with prev reference", %{mst_cid: cid, prev_cid: prev_cid} do
      commit = Commit.create_next("did:plc:abc123", cid, prev_cid)

      assert commit.prev == prev_cid
      assert commit.did == "did:plc:abc123"
      assert commit.data == cid
    end

    test "generates new revision greater than previous", %{mst_cid: cid, prev_cid: prev_cid} do
      prev_rev = TID.new()
      Process.sleep(1)

      commit = Commit.create_next("did:plc:abc123", cid, prev_cid)

      assert commit.rev > prev_rev
    end
  end

  describe "sign/2" do
    test "signs a commit with signing function", %{mst_cid: cid} do
      commit = Commit.create("did:plc:abc123", cid)

      signing_fn = fn _bytes -> <<1, 2, 3, 4>> end

      {:ok, signed_commit} = Commit.sign(commit, signing_fn)

      assert signed_commit.sig == <<1, 2, 3, 4>>
      assert Commit.signed?(signed_commit)
    end

    test "signing function receives commit bytes", %{mst_cid: cid} do
      commit = Commit.create("did:plc:abc123", cid)

      signing_fn = fn bytes ->
        assert is_binary(bytes)
        assert byte_size(bytes) > 0
        <<1, 2, 3>>
      end

      {:ok, _signed} = Commit.sign(commit, signing_fn)
    end

    test "returns error if signing fails", %{mst_cid: cid} do
      commit = Commit.create("did:plc:abc123", cid)

      signing_fn = fn _bytes -> raise "signing failed" end

      assert {:error, {:signing_failed, _}} = Commit.sign(commit, signing_fn)
    end
  end

  describe "verify/2" do
    test "verifies a valid signature", %{mst_cid: cid} do
      commit = Commit.create("did:plc:abc123", cid)

      # Sign the commit
      signing_fn = fn _bytes -> <<1, 2, 3>> end
      {:ok, signed_commit} = Commit.sign(commit, signing_fn)

      # Verify with matching function
      verify_fn = fn _bytes, sig -> sig == <<1, 2, 3>> end

      assert {:ok, true} = Commit.verify(signed_commit, verify_fn)
    end

    test "rejects invalid signature", %{mst_cid: cid} do
      commit = Commit.create("did:plc:abc123", cid)

      signing_fn = fn _bytes -> <<1, 2, 3>> end
      {:ok, signed_commit} = Commit.sign(commit, signing_fn)

      # Verify with non-matching function
      verify_fn = fn _bytes, _sig -> false end

      assert {:ok, false} = Commit.verify(signed_commit, verify_fn)
    end

    test "returns error for unsigned commit", %{mst_cid: cid} do
      commit = Commit.create("did:plc:abc123", cid)

      verify_fn = fn _bytes, _sig -> true end

      assert {:error, :unsigned_commit} = Commit.verify(commit, verify_fn)
    end

    test "verification function receives commit bytes and signature", %{mst_cid: cid} do
      commit = Commit.create("did:plc:abc123", cid)

      signing_fn = fn _bytes -> <<1, 2, 3>> end
      {:ok, signed_commit} = Commit.sign(commit, signing_fn)

      verify_fn = fn bytes, sig ->
        assert is_binary(bytes)
        assert byte_size(bytes) > 0
        assert sig == <<1, 2, 3>>
        true
      end

      {:ok, true} = Commit.verify(signed_commit, verify_fn)
    end

    test "returns error if verification fails", %{mst_cid: cid} do
      commit = Commit.create("did:plc:abc123", cid)

      signing_fn = fn _bytes -> <<1, 2, 3>> end
      {:ok, signed_commit} = Commit.sign(commit, signing_fn)

      verify_fn = fn _bytes, _sig -> raise "verification failed" end

      assert {:error, {:verification_failed, _}} = Commit.verify(signed_commit, verify_fn)
    end
  end

  describe "signed?/1" do
    test "returns false for unsigned commit", %{mst_cid: cid} do
      commit = Commit.create("did:plc:abc123", cid)

      refute Commit.signed?(commit)
    end

    test "returns true for signed commit", %{mst_cid: cid} do
      commit = Commit.create("did:plc:abc123", cid)
      signing_fn = fn _bytes -> <<1, 2, 3>> end
      {:ok, signed_commit} = Commit.sign(commit, signing_fn)

      assert Commit.signed?(signed_commit)
    end
  end

  describe "validate/1" do
    test "validates a correct commit", %{mst_cid: cid} do
      commit = Commit.create("did:plc:abc123", cid)

      assert :ok = Commit.validate(commit)
    end

    test "rejects commit with invalid DID", %{mst_cid: cid} do
      commit = %Commit{
        did: "not-a-did",
        version: 3,
        data: cid,
        rev: TID.new()
      }

      assert {:error, :invalid_did} = Commit.validate(commit)
    end

    test "rejects commit with invalid version", %{mst_cid: cid} do
      commit = %Commit{
        did: "did:plc:abc123",
        version: 99,
        data: cid,
        rev: TID.new()
      }

      assert {:error, :invalid_version} = Commit.validate(commit)
    end

    test "rejects commit with invalid data CID", %{} do
      commit = %Commit{
        did: "did:plc:abc123",
        version: 3,
        data: "not-a-cid",
        rev: TID.new()
      }

      assert {:error, :invalid_data_cid} = Commit.validate(commit)
    end

    test "rejects commit with invalid revision", %{mst_cid: cid} do
      commit = %Commit{
        did: "did:plc:abc123",
        version: 3,
        data: cid,
        rev: "invalid-tid"
      }

      assert {:error, :invalid_rev} = Commit.validate(commit)
    end

    test "rejects commit with invalid prev CID", %{mst_cid: cid} do
      commit = %Commit{
        did: "did:plc:abc123",
        version: 3,
        data: cid,
        rev: TID.new(),
        prev: "not-a-cid"
      }

      assert {:error, :invalid_prev_cid} = Commit.validate(commit)
    end

    test "accepts commit with valid prev CID", %{mst_cid: cid, prev_cid: prev_cid} do
      commit = Commit.create_next("did:plc:abc123", cid, prev_cid)

      assert :ok = Commit.validate(commit)
    end
  end

  describe "compare_revs/2" do
    test "compares revisions correctly" do
      rev1 = TID.from_timestamp(1_700_000_000_000_000)
      rev2 = TID.from_timestamp(1_700_000_000_000_001)

      assert Commit.compare_revs(rev2, rev1) == :gt
      assert Commit.compare_revs(rev1, rev2) == :lt
      assert Commit.compare_revs(rev1, rev1) == :eq
    end
  end

  describe "integration scenarios" do
    test "create and sign workflow", %{mst_cid: cid} do
      # Create commit
      commit = Commit.create("did:plc:abc123", cid)
      assert Commit.validate(commit) == :ok
      refute Commit.signed?(commit)

      # Sign commit
      signing_fn = fn _bytes -> <<1, 2, 3, 4, 5>> end
      {:ok, signed_commit} = Commit.sign(commit, signing_fn)
      assert Commit.signed?(signed_commit)

      # Verify commit
      verify_fn = fn _bytes, sig -> sig == <<1, 2, 3, 4, 5>> end
      assert {:ok, true} = Commit.verify(signed_commit, verify_fn)
    end

    test "commit chain with increasing revisions", %{mst_cid: cid} do
      # Create initial commit
      commit1 = Commit.create("did:plc:abc123", cid)
      rev1 = commit1.rev

      # Simulate signing and getting CID
      {:ok, commit1_cid} =
        CID.parse_cid("bafyreie5cvv4h45feadgeuwhbcutmh6t2ceseocckahdoe6uat64zmz454")

      Process.sleep(1)

      # Create next commit
      commit2 = Commit.create_next("did:plc:abc123", cid, commit1_cid)
      rev2 = commit2.rev

      # Revisions should be increasing
      assert Commit.compare_revs(rev2, rev1) == :gt
      assert commit2.prev == commit1_cid
    end

    test "validates complete commit lifecycle", %{mst_cid: cid} do
      # Create
      commit = Commit.create("did:plc:abc123", cid)
      assert :ok = Commit.validate(commit)

      # Sign
      signing_fn = fn bytes -> :crypto.hash(:sha256, bytes) end
      {:ok, signed} = Commit.sign(commit, signing_fn)
      assert :ok = Commit.validate(signed)

      # Verify
      verify_fn = fn bytes, sig ->
        expected = :crypto.hash(:sha256, bytes)
        sig == expected
      end

      assert {:ok, true} = Commit.verify(signed, verify_fn)
    end
  end
end
