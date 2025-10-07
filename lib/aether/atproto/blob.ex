defmodule Aether.ATProto.Blob do
  @moduledoc """
  Blob (binary large object) data structure for ATProto.

  Blobs represent files like images, videos, and other binary content.
  They are referenced in records and stored by the PDS.

  This module contains pure data operations used by both clients and servers.
  For storage operations, see `Aether.Blob.Storage`.
  """

  alias Aether.ATProto.CID

  defstruct [:ref, :mime_type, :size]

  @type t :: %__MODULE__{
          ref: CID.t(),
          mime_type: String.t(),
          size: pos_integer()
        }

  @default_mime_type "application/octet-stream"
  @max_blob_size 50 * 1024 * 1024

  @doc """
  Create a new blob reference.
  """
  @spec new(CID.t(), String.t(), pos_integer()) :: t()
  def new(cid, mime_type, size) do
    %__MODULE__{
      ref: cid,
      mime_type: mime_type,
      size: size
    }
  end

  @doc """
  Calculate CID from blob data.

  Uses SHA-256 hash with raw multicodec as required by ATProto.
  Creates a CIDv1 with base32 encoding (base32lower without padding).
  """
  @spec calculate_cid(binary()) :: {:ok, CID.t()} | {:error, term()}
  def calculate_cid(data) when is_binary(data) do
    # Calculate SHA-256 hash
    hash = :crypto.hash(:sha256, data)
    hash_size = byte_size(hash)

    # For AT Protocol, we need to create a CID with:
    # - CIDv1 (version 1)
    # - raw codec (0x55)
    # - SHA-256 multihash

    # Create multihash: sha2-256 (0x12) + hash length + hash bytes
    multihash = <<0x12, hash_size>> <> hash

    # Create CIDv1 with raw codec (0x55)
    # CIDv1 format: 0x01 (version) + 0x55 (codec) + multihash
    cid_bytes = <<0x01, 0x55>> <> multihash

    # Convert to base32 string (lowercase, no padding - multibase standard)
    base32_encoded = Base.encode32(cid_bytes, case: :lower, padding: false)

    # Add 'b' prefix for base32 multibase encoding
    cid_string = "b" <> base32_encoded

    CID.parse_cid(cid_string)
  end

  @doc """
  Validate a blob reference.

  Checks that all required fields are present and valid.
  """
  @spec validate(t(), keyword()) :: :ok | {:error, term()}
  def validate(%__MODULE__{} = blob, opts \\ []) do
    max_size = Keyword.get(opts, :max_size, @max_blob_size)

    with :ok <- validate_ref(blob.ref),
         :ok <- validate_mime_type(blob.mime_type),
         :ok <- validate_size(blob.size, max_size) do
      :ok
    end
  end

  @doc """
  Check if a MIME type is allowed.
  """
  @spec allowed_mime_type?(String.t(), keyword()) :: boolean()
  def allowed_mime_type?(mime_type, opts \\ []) do
    allowed_types = Keyword.get(opts, :allowed_types, :all)

    case allowed_types do
      :all -> true
      list when is_list(list) -> mime_type in list
      _ -> false
    end
  end

  @doc """
  Convert blob to map representation for JSON encoding.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = blob) do
    %{
      "$type" => "blob",
      "ref" => %{"$link" => CID.cid_to_string(blob.ref)},
      "mimeType" => blob.mime_type,
      "size" => blob.size
    }
  end

  @doc """
  Parse a blob from map representation.
  """
  @spec from_map(map()) :: {:ok, t()} | {:error, term()}
  def from_map(%{"$type" => "blob"} = map) do
    with {:ok, cid} <- parse_ref(map),
         {:ok, mime_type} <- get_mime_type(map),
         {:ok, size} <- get_size(map) do
      {:ok, new(cid, mime_type, size)}
    end
  end

  def from_map(_), do: {:error, :invalid_blob}

  @doc """
  Get the default MIME type for blobs.
  """
  @spec default_mime_type() :: String.t()
  def default_mime_type, do: @default_mime_type

  @doc """
  Get the default maximum blob size.
  """
  @spec max_blob_size() :: pos_integer()
  def max_blob_size, do: @max_blob_size

  # Private functions

  defp validate_ref(%CID{}), do: :ok
  defp validate_ref(_), do: {:error, :invalid_ref}

  defp validate_mime_type(mime_type) when is_binary(mime_type) and byte_size(mime_type) > 0 do
    :ok
  end

  defp validate_mime_type(_), do: {:error, :invalid_mime_type}

  defp validate_size(size, max_size) when is_integer(size) and size > 0 and size <= max_size do
    :ok
  end

  defp validate_size(size, max_size) when is_integer(size) and size > max_size do
    {:error, {:size_exceeded, max_size}}
  end

  defp validate_size(_size, _max_size), do: {:error, :invalid_size}

  defp parse_ref(%{"ref" => %{"$link" => cid_str}}) do
    CID.parse_cid(cid_str)
  end

  defp parse_ref(%{"cid" => cid_str}) when is_binary(cid_str) do
    CID.parse_cid(cid_str)
  end

  defp parse_ref(_), do: {:error, :missing_ref}

  defp get_mime_type(%{"mimeType" => mime_type}) when is_binary(mime_type) do
    {:ok, mime_type}
  end

  defp get_mime_type(_), do: {:ok, @default_mime_type}

  defp get_size(%{"size" => size}) when is_integer(size) and size > 0 do
    {:ok, size}
  end

  defp get_size(_), do: {:error, :missing_size}
end
