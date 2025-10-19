# lib/crypto/did.ex
defmodule Aether.Crypto.DID do
  @moduledoc """
  DID key parsing and formatting functionality.
  """

  alias Aether.Crypto

  # Constants
  @p256_did_prefix <<0x80, 0x24>>
  @secp256k1_did_prefix <<0xE7, 0x01>>
  @base58_multibase_prefix "z"
  @did_key_prefix "did:key:"

  @p256_jwt_alg "ES256"
  @secp256k1_jwt_alg "ES256K"

  @type parsed_multikey :: %{
          jwt_alg: String.t(),
          key_bytes: binary()
        }

  @doc """
  Parses a multikey string and returns the JWT algorithm and decompressed key bytes.
  """
  def parse_multikey(multikey) when is_binary(multikey) do
    multikey
    |> extract_prefixed_bytes()
    |> parse_prefixed_bytes()
  end

  @doc """
  Formats key bytes and JWT algorithm into a multikey string.
  """
  def format_multikey(jwt_alg, key_bytes) when is_binary(key_bytes) do
    case jwt_alg do
      @p256_jwt_alg ->
        compressed_key = Crypto.P256.compress_pubkey(key_bytes)
        @base58_multibase_prefix <> Base58.encode(@p256_did_prefix <> compressed_key)

      @secp256k1_jwt_alg ->
        compressed_key = Crypto.SECP256K1.compress_pubkey(key_bytes)
        @base58_multibase_prefix <> Base58.encode(@secp256k1_did_prefix <> compressed_key)

      _ ->
        raise ArgumentError, "Unsupported key type"
    end
  end

  @doc """
  Parses a DID key string and returns the parsed multikey.
  """
  def parse_did_key(did) when is_binary(did) do
    did
    |> extract_multikey()
    |> parse_multikey()
  end

  @doc """
  Formats key bytes and JWT algorithm into a DID key string.
  """
  def format_did_key(jwt_alg, key_bytes) when is_binary(key_bytes) do
    @did_key_prefix <> format_multikey(jwt_alg, key_bytes)
  end

  # Private helper functions with pattern matching

  defp parse_prefixed_bytes(<<@p256_did_prefix::binary, key_bytes::binary>>) do
    %{jwt_alg: @p256_jwt_alg, key_bytes: Crypto.P256.decompress_pubkey(key_bytes)}
  end

  defp parse_prefixed_bytes(<<@secp256k1_did_prefix::binary, key_bytes::binary>>) do
    %{jwt_alg: @secp256k1_jwt_alg, key_bytes: Crypto.SECP256K1.decompress_pubkey(key_bytes)}
  end

  defp parse_prefixed_bytes(_prefixed_bytes) do
    raise ArgumentError, "Unsupported key type"
  end

  defp extract_multikey(<<@did_key_prefix::binary, multikey::binary>>), do: multikey
  defp extract_multikey(did), do: raise(ArgumentError, "Incorrect prefix for did:key: #{did}")

  defp extract_prefixed_bytes(<<@base58_multibase_prefix::binary, multikey::binary>>) do
    Base58.decode(multikey)
  end

  defp extract_prefixed_bytes(multikey) do
    raise(ArgumentError, "Incorrect prefix for multikey: #{multikey}")
  end
end
