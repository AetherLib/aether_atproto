defmodule Aether.ATProto.Varint do
  @moduledoc """
  Variable-length integer encoding/decoding.

  Varint encoding is used in CAR files to encode block lengths.
  It's a compact encoding where smaller numbers use fewer bytes.

  ## Encoding

  Each byte uses 7 bits for data and 1 bit as a continuation flag.
  If the high bit is set, more bytes follow.

  ## Examples

      iex> Aether.ATProto.Varint.encode(127)
      <<127>>

      iex> Aether.ATProto.Varint.encode(300)
      <<172, 2>>

      iex> {:ok, 127, <<>>} = Aether.ATProto.Varint.decode(<<127>>)
      iex> :ok
      :ok
  """

  @doc """
  Encode an integer as a varint.

  ## Examples

      iex> Aether.ATProto.Varint.encode(0)
      <<0>>

      iex> Aether.ATProto.Varint.encode(1)
      <<1>>

      iex> Aether.ATProto.Varint.encode(127)
      <<127>>

      iex> Aether.ATProto.Varint.encode(128)
      <<128, 1>>
  """
  @spec encode(non_neg_integer()) :: binary()
  def encode(n) when is_integer(n) and n >= 0 do
    do_encode(n, <<>>)
  end

  @doc """
  Decode a varint from binary data.

  Returns `{:ok, value, rest}` where rest is the remaining binary data.

  ## Examples

      iex> Aether.ATProto.Varint.decode(<<127>>)
      {:ok, 127, <<>>}

      iex> Aether.ATProto.Varint.decode(<<128, 1, 99>>)
      {:ok, 128, <<99>>}
  """
  @spec decode(binary()) :: {:ok, non_neg_integer(), binary()} | {:error, :incomplete}
  def decode(binary) when is_binary(binary) do
    do_decode(binary, 0, 0)
  end

  # Private functions

  defp do_encode(n, acc) when n < 128 do
    <<acc::binary, n>>
  end

  defp do_encode(n, acc) do
    # Take the lower 7 bits and set the high bit
    byte = Bitwise.bor(Bitwise.band(n, 0x7F), 0x80)
    # Shift right by 7 bits for the next iteration
    do_encode(Bitwise.bsr(n, 7), <<acc::binary, byte>>)
  end

  defp do_decode(<<byte, rest::binary>>, acc, shift) when byte < 128 do
    # Last byte - high bit not set
    value = Bitwise.bor(acc, Bitwise.bsl(byte, shift))
    {:ok, value, rest}
  end

  defp do_decode(<<byte, rest::binary>>, acc, shift) do
    # More bytes to come - high bit is set
    value_bits = Bitwise.band(byte, 0x7F)
    new_acc = Bitwise.bor(acc, Bitwise.bsl(value_bits, shift))
    do_decode(rest, new_acc, shift + 7)
  end

  defp do_decode(<<>>, _acc, _shift) do
    {:error, :incomplete}
  end
end
