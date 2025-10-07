defmodule Aether.ATProto.BlobTest do
  use ExUnit.Case, async: true
  doctest Aether.ATProto.Blob

  alias Aether.ATProto.Blob
  alias Aether.ATProto.CID

  setup do
    {:ok, cid} = CID.parse_cid("bafkreie5cvv4h45feadgeuwhbcutmh6t2ceseocckahdoe6uat64zmz454")
    %{cid: cid}
  end

  describe "new/3" do
    test "creates a blob with all fields", %{cid: cid} do
      blob = Blob.new(cid, "image/jpeg", 1024)

      assert blob.ref == cid
      assert blob.mime_type == "image/jpeg"
      assert blob.size == 1024
    end

    test "creates blob with different MIME types", %{cid: cid} do
      blob = Blob.new(cid, "video/mp4", 5_000_000)

      assert blob.mime_type == "video/mp4"
      assert blob.size == 5_000_000
    end
  end

  describe "calculate_cid/1" do
    test "calculates CID from binary data" do
      # Use reasonable size data
      data = :crypto.strong_rand_bytes(100)
      {:ok, cid} = Blob.calculate_cid(data)

      assert %CID{} = cid
    end

    test "same data produces same CID" do
      data = :crypto.strong_rand_bytes(1000)
      {:ok, cid1} = Blob.calculate_cid(data)
      {:ok, cid2} = Blob.calculate_cid(data)

      assert CID.cid_to_string(cid1) == CID.cid_to_string(cid2)
    end

    test "handles large binary data" do
      data = :crypto.strong_rand_bytes(10_000)
      {:ok, cid} = Blob.calculate_cid(data)

      assert %CID{} = cid
    end
  end

  describe "validate/2" do
    test "validates blob with all required fields", %{cid: cid} do
      blob = Blob.new(cid, "image/jpeg", 1024)

      assert :ok = Blob.validate(blob)
    end

    test "validates blob within size limit", %{cid: cid} do
      blob = Blob.new(cid, "image/png", 50 * 1024 * 1024)

      assert :ok = Blob.validate(blob)
    end

    test "rejects blob exceeding default size limit", %{cid: cid} do
      blob = Blob.new(cid, "video/mp4", 51 * 1024 * 1024)

      assert {:error, {:size_exceeded, _}} = Blob.validate(blob)
    end

    test "accepts blob within custom size limit", %{cid: cid} do
      blob = Blob.new(cid, "video/mp4", 100 * 1024 * 1024)

      assert :ok = Blob.validate(blob, max_size: 200 * 1024 * 1024)
    end

    test "rejects blob exceeding custom size limit", %{cid: cid} do
      blob = Blob.new(cid, "video/mp4", 100 * 1024 * 1024)

      assert {:error, {:size_exceeded, _}} = Blob.validate(blob, max_size: 50 * 1024 * 1024)
    end

    test "rejects blob with invalid ref" do
      blob = %Blob{ref: nil, mime_type: "image/jpeg", size: 1024}

      assert {:error, :invalid_ref} = Blob.validate(blob)
    end

    test "rejects blob with invalid mime_type" do
      {:ok, cid} = CID.parse_cid("bafkreie5cvv4h45feadgeuwhbcutmh6t2ceseocckahdoe6uat64zmz454")
      blob = %Blob{ref: cid, mime_type: "", size: 1024}

      assert {:error, :invalid_mime_type} = Blob.validate(blob)
    end

    test "rejects blob with nil mime_type" do
      {:ok, cid} = CID.parse_cid("bafkreie5cvv4h45feadgeuwhbcutmh6t2ceseocckahdoe6uat64zmz454")
      blob = %Blob{ref: cid, mime_type: nil, size: 1024}

      assert {:error, :invalid_mime_type} = Blob.validate(blob)
    end

    test "rejects blob with zero size", %{cid: cid} do
      blob = %Blob{ref: cid, mime_type: "image/jpeg", size: 0}

      assert {:error, :invalid_size} = Blob.validate(blob)
    end

    test "rejects blob with negative size", %{cid: cid} do
      blob = %Blob{ref: cid, mime_type: "image/jpeg", size: -1}

      assert {:error, :invalid_size} = Blob.validate(blob)
    end
  end

  describe "allowed_mime_type?/2" do
    test "allows any MIME type by default" do
      assert Blob.allowed_mime_type?("image/jpeg")
      assert Blob.allowed_mime_type?("video/mp4")
      assert Blob.allowed_mime_type?("application/octet-stream")
      assert Blob.allowed_mime_type?("text/plain")
    end

    test "restricts to allowed list when provided" do
      allowed = ["image/jpeg", "image/png", "image/gif"]

      assert Blob.allowed_mime_type?("image/jpeg", allowed_types: allowed)
      assert Blob.allowed_mime_type?("image/png", allowed_types: allowed)
      refute Blob.allowed_mime_type?("video/mp4", allowed_types: allowed)
    end

    test "handles empty allowed list" do
      refute Blob.allowed_mime_type?("image/jpeg", allowed_types: [])
    end
  end

  describe "to_map/1" do
    test "converts blob to map with correct structure", %{cid: cid} do
      blob = Blob.new(cid, "image/jpeg", 1024)
      map = Blob.to_map(blob)

      assert map["$type"] == "blob"
      assert map["ref"]["$link"] == CID.cid_to_string(cid)
      assert map["mimeType"] == "image/jpeg"
      assert map["size"] == 1024
    end

    test "preserves all blob information in map", %{cid: cid} do
      blob = Blob.new(cid, "video/mp4", 5_000_000)
      map = Blob.to_map(blob)

      assert is_map(map)
      assert Map.has_key?(map, "$type")
      assert Map.has_key?(map, "ref")
      assert Map.has_key?(map, "mimeType")
      assert Map.has_key?(map, "size")
    end
  end

  describe "from_map/1" do
    test "parses blob from map", %{cid: cid} do
      map = %{
        "$type" => "blob",
        "ref" => %{"$link" => CID.cid_to_string(cid)},
        "mimeType" => "image/jpeg",
        "size" => 1024
      }

      {:ok, blob} = Blob.from_map(map)

      assert blob.mime_type == "image/jpeg"
      assert blob.size == 1024
      assert CID.cid_to_string(blob.ref) == CID.cid_to_string(cid)
    end

    test "parses blob with different MIME type", %{cid: cid} do
      map = %{
        "$type" => "blob",
        "ref" => %{"$link" => CID.cid_to_string(cid)},
        "mimeType" => "video/mp4",
        "size" => 10_000
      }

      {:ok, blob} = Blob.from_map(map)

      assert blob.mime_type == "video/mp4"
      assert blob.size == 10_000
    end

    test "handles legacy format with cid field", %{cid: cid} do
      map = %{
        "$type" => "blob",
        "cid" => CID.cid_to_string(cid),
        "mimeType" => "image/png",
        "size" => 2048
      }

      {:ok, blob} = Blob.from_map(map)

      assert blob.mime_type == "image/png"
      assert blob.size == 2048
    end

    test "defaults to application/octet-stream when mimeType missing", %{cid: cid} do
      map = %{
        "$type" => "blob",
        "ref" => %{"$link" => CID.cid_to_string(cid)},
        "size" => 1024
      }

      {:ok, blob} = Blob.from_map(map)

      assert blob.mime_type == "application/octet-stream"
    end

    test "returns error for missing ref" do
      map = %{
        "$type" => "blob",
        "mimeType" => "image/jpeg",
        "size" => 1024
      }

      assert {:error, :missing_ref} = Blob.from_map(map)
    end

    test "returns error for missing size", %{cid: cid} do
      map = %{
        "$type" => "blob",
        "ref" => %{"$link" => CID.cid_to_string(cid)},
        "mimeType" => "image/jpeg"
      }

      assert {:error, :missing_size} = Blob.from_map(map)
    end

    test "returns error for invalid $type" do
      map = %{
        "$type" => "not_a_blob",
        "ref" => %{"$link" => "some_cid"},
        "size" => 1024
      }

      assert {:error, :invalid_blob} = Blob.from_map(map)
    end

    test "returns error for missing $type" do
      map = %{
        "ref" => %{"$link" => "some_cid"},
        "size" => 1024
      }

      assert {:error, :invalid_blob} = Blob.from_map(map)
    end

    test "returns error for invalid CID string" do
      map = %{
        "$type" => "blob",
        "ref" => %{"$link" => "invalid_cid"},
        "mimeType" => "image/jpeg",
        "size" => 1024
      }

      assert {:error, _} = Blob.from_map(map)
    end
  end

  describe "round-trip conversion" do
    test "blob survives to_map and from_map", %{cid: cid} do
      original = Blob.new(cid, "image/jpeg", 1024)

      map = Blob.to_map(original)
      {:ok, restored} = Blob.from_map(map)

      assert restored.mime_type == original.mime_type
      assert restored.size == original.size
      assert CID.cid_to_string(restored.ref) == CID.cid_to_string(original.ref)
    end

    test "preserves all blob types", %{cid: cid} do
      mime_types = [
        "image/jpeg",
        "image/png",
        "image/gif",
        "video/mp4",
        "audio/mpeg",
        "application/pdf"
      ]

      for mime_type <- mime_types do
        original = Blob.new(cid, mime_type, 1024)
        map = Blob.to_map(original)
        {:ok, restored} = Blob.from_map(map)

        assert restored.mime_type == mime_type
      end
    end
  end

  describe "default_mime_type/0 and max_blob_size/0" do
    test "returns default MIME type" do
      assert Blob.default_mime_type() == "application/octet-stream"
    end

    test "returns max blob size" do
      assert Blob.max_blob_size() == 50 * 1024 * 1024
    end
  end

  describe "integration scenarios" do
    test "upload and reference pattern" do
      # Simulate creating a blob reference (without actual storage)
      image_data = :crypto.strong_rand_bytes(1024)
      {:ok, cid} = Blob.calculate_cid(image_data)

      # Create blob reference
      blob = Blob.new(cid, "image/jpeg", byte_size(image_data))

      # Validate before storing
      assert :ok = Blob.validate(blob)

      # Convert to map for JSON encoding
      map = Blob.to_map(blob)

      # Verify map structure
      assert map["$type"] == "blob"
      assert map["size"] == 1024
    end

    test "handles various image sizes" do
      sizes = [1024, 10_240, 102_400, 1_024_000, 10_240_000]

      for size <- sizes do
        data = :crypto.strong_rand_bytes(size)
        {:ok, cid} = Blob.calculate_cid(data)
        blob = Blob.new(cid, "image/png", size)

        assert :ok = Blob.validate(blob)
      end
    end

    test "enforces size limits for different blob types" do
      {:ok, cid} = CID.parse_cid("bafkreie5cvv4h45feadgeuwhbcutmh6t2ceseocckahdoe6uat64zmz454")

      # Small image - should pass
      image = Blob.new(cid, "image/jpeg", 1024)
      assert :ok = Blob.validate(image)

      # Large video - should fail with default limit
      video = Blob.new(cid, "video/mp4", 100 * 1024 * 1024)
      assert {:error, {:size_exceeded, _}} = Blob.validate(video)

      # Large video - should pass with custom limit
      assert :ok = Blob.validate(video, max_size: 200 * 1024 * 1024)
    end
  end
end
