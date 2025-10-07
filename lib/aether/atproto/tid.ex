defmodule Aether.ATProto.TID do
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
  tid = Aether.ATProto.TID.new()
  #=> "3jzfcijpj2z2a"

  # Validate a TID
  Aether.ATProto.TID.valid_tid?("3jzfcijpj2z2a")
  #=> true

  # Parse a TID to get timestamp
  {:ok, timestamp} = Aether.ATProto.TID.parse_timestamp("3jzfcijpj2z2a")
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

      iex> tid = Aether.ATProto.TID.new()
      iex> String.length(tid)
      13
      iex> Aether.ATProto.TID.valid_tid?(tid)
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

  This function creates a Time-Ordered ID (TID) using the given timestamp and an optional
  clock identifier. The TID format ensures temporal ordering while providing collision
  resistance through the clock ID.

  ## Parameters
  - `timestamp_us`: Unix timestamp in microseconds (integer)
  - `clock_id`: Optional clock identifier (0-1023). If not provided, a random value in this range is used.

  ## Returns
  - TID string in base32hex format (13 characters)

  ## Examples

      # Generate TID with automatic clock ID (recommended for most use cases)
      iex> tid = Aether.ATProto.TID.from_timestamp(1_700_000_000_000_000)
      iex> String.length(tid)
      13

      # Generate TID with specific clock ID (for deterministic testing)
      iex> Aether.ATProto.TID.from_timestamp(1_700_000_000_000_000, 42)
      "3ke6kg3wk223e"  # This value is deterministic with clock_id=42

      # The function now properly handles the default case without type violations
      iex> is_binary(Aether.ATProto.TID.from_timestamp(1_700_000_000_000_000))
      true
  """
  @spec from_timestamp(integer(), non_neg_integer()) :: String.t()
  def from_timestamp(timestamp_us, clock_id \\ :rand.uniform(1024) - 1)
      when is_integer(timestamp_us) do
    encode(timestamp_us, clock_id)
  end

  @doc """
  Validate a TID string.

  ## Examples

      iex> Aether.ATProto.TID.valid_tid?("3jzfcijpj2z2a")
      true

      iex> Aether.ATProto.TID.valid_tid?("invalid")
      false

      iex> Aether.ATProto.TID.valid_tid?("1234567890123")
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

      iex> tid = Aether.ATProto.TID.new()
      iex> {:ok, timestamp} = Aether.ATProto.TID.parse_timestamp(tid)
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

      iex> tid1 = Aether.ATProto.TID.from_timestamp(1_700_000_000_000_000)
      iex> tid2 = Aether.ATProto.TID.from_timestamp(1_700_000_000_000_001)
      iex> Aether.ATProto.TID.compare(tid1, tid2)
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
