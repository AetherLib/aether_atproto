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
    prefixed_bytes = extract_prefixed_bytes(multikey)

    cond do
      has_prefix(prefixed_bytes, @p256_did_prefix) ->
        key_bytes =
          prefixed_bytes
          |> binary_part(
            byte_size(@p256_did_prefix),
            byte_size(prefixed_bytes) - byte_size(@p256_did_prefix)
          )
          |> Crypto.P256.decompress_pubkey()

        %{jwt_alg: @p256_jwt_alg, key_bytes: key_bytes}

      has_prefix(prefixed_bytes, @secp256k1_did_prefix) ->
        key_bytes =
          prefixed_bytes
          |> binary_part(
            byte_size(@secp256k1_did_prefix),
            byte_size(prefixed_bytes) - byte_size(@secp256k1_did_prefix)
          )
          |> Crypto.SECP256K1.decompress_pubkey()

        %{jwt_alg: @secp256k1_jwt_alg, key_bytes: key_bytes}

      true ->
        raise ArgumentError, "Unsupported key type"
    end
  end

  @doc """
  Formats key bytes and JWT algorithm into a multikey string.
  """
  def format_multikey(jwt_alg, key_bytes) when is_binary(key_bytes) do
    {prefix, compress_fn} =
      case jwt_alg do
        @p256_jwt_alg -> {@p256_did_prefix, &Crypto.P256.compress_pubkey/1}
        @secp256k1_jwt_alg -> {@secp256k1_did_prefix, &Crypto.SECP256K1.compress_pubkey/1}
        _ -> raise ArgumentError, "Unsupported key type"
      end

    compressed_key = compress_fn.(key_bytes)
    prefixed_bytes = prefix <> compressed_key

    @base58_multibase_prefix <> Base58.encode(prefixed_bytes)
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

  # Private helper functions

  defp extract_multikey(did) when is_binary(did) do
    if String.starts_with?(did, @did_key_prefix) do
      String.slice(did, String.length(@did_key_prefix)..-1)
    else
      raise ArgumentError, "Incorrect prefix for did:key: #{did}"
    end
  end

  defp extract_prefixed_bytes(multikey) when is_binary(multikey) do
    if String.starts_with?(multikey, @base58_multibase_prefix) do
      multikey
      |> String.slice(String.length(@base58_multibase_prefix)..-1)
      |> Base58.decode()
    else
      raise ArgumentError, "Incorrect prefix for multikey: #{multikey}"
    end
  end

  defp has_prefix(bytes, prefix) when is_binary(bytes) and is_binary(prefix) do
    prefix_size = byte_size(prefix)

    if byte_size(bytes) >= prefix_size do
      binary_part(bytes, 0, prefix_size) == prefix
    else
      false
    end
  end
end
