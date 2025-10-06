defmodule AetherATProtoCore.TID do
  @moduledoc """
  Timestamp Identifier (TID) generation and validation for ATProto.

  TIDs are sortable, unique identifiers used for record keys and revisions.
  They encode a microsecond timestamp and a random clock identifier.

  ## Format

  - 13 characters long
  - Base32-sortable encoding: `234567abcdefghijklmnopqrstuvwxyz`
  - First character must be in: `234567abcdefghij`
  - Encodes: 53 bits timestamp + 10 bits clock ID

  ## Usage

  ```elixir
  # Generate a new TID
  tid = AetherATProtoCore.TID.new()
  #=> "3jzfcijpj2z2a"

  # Validate a TID
  AetherATProtoCore.TID.valid_tid?("3jzfcijpj2z2a")
  #=> true

  # Parse a TID to get timestamp
  {:ok, timestamp} = AetherATProtoCore.TID.parse_timestamp("3jzfcijpj2z2a")
  ```

  ## Ordering

  TIDs are lexicographically sortable - comparing them as strings
  gives correct chronological ordering.
  """

  @base32_chars ~c"234567abcdefghijklmnopqrstuvwxyz"
  @valid_first_chars ~c"234567abcdefghij"

  @doc """
  Generate a new TID with the current timestamp.

  ## Examples

      iex> tid = AetherATProtoCore.TID.new()
      iex> String.length(tid)
      13
      iex> AetherATProtoCore.TID.valid_tid?(tid)
      true
  """
  @spec new() :: String.t()
  def new do
    timestamp_us = System.os_time(:microsecond)
    clock_id = :rand.uniform(1024) - 1

    encode(timestamp_us, clock_id)
  end

  @doc """
  Generate a TID from a specific timestamp in microseconds.

  ## Examples

      iex> tid = AetherATProtoCore.TID.from_timestamp(1_700_000_000_000_000)
      iex> String.length(tid)
      13
  """
  @spec from_timestamp(integer(), non_neg_integer()) :: String.t()
  def from_timestamp(timestamp_us, clock_id \\ nil) when is_integer(timestamp_us) do
    clock_id = clock_id || :rand.uniform(1024) - 1
    encode(timestamp_us, clock_id)
  end

  @doc """
  Validate a TID string.

  ## Examples

      iex> AetherATProtoCore.TID.valid_tid?("3jzfcijpj2z2a")
      true

      iex> AetherATProtoCore.TID.valid_tid?("invalid")
      false

      iex> AetherATProtoCore.TID.valid_tid?("1234567890123")
      false
  """
  @spec valid_tid?(String.t()) :: boolean()
  def valid_tid?(tid) when is_binary(tid) do
    case String.length(tid) do
      13 ->
        chars = String.to_charlist(tid)
        valid_first?(hd(chars)) and Enum.all?(chars, &valid_char?/1)

      _ ->
        false
    end
  end

  def valid_tid?(_), do: false

  @doc """
  Parse a TID to extract the timestamp in microseconds.

  ## Examples

      iex> tid = AetherATProtoCore.TID.new()
      iex> {:ok, timestamp} = AetherATProtoCore.TID.parse_timestamp(tid)
      iex> is_integer(timestamp)
      true
  """
  @spec parse_timestamp(String.t()) :: {:ok, integer()} | {:error, :invalid_tid}
  def parse_timestamp(tid) when is_binary(tid) do
    if valid_tid?(tid) do
      timestamp = decode_timestamp(tid)
      {:ok, timestamp}
    else
      {:error, :invalid_tid}
    end
  end

  @doc """
  Compare two TIDs chronologically.

  Returns `:gt` if tid1 is newer, `:lt` if older, `:eq` if equal.

  ## Examples

      iex> tid1 = AetherATProtoCore.TID.from_timestamp(1_700_000_000_000_000)
      iex> tid2 = AetherATProtoCore.TID.from_timestamp(1_700_000_000_000_001)
      iex> AetherATProtoCore.TID.compare(tid1, tid2)
      :lt
  """
  @spec compare(String.t(), String.t()) :: :gt | :lt | :eq
  def compare(tid1, tid2) when is_binary(tid1) and is_binary(tid2) do
    # TIDs are lexicographically sortable
    cond do
      tid1 > tid2 -> :gt
      tid1 < tid2 -> :lt
      true -> :eq
    end
  end

  # Private functions

  defp encode(timestamp_us, clock_id) do
    # Combine timestamp (53 bits) and clock_id (10 bits) into 64-bit integer
    # Top bit is always 0
    value = Bitwise.bsl(timestamp_us, 10) + clock_id

    # Encode to base32 (big-endian, most significant first)
    encode_base32(value, 13, [])
  end

  defp encode_base32(_value, 0, acc), do: List.to_string(acc)

  defp encode_base32(value, remaining, acc) do
    # Extract from most significant bits first
    shift_amount = (remaining - 1) * 5
    char_index = Bitwise.band(Bitwise.bsr(value, shift_amount), 0x1F)
    char = Enum.at(@base32_chars, char_index)
    encode_base32(value, remaining - 1, acc ++ [char])
  end

  defp decode_timestamp(tid) do
    chars = String.to_charlist(tid)

    value =
      Enum.reduce(chars, 0, fn char, acc ->
        index = Enum.find_index(@base32_chars, &(&1 == char))
        Bitwise.bsl(acc, 5) + index
      end)

    # Extract timestamp (top 53 bits)
    Bitwise.bsr(value, 10)
  end

  defp valid_first?(char), do: char in @valid_first_chars
  defp valid_char?(char), do: char in @base32_chars
end
