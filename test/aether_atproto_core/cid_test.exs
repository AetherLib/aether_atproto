defmodule AetherATProtoCore.CIDTest do
  use ExUnit.Case, async: true
  doctest AetherATProtoCore.CID

  describe "parse_cid/1" do
    test "parses valid CIDv0" do
      cid_v0 = "QmY7Yh4UquoXHLPFo2XbhXkhBvFoPwmQUSa92pxnxjQuPU"

      assert {:ok, %AetherATProtoCore.CID{}} = AetherATProtoCore.CID.parse_cid(cid_v0)

      assert {:ok,
              %AetherATProtoCore.CID{
                version: 0,
                codec: "dag-pb",
                hash: ^cid_v0,
                multibase: "base58btc"
              }} =
               AetherATProtoCore.CID.parse_cid(cid_v0)
    end

    test "parses valid CIDv1 base32" do
      cid_v1 = "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"

      assert {:ok, %AetherATProtoCore.CID{}} = AetherATProtoCore.CID.parse_cid(cid_v1)

      assert {:ok,
              %AetherATProtoCore.CID{
                version: 1,
                codec: "dag-cbor",
                hash: ^cid_v1,
                multibase: "base32"
              }} =
               AetherATProtoCore.CID.parse_cid(cid_v1)
    end

    test "parses valid CIDv1 base58" do
      cid_v1_base58 = "zdj7WkLmG2I5E5NTd2y1Hy2fx2c3nK1cC1NvJZ7kY7fYx1cYq"

      assert {:ok, %AetherATProtoCore.CID{}} = AetherATProtoCore.CID.parse_cid(cid_v1_base58)

      assert {:ok,
              %AetherATProtoCore.CID{
                version: 1,
                codec: "dag-cbor",
                hash: ^cid_v1_base58,
                multibase: "base58btc"
              }} = AetherATProtoCore.CID.parse_cid(cid_v1_base58)
    end

    test "returns error for invalid CID format" do
      assert {:error, :invalid_format} = AetherATProtoCore.CID.parse_cid("invalid_cid")
      assert {:error, :invalid_format} = AetherATProtoCore.CID.parse_cid("")
      assert {:error, :invalid_format} = AetherATProtoCore.CID.parse_cid("QmInvalidLength")
    end

    test "returns error for CIDv0 with wrong length" do
      assert {:error, :invalid_format} = AetherATProtoCore.CID.parse_cid("QmTooShort")

      assert {:error, :invalid_format} =
               AetherATProtoCore.CID.parse_cid("Qm" <> String.duplicate("a", 50))
    end
  end

  describe "parse_cid!/1" do
    test "returns CID struct for valid CID" do
      cid_v0 = "QmY7Yh4UquoXHLPFo2XbhXkhBvFoPwmQUSa92pxnxjQuPU"

      cid = AetherATProtoCore.CID.parse_cid!(cid_v0)
      assert %AetherATProtoCore.CID{version: 0, hash: ^cid_v0, multibase: "base58btc"} = cid
    end

    test "raises ParseError for invalid CID" do
      assert_raise AetherATProtoCore.CID.ParseError, fn ->
        AetherATProtoCore.CID.parse_cid!("invalid_cid")
      end

      assert_raise AetherATProtoCore.CID.ParseError, fn ->
        AetherATProtoCore.CID.parse_cid!(nil)
      end
    end

    test "returns CID struct when passed a CID struct" do
      cid_struct = %AetherATProtoCore.CID{version: 1, hash: "test"}
      assert ^cid_struct = AetherATProtoCore.CID.parse_cid!(cid_struct)
    end
  end

  describe "valid_cid?/1" do
    test "returns true for valid CID strings" do
      assert AetherATProtoCore.CID.valid_cid?("QmY7Yh4UquoXHLPFo2XbhXkhBvFoPwmQUSa92pxnxjQuPU")

      assert AetherATProtoCore.CID.valid_cid?(
               "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"
             )
    end

    test "returns true for CID structs" do
      cid_struct = %AetherATProtoCore.CID{version: 1, hash: "test"}
      assert AetherATProtoCore.CID.valid_cid?(cid_struct)
    end

    test "returns false for invalid inputs" do
      refute AetherATProtoCore.CID.valid_cid?("invalid")
      refute AetherATProtoCore.CID.valid_cid?(nil)
      refute AetherATProtoCore.CID.valid_cid?(123)
      refute AetherATProtoCore.CID.valid_cid?(%{})
    end
  end

  describe "cid_to_string/1" do
    test "returns hash from CID struct" do
      hash = "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"
      cid = %AetherATProtoCore.CID{hash: hash}

      assert AetherATProtoCore.CID.cid_to_string(cid) == hash
    end

    test "returns string when passed a string" do
      hash = "test_hash"
      assert AetherATProtoCore.CID.cid_to_string(hash) == hash
    end
  end

  describe "cid_version/1" do
    test "returns version for CID strings" do
      assert AetherATProtoCore.CID.cid_version("QmY7Yh4UquoXHLPFo2XbhXkhBvFoPwmQUSa92pxnxjQuPU") ==
               0

      assert AetherATProtoCore.CID.cid_version(
               "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"
             ) ==
               1
    end

    test "returns version for CID structs" do
      cid_v0 = %AetherATProtoCore.CID{version: 0, hash: "test"}
      cid_v1 = %AetherATProtoCore.CID{version: 1, hash: "test"}

      assert AetherATProtoCore.CID.cid_version(cid_v0) == 0
      assert AetherATProtoCore.CID.cid_version(cid_v1) == 1
    end

    test "returns error for invalid CID" do
      assert AetherATProtoCore.CID.cid_version("invalid") == {:error, :invalid_cid}
    end
  end

  describe "cid_codec/1" do
    test "returns codec for CID strings" do
      assert AetherATProtoCore.CID.cid_codec("QmY7Yh4UquoXHLPFo2XbhXkhBvFoPwmQUSa92pxnxjQuPU") ==
               "dag-pb"

      assert AetherATProtoCore.CID.cid_codec(
               "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"
             ) ==
               "dag-cbor"
    end

    test "returns codec for CID structs" do
      cid = %AetherATProtoCore.CID{codec: "dag-cbor", hash: "test"}
      assert AetherATProtoCore.CID.cid_codec(cid) == "dag-cbor"
    end

    test "returns error for invalid CID" do
      assert AetherATProtoCore.CID.cid_codec("invalid") == {:error, :invalid_cid}
    end
  end

  describe "is_cidv0?/1" do
    test "returns true for CIDv0 strings" do
      assert AetherATProtoCore.CID.is_cidv0?("QmY7Yh4UquoXHLPFo2XbhXkhBvFoPwmQUSa92pxnxjQuPU")
    end

    test "returns true for CIDv0 structs" do
      cid = %AetherATProtoCore.CID{version: 0, hash: "test"}
      assert AetherATProtoCore.CID.is_cidv0?(cid)
    end

    test "returns false for CIDv1" do
      refute AetherATProtoCore.CID.is_cidv0?(
               "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"
             )

      cid_v1 = %AetherATProtoCore.CID{version: 1, hash: "test"}
      refute AetherATProtoCore.CID.is_cidv0?(cid_v1)
    end

    test "returns false for invalid inputs" do
      refute AetherATProtoCore.CID.is_cidv0?("invalid")
      refute AetherATProtoCore.CID.is_cidv0?(nil)
    end
  end

  describe "is_cidv1?/1" do
    test "returns true for CIDv1 strings" do
      assert AetherATProtoCore.CID.is_cidv1?(
               "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"
             )
    end

    test "returns true for CIDv1 structs" do
      cid = %AetherATProtoCore.CID{version: 1, hash: "test"}
      assert AetherATProtoCore.CID.is_cidv1?(cid)
    end

    test "returns false for CIDv0" do
      refute AetherATProtoCore.CID.is_cidv1?("QmY7Yh4UquoXHLPFo2XbhXkhBvFoPwmQUSa92pxnxjQuPU")

      cid_v0 = %AetherATProtoCore.CID{version: 0, hash: "test"}
      refute AetherATProtoCore.CID.is_cidv1?(cid_v0)
    end

    test "returns false for invalid inputs" do
      refute AetherATProtoCore.CID.is_cidv1?("invalid")
      refute AetherATProtoCore.CID.is_cidv1?(nil)
    end
  end

  describe "new/3" do
    test "creates CIDv0 struct" do
      hash = "QmY7Yh4UquoXHLPFo2XbhXkhBvFoPwmQUSa92pxnxjQuPU"
      cid = AetherATProtoCore.CID.new(0, "dag-pb", hash)

      assert %AetherATProtoCore.CID{
               version: 0,
               codec: "dag-pb",
               hash: ^hash,
               multibase: "base58btc"
             } = cid
    end

    test "creates CIDv1 struct with base32 hash" do
      hash = "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"
      cid = AetherATProtoCore.CID.new(1, "dag-cbor", hash)

      assert %AetherATProtoCore.CID{
               version: 1,
               codec: "dag-cbor",
               hash: ^hash,
               multibase: "base32"
             } = cid
    end

    test "creates CIDv1 struct with base58 hash" do
      hash = "zdj7WkLmG2I5E5NTd2y1Hy2fx2c3nK1cC1NvJZ7kY7fYx1cYq"
      cid = AetherATProtoCore.CID.new(1, "dag-cbor", hash)

      assert %AetherATProtoCore.CID{
               version: 1,
               codec: "dag-cbor",
               hash: ^hash,
               multibase: "base58btc"
             } = cid
    end
  end

  describe "convert_version/2" do
    test "returns same CID when versions match" do
      cid_v0 = %AetherATProtoCore.CID{version: 0, hash: "test"}
      assert ^cid_v0 = AetherATProtoCore.CID.convert_version(cid_v0, 0)

      cid_v1 = %AetherATProtoCore.CID{version: 1, hash: "test"}
      assert ^cid_v1 = AetherATProtoCore.CID.convert_version(cid_v1, 1)
    end

    test "changes version when different" do
      cid_v0 = %AetherATProtoCore.CID{version: 0, hash: "test", codec: "dag-pb"}
      cid_v1 = AetherATProtoCore.CID.convert_version(cid_v0, 1)

      assert %AetherATProtoCore.CID{version: 1, hash: "test", codec: "dag-pb"} = cid_v1

      cid_v0_converted = AetherATProtoCore.CID.convert_version(cid_v1, 0)
      assert %AetherATProtoCore.CID{version: 0, hash: "test", codec: "dag-pb"} = cid_v0_converted
    end
  end

  # Integration test: real-world ATProto CIDs
  describe "real ATProto CIDs" do
    test "handles typical ATProto record CIDs" do
      # These are examples of CIDs you might encounter in ATProto
      atproto_cids = [
        "bafyreidfayvfuwqa7qlnopdjiqrxzs6blmoeu4rujcjtnci5beludwkzcm",
        "bafyreifcpc5a2q7azfbn2iaveh2dycz37d6i7bnpdn5q4n3aowjwmzwjcy",
        "Qma6e8dovfLyiG2UUfdkSHNPAySzrWLXzq7uMTcPSR5Zaa"
      ]

      for cid <- atproto_cids do
        assert AetherATProtoCore.CID.valid_cid?(cid)

        {:ok, parsed} = AetherATProtoCore.CID.parse_cid(cid)
        assert parsed.version in [0, 1]
        assert is_binary(parsed.hash)
        assert AetherATProtoCore.CID.cid_to_string(parsed) == cid
      end
    end
  end
end
