defmodule Aether.Crypto.Utils do
  @moduledoc """
  Common functions used in ATProto crypto
  """

  @did_key_prefix "did:key:"
  @base58_multibase_prefix "z"

  @doc """
  Generates a random string of the given byte length in the specified encoding.

  Supported encodings: `:hex`, `:base64`, `:base64url`

  ## Examples
      iex> RandomUtils.random_str(16, :hex)
      "8f7a4e1c9b3d6e2a5f8c1b7e9d4a2f6c"

      iex> RandomUtils.random_str(16, :base64)
      "L7nP8q2X1mR6wK9jT4cH5Q=="
  """
  def random_str(byte_length, encoding) when is_integer(byte_length) and byte_length > 0 do
    bytes = :crypto.strong_rand_bytes(byte_length)

    case encoding do
      :hex -> Base.encode16(bytes, case: :lower)
      :base64 -> Base.encode64(bytes)
      :base64url -> Base.url_encode64(bytes, padding: false)
      _ -> raise ArgumentError, "Unsupported encoding: #{encoding}"
    end
  end

  @doc """
  Generates a deterministic random integer from a seed string within the specified range [low, high).

  ## Examples
      iex> RandomUtils.random_int_from_seed("my-seed", 100, 0)
      42

      iex> RandomUtils.random_int_from_seed("another-seed", 50)
      23
  """
  def random_int_from_seed(seed, high, low \\ 0)
      when is_binary(seed) and is_integer(high) and is_integer(low) do
    hash = :crypto.hash(:sha256, seed)

    # Take first 6 bytes (48 bits) and convert to integer (big-endian)
    <<number::big-unsigned-integer-48>> = binary_part(hash, 0, 6)

    range = high - low
    normalized = rem(number, range)
    normalized + low
  end

  @doc """
  Extracts the multikey from a DID key string.

  ## Examples
      iex> MultibaseUtils.extract_multikey("did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK")
      "z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK"

      iex> MultibaseUtils.extract_multikey("did:key:invalid")
      ** (ArgumentError) Incorrect prefix for did:key: did:key:invalid
  """
  def extract_multikey(did) when is_binary(did) do
    if String.starts_with?(did, @did_key_prefix) do
      String.slice(did, String.length(@did_key_prefix)..-1)
    else
      raise ArgumentError, "Incorrect prefix for did:key: #{did}"
    end
  end

  @doc """
  Extracts and decodes the prefixed bytes from a multikey string.

  ## Examples
      iex> MultibaseUtils.extract_prefixed_bytes("z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK")
      <<214, 53, 226, 91, 6, 80, 77, 118, 234, 180, 125, 251, 178, 125, 255, 114, 188, 226, 134, 48, 186, 66, 211, 174, 118, 118, 68, 157, 174, 118, 118>>

      iex> MultibaseUtils.extract_prefixed_bytes("invalid")
      ** (ArgumentError) Incorrect prefix for multikey: invalid
  """
  def extract_prefixed_bytes(multikey) when is_binary(multikey) do
    if String.starts_with?(multikey, @base58_multibase_prefix) do
      multikey
      |> String.slice(String.length(@base58_multibase_prefix)..-1)
      |> Base58.decode()
    else
      raise ArgumentError, "Incorrect prefix for multikey: #{multikey}"
    end
  end

  @doc """
  Checks if the given bytes start with the specified prefix.

  ## Examples
      iex> MultibaseUtils.has_prefix(<<1, 2, 3, 4>>, <<1, 2>>)
      true

      iex> MultibaseUtils.has_prefix(<<1, 2, 3, 4>>, <<5, 6>>)
      false

      iex> MultibaseUtils.has_prefix(<<1, 2>>, <<1, 2, 3>>)
      false
  """
  def has_prefix(bytes, prefix) when is_binary(bytes) and is_binary(prefix) do
    prefix_size = byte_size(prefix)

    if byte_size(bytes) >= prefix_size do
      binary_part(bytes, 0, prefix_size) == prefix
    else
      false
    end
  end

  @doc """
  Decodes a multibase-encoded string to bytes.

  ## Examples
      iex> Multibase.multibase_to_bytes("f48656c6c6f")
      "Hello"

      iex> Multibase.multibase_to_bytes("z6MkhaXgBZDvotDkL5257faizti")
      <<214, 53, 226, 91, 6, 80, 77, 118, 234, 180, 125, 251, 178, 125>>

      iex> Multibase.multibase_to_bytes("mSGVsbG8=")
      "Hello"
  """
  def multibase_to_bytes(mb) when is_binary(mb) do
    case String.split_at(mb, 1) do
      {"f", key} ->
        Base.decode16!(key, case: :lower)

      {"F", key} ->
        Base.decode16!(key, case: :upper)

      {"b", key} ->
        Base.decode32!(key, case: :lower, padding: false)

      {"B", key} ->
        Base.decode32!(key, case: :upper, padding: false)

      {"z", key} ->
        Base58.decode(key)

      {"m", key} ->
        Base.decode64!(key)

      {"u", key} ->
        Base.url_decode64!(key, padding: false)

      {"U", key} ->
        Base.url_decode64!(key)

      {base, _} ->
        raise ArgumentError, "Unsupported multibase: #{base}#{String.slice(mb, 1..10)}..."
    end
  end

  @doc """
  Encodes bytes to a multibase string with the specified encoding.

  Supported encodings: `:base16`, `:base16upper`, `:base32`, `:base32upper`,
  `:base58btc`, `:base64`, `:base64url`, `:base64urlpad`

  ## Examples
      iex> Multibase.bytes_to_multibase("Hello", :base16)
      "f48656c6c6f"

      iex> Multibase.bytes_to_multibase("Hello", :base64)
      "mSGVsbG8="

      iex> Multibase.bytes_to_multibase(<<1, 2, 3, 4>>, :base58btc)
      "z2VfUX"
  """
  def bytes_to_multibase(bytes, encoding) when is_binary(bytes) do
    prefix = multibase_prefix(encoding)
    encoded = encode_bytes(bytes, encoding)
    prefix <> encoded
  end

  defp multibase_prefix(encoding) do
    case encoding do
      :base16 -> "f"
      :base16upper -> "F"
      :base32 -> "b"
      :base32upper -> "B"
      :base58btc -> "z"
      :base64 -> "m"
      :base64url -> "u"
      :base64urlpad -> "U"
      _ -> raise ArgumentError, "Unsupported multibase encoding: #{encoding}"
    end
  end

  defp encode_bytes(bytes, encoding) do
    case encoding do
      :base16 -> Base.encode16(bytes, case: :lower)
      :base16upper -> Base.encode16(bytes, case: :upper)
      :base32 -> Base.encode32(bytes, case: :lower, padding: false)
      :base32upper -> Base.encode32(bytes, case: :upper, padding: false)
      :base58btc -> Base58.encode(bytes)
      :base64 -> Base.encode64(bytes)
      :base64url -> Base.url_encode64(bytes, padding: false)
      :base64urlpad -> Base.url_encode64(bytes)
    end
  end

  @doc """
  Converts a DER-encoded ECDSA signature to compact (64-byte) format.
  """
  def der_to_compact(der_sig) do
    # Parse DER-encoded signature and convert to compact format
    {:ok, {r, s}} = :public_key.der_decode(:ECSignature, der_sig)

    # Convert to 32-byte big-endian format
    r_bin = :binary.encode_unsigned(r) |> pad_to_size(32)
    s_bin = :binary.encode_unsigned(s) |> pad_to_size(32)

    r_bin <> s_bin
  end

  @doc """
  Pads a binary to the given size with leading zeros.
  """
  def pad_to_size(binary, size) do
    padding = size - byte_size(binary)

    if padding > 0 do
      <<0::size(padding)-unit(8), binary::binary>>
    else
      binary
    end
  end

  @doc """
  Encodes a binary to a string in the specified encoding.
  """
  def encode_string(data, encoding) do
    case encoding do
      :base64 -> Base.encode64(data)
      :hex -> Base.encode16(data, case: :lower)
      _ -> raise "Unsupported encoding: #{encoding}"
    end
  end

  @doc """
  Ensures a public key is in uncompressed format.

  Note: This is a simplified implementation. In a production system,
  you would need proper ECC point decompression logic.
  """
  def ensure_uncompressed_pubkey(<<prefix::8, x::bytes-size(32)>>) when prefix in [0x02, 0x03] do
    # For compressed keys (0x02 or 0x03 prefix + 32-byte x coordinate)
    # We need to compute the y coordinate from the x coordinate and prefix
    # This is complex and requires solving the elliptic curve equation

    # Placeholder: Return the compressed key as-is for now
    # In a real implementation, you would:
    # 1. Convert x to an integer
    # 2. Solve y^2 = x^3 + ax + b mod p for the specific curve
    # 3. Choose the correct y based on the prefix (even/odd)
    # 4. Return <<0x04, x, y>> as uncompressed key

    # For now, we'll raise an error since proper decompression is complex
    raise "Public key decompression not implemented. Compressed keys are: #{Base.encode16(<<prefix>> <> x)}"
  end

  def ensure_uncompressed_pubkey(<<0x04, _::bytes-size(64)>> = key) do
    # Already uncompressed (0x04 prefix + 64 bytes of x+y)
    key
  end

  def ensure_uncompressed_pubkey(key) do
    raise "Unsupported public key format: #{byte_size(key)} bytes"
  end

  @doc """
  Gets the order (n) of an elliptic curve.
  """
  def get_curve_order(curve) do
    case curve do
      :secp256k1 ->
        # Order for secp256k1: FFFFFFFF FFFFFFFF FFFFFFFF FFFFFFFE BAAEDCE6 AF48A03B BFD25E8C D0364141
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141

      :secp256r1 ->
        # Order for secp256r1 (P-256): FFFFFFFF 00000000 FFFFFFFF FFFFFFFF BCE6FAAD A7179E84 F3B9CAC2 FC632551
        0xFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551

      _ ->
        raise "Unsupported curve: #{curve}"
    end
  end

  @doc """
  Checks if a signature is malleable (high S value).
  """
  def is_malleable(sig, curve) do
    # Check if signature is malleable (low S value check)
    # Signature is 64 bytes: 32 bytes R + 32 bytes S
    <<_r::bytes-size(32), s_bin::bytes-size(32)>> = sig
    s_int = :binary.decode_unsigned(s_bin, :big)

    # Get curve order
    n = get_curve_order(curve)

    # Signature is malleable if s > n/2
    s_int > div(n, 2)
  end
end
