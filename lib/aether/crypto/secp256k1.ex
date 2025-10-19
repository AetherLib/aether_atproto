# lib/crypto/secp256k1.ex
defmodule Aether.Crypto.SECP256K1 do
  @moduledoc """
  SECP256K1 cryptographic operations and keypair management.
  """

  alias Aether.Crypto.Utils
  alias Aether.Crypto

  @jwt_alg "ES256K"
  @curve :secp256k1

  defstruct private_key: nil, public_key: nil, exportable: false

  @type t :: %__MODULE__{
          private_key: binary() | nil,
          public_key: binary(),
          exportable: boolean()
        }

  # Keypair Operations

  @doc """
  Creates a new SECP256K1 keypair.
  """
  def create(opts \\ []) do
    exportable = Keyword.get(opts, :exportable, false)

    # Generate private key
    private_key = :crypto.strong_rand_bytes(32)

    # Generate public key from private key
    {public_key, _} = :crypto.generate_key(:ecdh, @curve, private_key)

    %__MODULE__{
      private_key: private_key,
      public_key: public_key,
      exportable: exportable
    }
  end

  @doc """
  Imports a private key.
  """
  def import_private_key(priv_key, opts \\ []) do
    exportable = Keyword.get(opts, :exportable, false)

    private_key =
      if is_binary(priv_key) do
        priv_key
      else
        raise ArgumentError, "Private key must be a binary"
      end

    # Generate public key from private key
    {public_key, _} = :crypto.generate_key(:ecdh, @curve, private_key)

    %__MODULE__{
      private_key: private_key,
      public_key: public_key,
      exportable: exportable
    }
  end

  @doc """
  Returns the public key bytes.
  """
  def public_key_bytes(%__MODULE__{public_key: public_key}), do: public_key

  @doc """
  Returns the public key as a string in the specified encoding.
  """
  def public_key_str(keypair, encoding \\ :base64) do
    keypair
    |> public_key_bytes()
    |> Utils.encode_string(encoding)
  end

  @doc """
  Returns the DID for this keypair.
  """
  def did(keypair) do
    public_key = public_key_bytes(keypair)
    Crypto.DID.format_did_key(@jwt_alg, public_key)
  end

  @doc """
  Signs a message.
  """
  def sign(%__MODULE__{private_key: private_key}, msg) do
    # Hash the message
    msg_hash = :crypto.hash(:sha256, msg)

    # Sign the hash
    signature = :crypto.sign(:ecdsa, :sha256, msg_hash, [private_key, @curve])

    # Convert DER-encoded signature to compact format (64 bytes)
    Utils.der_to_compact(signature)
  end

  @doc """
  Exports the private key if allowed.
  """
  def export(%__MODULE__{exportable: true, private_key: private_key}), do: private_key
  def export(%__MODULE__{exportable: false}), do: raise("Private key is not exportable")

  # Signature Verification Operations

  @doc """
  Verifies a signature for a DID key.
  """
  def verify_did_sig(did, data, sig, opts \\ []) do
    allow_malleable = Keyword.get(opts, :allow_malleable_sig, false)

    # Extract and parse the DID to get the public key
    parsed = Crypto.DID.parse_did_key(did)

    if parsed.jwt_alg != @jwt_alg do
      raise ArgumentError, "Not a secp256k1 did:key: #{did}"
    end

    verify_sig(parsed.key_bytes, data, sig, allow_malleable: allow_malleable)
  end

  @doc """
  Verifies a signature with a public key.
  """
  def verify_sig(public_key, data, sig, opts \\ []) do
    allow_malleable = Keyword.get(opts, :allow_malleable_sig, false)

    # Hash the data
    msg_hash = :crypto.hash(:sha256, data)

    # Convert public key to the format expected by Erlang crypto
    uncompressed_pubkey = Utils.ensure_uncompressed_pubkey(public_key)

    # Verify the signature
    case :crypto.verify(:ecdsa, :sha256, msg_hash, sig, [uncompressed_pubkey, @curve]) do
      true ->
        # Check for malleability if required
        if allow_malleable do
          true
        else
          is_compact_format(sig) and not Utils.is_malleable(sig, @curve)
        end

      false ->
        false
    end
  end

  @doc """
  Checks if a signature is in compact format.
  """
  def is_compact_format(sig) when byte_size(sig) == 64, do: true
  def is_compact_format(_), do: false

  # Encoding Operations

  @doc """
  Compresses a SECP256K1 public key.
  """
  def compress_pubkey(uncompressed_key) do
    # Uncompressed key is 65 bytes: 0x04 + x + y
    # Compressed key is 33 bytes: 0x02/0x03 + x
    <<0x04, x::binary-32, y::binary-32>> = uncompressed_key

    # Check if y is even or odd to determine prefix
    <<y_last::8>> = binary_part(y, 31, 1)
    prefix = if rem(y_last, 2) == 0, do: <<0x02>>, else: <<0x03>>

    prefix <> x
  end

  @doc """
  Decompresses a SECP256K1 public key.
  """
  def decompress_pubkey(compressed_key) do
    # For now, return as-is since Erlang crypto typically handles compressed keys
    # In a full implementation, you'd perform proper ECC point decompression
    compressed_key
  end
end
