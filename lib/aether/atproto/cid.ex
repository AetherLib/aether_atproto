defmodule Aether.ATProto.CID do
  @moduledoc """
  Content Identifier (CID) handling for ATProto.

  Supports CIDv0 and CIDv1 formats commonly used in IPFS and ATProto networks.
  """

  defstruct [:version, :codec, :hash, :multibase, :multihash]

  @type t :: %__MODULE__{
          version: 0 | 1,
          codec: String.t() | nil,
          hash: String.t(),
          multibase: String.t() | nil,
          multihash: binary() | nil
        }

  defmodule ParseError do
    defexception message: "Invalid CID format"
  end

  @cid_v0_length 46
  @cid_v0_prefix "Qm"
  @cid_v1_base32_prefix "b"
  @cid_v1_base58_prefix "z"

  @doc """
  Parse a CID string into structured data.

  ## Examples

      iex> Aether.ATProto.CID.parse_cid("QmY7Yh4UquoXHLPFo2XbhXkhBvFoPwmQUSa92pxnxjQuPU")
      {:ok, %Aether.ATProto.CID{version: 0, codec: "dag-pb", hash: "QmY7Yh4UquoXHLPFo2XbhXkhBvFoPwmQUSa92pxnxjQuPU", multibase: "base58btc"}}

      iex> Aether.ATProto.CID.parse_cid("bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi")
      {:ok, %Aether.ATProto.CID{version: 1, codec: "dag-cbor", hash: "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi", multibase: "base32"}}
  """
  def parse_cid(cid_string) when is_binary(cid_string) do
    cond do
      # CIDv0 - Base58BTC SHA-256, always 46 characters starting with Qm
      String.starts_with?(cid_string, @cid_v0_prefix) and byte_size(cid_string) == @cid_v0_length ->
        {:ok,
         %__MODULE__{
           version: 0,
           codec: "dag-pb",
           hash: cid_string,
           multibase: "base58btc"
         }}

      # CIDv1 - Base32 encoded (must have proper base32 characters after 'b')
      String.starts_with?(cid_string, @cid_v1_base32_prefix) and valid_base32_cid?(cid_string) ->
        {:ok,
         %__MODULE__{
           version: 1,
           codec: "dag-cbor",
           hash: cid_string,
           multibase: "base32"
         }}

      # CIDv1 - Base58BTC encoded (must have proper base58 characters after 'z')
      String.starts_with?(cid_string, @cid_v1_base58_prefix) and valid_base58_cid?(cid_string) ->
        {:ok,
         %__MODULE__{
           version: 1,
           codec: "dag-cbor",
           hash: cid_string,
           multibase: "base58btc"
         }}

      true ->
        {:error, :invalid_format}
    end
  end

  # Helper function to validate CIDv1 base32 format
  defp valid_base32_cid?(cid_string) do
    # Must be longer than just the prefix
    # Rest of string should be valid base32 characters (a-z2-7)
    byte_size(cid_string) > 1 and
      String.match?(String.slice(cid_string, 1..-1//1), ~r/^[a-z2-7]+$/)
  end

  # Helper function to validate CIDv1 base58 format
  defp valid_base58_cid?(cid_string) do
    # Must be longer than just the prefix
    # Get substring starting after the prefix
    byte_size(cid_string) > 1 and
      String.slice(cid_string, 1..-1//1)
      # Use a more permissive base58 regex that allows all common base58 characters
      |> String.match?(~r/^[1-9A-Za-z]*$/)
  end

  def parse_cid!(cid_string) when is_binary(cid_string) do
    case parse_cid(cid_string) do
      {:ok, cid} -> cid
      {:error, _} -> raise ParseError, "Failed to parse CID: #{cid_string}"
    end
  end

  def parse_cid!(%__MODULE__{} = cid), do: cid
  def parse_cid!(_other), do: raise(ParseError)

  @doc """
  Check if a value is a valid CID.

  ## Examples

      iex> Aether.ATProto.CID.valid_cid?("QmY7Yh4UquoXHLPFo2XbhXkhBvFoPwmQUSa92pxnxjQuPU")
      true

      iex> Aether.ATProto.CID.valid_cid?("invalid")
      false

      iex> Aether.ATProto.CID.valid_cid?(%Aether.ATProto.CID{version: 1, hash: "bafy..."})
      true
  """
  def valid_cid?(cid) when is_binary(cid) do
    match?({:ok, _}, parse_cid(cid))
  end

  def valid_cid?(%__MODULE__{}), do: true
  def valid_cid?(_), do: false

  @doc """
  Convert a CID struct back to its string representation.

  ## Examples

      iex> cid = %Aether.ATProto.CID{hash: "QmY7Yh4UquoXHLPFo2XbhXkhBvFoPwmQUSa92pxnxjQuPU"}
      iex> Aether.ATProto.CID.cid_to_string(cid)
      "QmY7Yh4UquoXHLPFo2XbhXkhBvFoPwmQUSa92pxnxjQuPU"
  """
  def cid_to_string(%__MODULE__{hash: hash}), do: hash
  def cid_to_string(cid_string) when is_binary(cid_string), do: cid_string

  @doc """
  Encode a CID to its string representation. Alias for cid_to_string/1.
  """
  def encode(%__MODULE__{hash: hash} = cid) when is_binary(hash) do
    # If hash is already a string (like "bafyreie..."), use it
    # If hash is binary bytes, encode to base32
    if String.printable?(hash) do
      cid_to_string(cid)
    else
      # Convert binary hash to base32 string for CIDv1
      encoded_hash = Base.encode32(hash, case: :lower, padding: false)
      "b" <> encoded_hash
    end
  end

  def encode(cid_string) when is_binary(cid_string), do: cid_string

  @doc """
  Decode a CID string. Alias for parse_cid/1.
  """
  def decode(cid_string) when is_binary(cid_string), do: parse_cid(cid_string)

  @doc """
  Extract the version from a CID.

  ## Examples

      iex> Aether.ATProto.CID.cid_version("QmY7Yh4UquoXHLPFo2XbhXkhBvFoPwmQUSa92pxnxjQuPU")
      0

      iex> Aether.ATProto.CID.cid_version("bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi")
      1

      iex> Aether.ATProto.CID.cid_version("invalid")
      {:error, :invalid_cid}
  """
  def cid_version(cid_string) when is_binary(cid_string) do
    case parse_cid(cid_string) do
      {:ok, %__MODULE__{version: version}} -> version
      {:error, _} -> {:error, :invalid_cid}
    end
  end

  def cid_version(%__MODULE__{version: version}), do: version

  @doc """
  Get the codec used by the CID.

  ## Examples

      iex> Aether.ATProto.CID.cid_codec("QmY7Yh4UquoXHLPFo2XbhXkhBvFoPwmQUSa92pxnxjQuPU")
      "dag-pb"

      iex> Aether.ATProto.CID.cid_codec("bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi")
      "dag-cbor"
  """
  def cid_codec(cid) when is_binary(cid) do
    case parse_cid(cid) do
      {:ok, %__MODULE__{codec: codec}} -> codec
      {:error, _} -> {:error, :invalid_cid}
    end
  end

  def cid_codec(%__MODULE__{codec: codec}), do: codec

  @doc """
  Check if a CID is in CIDv0 format.

  ## Examples

      iex> Aether.ATProto.CID.is_cidv0?("QmY7Yh4UquoXHLPFo2XbhXkhBvFoPwmQUSa92pxnxjQuPU")
      true

      iex> Aether.ATProto.CID.is_cidv0?("bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi")
      false
  """
  def is_cidv0?(cid) when is_binary(cid) do
    case cid_version(cid) do
      0 -> true
      _ -> false
    end
  end

  def is_cidv0?(%__MODULE__{version: 0}), do: true
  def is_cidv0?(_), do: false

  @doc """
  Check if a CID is in CIDv1 format.

  ## Examples

      iex> Aether.ATProto.CID.is_cidv1?("bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi")
      true

      iex> Aether.ATProto.CID.is_cidv1?("QmY7Yh4UquoXHLPFo2XbhXkhBvFoPwmQUSa92pxnxjQuPU")
      false
  """
  def is_cidv1?(cid) when is_binary(cid) do
    case cid_version(cid) do
      1 -> true
      _ -> false
    end
  end

  def is_cidv1?(%__MODULE__{version: 1}), do: true
  def is_cidv1?(_), do: false

  @doc """
  Create a new CID struct with the given properties.

  ## Examples

      iex> Aether.ATProto.CID.new(1, "dag-cbor", "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi")
      %Aether.ATProto.CID{
        version: 1,
        codec: "dag-cbor",
        hash: "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi",
        multibase: "base32"
      }
  """
  def new(version, codec, hash) when version in [0, 1] and is_binary(hash) do
    multibase = if version == 0, do: "base58btc", else: detect_multibase(hash)

    %__MODULE__{
      version: version,
      codec: codec,
      hash: hash,
      multibase: multibase
    }
  end

  defp detect_multibase(hash) do
    cond do
      String.starts_with?(hash, @cid_v1_base32_prefix) -> "base32"
      String.starts_with?(hash, @cid_v1_base58_prefix) -> "base58btc"
      true -> nil
    end
  end

  @doc """
  Convert between CID versions (placeholder - in real implementation would require multihash decoding).

  Note: This is a simplified version that just changes the struct representation.
  """
  def convert_version(%__MODULE__{version: current_version} = cid, target_version)
      when current_version in [0, 1] and target_version in [0, 1] do
    if current_version == target_version do
      cid
    else
      %__MODULE__{cid | version: target_version}
    end
  end

  @doc """
  Convert a CID to its binary representation.

  ## Examples

      iex> {:ok, cid} = Aether.ATProto.CID.parse_cid("bafyreie5cvv4h45feadgeuwhbcutmh6t2ceseocckahdoe6uat64zmz454")
      iex> bytes = Aether.ATProto.CID.cid_to_bytes(cid)
      iex> is_binary(bytes)
      true
  """
  @spec cid_to_bytes(t()) :: binary()
  def cid_to_bytes(%__MODULE__{hash: hash}) do
    # Simplified: just use the hash string as bytes
    # In production, this would properly encode the CID
    hash
  end

  @doc """
  Parse a CID from binary data.

  Returns `{:ok, cid, rest}` where rest is the remaining binary data.

  ## Examples

      iex> {:ok, cid} = Aether.ATProto.CID.parse_cid("bafyreie5cvv4h45feadgeuwhbcutmh6t2ceseocckahdoe6uat64zmz454")
      iex> bytes = Aether.ATProto.CID.cid_to_bytes(cid)
      iex> {:ok, parsed, <<>>} = Aether.ATProto.CID.parse_cid_bytes(bytes)
      iex> parsed.hash == cid.hash
      true
  """
  @spec parse_cid_bytes(binary()) :: {:ok, t(), binary()} | {:error, term()}
  def parse_cid_bytes(binary) when is_binary(binary) do
    # Simplified CID parsing from bytes
    # Try to parse as a CID string first
    # In production, this would parse the binary CID format
    case parse_cid(binary) do
      {:ok, cid} -> {:ok, cid, <<>>}
      {:error, _} -> {:error, :invalid_cid}
    end
  end

  @doc """
  Generate a CIDv1 from binary data using SHA-256 hash.

  ## Examples

      iex> data = "hello world"
      iex> Aether.ATProto.CID.from_data(data)
      "bafyreifzjut3te2nhyekklss27nh3k72ysco7y32koao5eei66wof36n5e"
  """
  def from_data(data, codec \\ "dag-cbor") when is_binary(data) do
    # Hash the data
    hash = :crypto.hash(:sha256, data)

    # For CIDv1 with dag-cbor codec, the multicodec prefix is 0x71
    # and SHA-256 multihash code is 0x12
    # Multihash format: <hash_function_code><digest_length><digest_bytes>
    multihash = <<0x12, 32>> <> hash

    # CIDv1 format: <version><codec><multihash>
    cid_bytes = <<0x01>> <> codec_to_bytes(codec) <> multihash

    # Base32 encode (lowercase, no padding)
    encoded = Base.encode32(cid_bytes, case: :lower, padding: false)

    # Add base32 multibase prefix
    "b" <> encoded
  end

  defp codec_to_bytes("dag-cbor"), do: <<0x71>>
  defp codec_to_bytes("dag-pb"), do: <<0x70>>
  defp codec_to_bytes("raw"), do: <<0x55>>
  # Default to dag-cbor
  defp codec_to_bytes(_), do: <<0x71>>

  @doc """
  Generate a CIDv1 from a map by encoding it to CBOR first.

  ## Examples

      iex> data = %{"hello" => "world"}
      iex> cid = Aether.ATProto.CID.from_map(data)
      iex> String.starts_with?(cid, "bafyrei")
      true
  """
  def from_map(map) when is_map(map) do
    cbor_data = CBOR.encode(map)
    from_data(cbor_data, "dag-cbor")
  end
end

# CBOR Encoder implementation for CID
# This allows CIDs to be encoded in CBOR format for ATProto
if Code.ensure_loaded?(CBOR.Encoder) do
  defimpl CBOR.Encoder, for: Aether.ATProto.CID do
    def encode_into(cid, acc) do
      # Encode CID as its string representation
      # ATProto expects CIDs to be strings in CBOR
      cid_string = Aether.ATProto.CID.cid_to_string(cid)
      CBOR.Encoder.encode_into(cid_string, acc)
    end
  end
end
