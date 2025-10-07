defmodule Aether.ATProto.CAR do
  @moduledoc """
  CAR (Content Addressable aRchive) file handling for ATProto.

  CAR files are used to package repository data (commits, MST nodes, records)
  into a single file for export, import, and synchronization.

  ## Format

  A CAR file consists of:
  1. Header (CBOR-encoded) with version and root CIDs
  2. Sequence of blocks, each containing:
     - Length (varint)
     - CID
     - Block data

  ## Usage

  ```elixir
  # Write a CAR file
  blocks = [
    %Aether.ATProto.CAR.Block{cid: commit_cid, data: commit_data},
    %Aether.ATProto.CAR.Block{cid: mst_cid, data: mst_data}
  ]

  car = %Aether.ATProto.CAR{
    roots: [commit_cid],
    blocks: blocks
  }

  {:ok, binary} = Aether.ATProto.CAR.encode(car)
  File.write!("repo.car", binary)

  # Read a CAR file
  binary = File.read!("repo.car")
  {:ok, car} = Aether.ATProto.CAR.decode(binary)
  ```

  ## ATProto Repositories

  When exporting a repository:
  - First root CID is the most recent commit
  - Include all blocks for that commit (MST nodes, records)
  - Blocks should be de-duplicated by CID
  """

  alias Aether.ATProto.CAR.Block
  alias Aether.ATProto.CID
  alias Aether.ATProto.Varint

  defstruct version: 1, roots: [], blocks: []

  @type t :: %__MODULE__{
          version: pos_integer(),
          roots: [CID.t()],
          blocks: [Block.t()]
        }

  @doc """
  Encode a CAR structure to binary format.

  ## Examples

      iex> cid = Aether.ATProto.CID.parse_cid!("bafyreie5cvv4h45feadgeuwhbcutmh6t2ceseocckahdoe6uat64zmz454")
      iex> block = %Aether.ATProto.CAR.Block{cid: cid, data: <<1, 2, 3>>}
      iex> car = %Aether.ATProto.CAR{roots: [cid], blocks: [block]}
      iex> {:ok, binary} = Aether.ATProto.CAR.encode(car)
      iex> is_binary(binary)
      true
  """
  @spec encode(t()) :: {:ok, binary()} | {:error, term()}
  def encode(%__MODULE__{} = car) do
    try do
      # Encode header
      header = encode_header(car)
      header_length = Varint.encode(byte_size(header))

      # Encode blocks
      blocks_binary =
        car.blocks
        |> Enum.map(&encode_block/1)
        |> IO.iodata_to_binary()

      # Combine: header_length + header + blocks
      binary = IO.iodata_to_binary([header_length, header, blocks_binary])

      {:ok, binary}
    rescue
      e -> {:error, {:encoding_failed, e}}
    end
  end

  @doc """
  Decode a CAR binary into a CAR structure.

  ## Examples

      iex> cid = Aether.ATProto.CID.parse_cid!("bafyreie5cvv4h45feadgeuwhbcutmh6t2ceseocckahdoe6uat64zmz454")
      iex> block = %Aether.ATProto.CAR.Block{cid: cid, data: <<1, 2, 3>>}
      iex> car = %Aether.ATProto.CAR{roots: [cid], blocks: [block]}
      iex> {:ok, binary} = Aether.ATProto.CAR.encode(car)
      iex> {:ok, decoded} = Aether.ATProto.CAR.decode(binary)
      iex> decoded.version
      1
  """
  @spec decode(binary()) :: {:ok, t()} | {:error, term()}
  def decode(binary) when is_binary(binary) do
    try do
      # Decode header
      with {:ok, header_length, rest} <- Varint.decode(binary),
           {:ok, header, blocks_binary} <- extract_bytes(rest, header_length),
           {:ok, version, roots} <- decode_header(header),
           {:ok, blocks} <- decode_blocks(blocks_binary) do
        {:ok, %__MODULE__{version: version, roots: roots, blocks: blocks}}
      end
    rescue
      e -> {:error, {:decoding_failed, e}}
    end
  end

  @doc """
  Find a block by its CID.

  ## Examples

      iex> cid = Aether.ATProto.CID.parse_cid!("bafyreie5cvv4h45feadgeuwhbcutmh6t2ceseocckahdoe6uat64zmz454")
      iex> block = %Aether.ATProto.CAR.Block{cid: cid, data: <<1, 2, 3>>}
      iex> car = %Aether.ATProto.CAR{blocks: [block]}
      iex> {:ok, found} = Aether.ATProto.CAR.get_block(car, cid)
      iex> found.data
      <<1, 2, 3>>
  """
  @spec get_block(t(), CID.t()) :: {:ok, Block.t()} | {:error, :not_found}
  def get_block(%__MODULE__{blocks: blocks}, cid) do
    cid_string = CID.cid_to_string(cid)

    case Enum.find(blocks, fn block ->
           CID.cid_to_string(block.cid) == cid_string
         end) do
      nil -> {:error, :not_found}
      block -> {:ok, block}
    end
  end

  @doc """
  Get all blocks from the CAR.

  ## Examples

      iex> cid = Aether.ATProto.CID.parse_cid!("bafyreie5cvv4h45feadgeuwhbcutmh6t2ceseocckahdoe6uat64zmz454")
      iex> block = %Aether.ATProto.CAR.Block{cid: cid, data: <<1, 2, 3>>}
      iex> car = %Aether.ATProto.CAR{blocks: [block]}
      iex> blocks = Aether.ATProto.CAR.list_blocks(car)
      iex> length(blocks)
      1
  """
  @spec list_blocks(t()) :: [Block.t()]
  def list_blocks(%__MODULE__{blocks: blocks}), do: blocks

  # Private functions

  defp encode_header(car) do
    # Encode as CBOR map with version and roots
    header_map = %{
      "version" => car.version,
      "roots" => Enum.map(car.roots, &CID.cid_to_string/1)
    }

    CBOR.encode(header_map)
  end

  defp decode_header(header_binary) do
    # Decode CBOR header
    {:ok, header_map, ""} = CBOR.decode(header_binary)

    roots =
      header_map["roots"]
      |> Enum.map(fn cid_str ->
        {:ok, cid} = CID.parse_cid(cid_str)
        cid
      end)

    {:ok, header_map["version"], roots}
  end

  defp encode_block(%Block{cid: cid, data: data}) do
    # Encode CID as string (simplified)
    cid_str = CID.cid_to_string(cid)
    cid_length = Varint.encode(byte_size(cid_str))

    # Block format: length(varint) + cid_length(varint) + cid_str + data
    block_data = IO.iodata_to_binary([cid_length, cid_str, data])
    length_prefix = Varint.encode(byte_size(block_data))

    [length_prefix, block_data]
  end

  defp decode_blocks(binary), do: decode_blocks(binary, [])

  defp decode_blocks(<<>>, acc), do: {:ok, Enum.reverse(acc)}

  defp decode_blocks(binary, acc) do
    with {:ok, block_length, rest} <- Varint.decode(binary),
         {:ok, block_data, remaining} <- extract_bytes(rest, block_length),
         {:ok, block} <- decode_block(block_data) do
      decode_blocks(remaining, [block | acc])
    end
  end

  defp decode_block(block_data) do
    # Extract CID length, then CID, then data
    with {:ok, cid_length, rest} <- Varint.decode(block_data),
         {:ok, cid_str, data} <- extract_bytes(rest, cid_length),
         {:ok, cid} <- CID.parse_cid(cid_str) do
      {:ok, %Block{cid: cid, data: data}}
    end
  end

  defp extract_bytes(binary, length) when byte_size(binary) >= length do
    <<extracted::binary-size(length), rest::binary>> = binary
    {:ok, extracted, rest}
  end

  defp extract_bytes(_binary, _length), do: {:error, :insufficient_data}
end
