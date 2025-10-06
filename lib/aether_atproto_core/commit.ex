defmodule AetherATProtoCore.Commit do
  @moduledoc """
  Repository commit handling for ATProto.

  A commit represents a signed snapshot of a repository at a specific point in time.
  Each commit contains:
  - The repository DID
  - A revision identifier (TID)
  - A CID pointing to the MST root
  - Optional previous commit CID
  - A cryptographic signature

  ## Structure

  Commits are content-addressed and form a chain via the `prev` field,
  though in version 3 of the repository format, the `prev` field is typically null.

  ## Usage

  ```elixir
  # Create a new commit
  commit = %AetherATProtoCore.Commit{
    did: "did:plc:abc123",
    version: 3,
    data: mst_root_cid,
    rev: AetherATProtoCore.TID.new(),
    prev: nil
  }

  # Sign the commit (requires signing key)
  {:ok, signed_commit} = AetherATProtoCore.Commit.sign(commit, signing_key)

  # Verify a commit signature
  {:ok, valid?} = AetherATProtoCore.Commit.verify(signed_commit, public_key)
  ```

  ## Signing

  Commits are signed using the repository's signing key from its DID document.
  The signature covers the DAG-CBOR serialization of the unsigned commit fields.

  For this library implementation, we provide the structure and validation,
  but actual signing/verification should be implemented in your application
  using your preferred cryptography library (e.g., `ex_crypto`, `kcl`).
  """

  alias AetherATProtoCore.CID
  alias AetherATProtoCore.TID

  @version 3

  defstruct [
    :did,
    :version,
    :data,
    :rev,
    :prev,
    :sig
  ]

  @type t :: %__MODULE__{
          did: String.t(),
          version: non_neg_integer(),
          data: CID.t(),
          rev: String.t(),
          prev: CID.t() | nil,
          sig: binary() | nil
        }

  @doc """
  Create a new unsigned commit.

  ## Examples

      iex> mst_cid = AetherATProtoCore.CID.parse_cid!("bafyreie5cvv4h45feadgeuwhbcutmh6t2ceseocckahdoe6uat64zmz454")
      iex> commit = AetherATProtoCore.Commit.create("did:plc:abc123", mst_cid)
      iex> commit.did
      "did:plc:abc123"
      iex> commit.version
      3
      iex> commit.prev
      nil
  """
  @spec create(String.t(), CID.t(), keyword()) :: t()
  def create(did, data_cid, opts \\ []) do
    %__MODULE__{
      did: did,
      version: @version,
      data: data_cid,
      rev: Keyword.get_lazy(opts, :rev, &TID.new/0),
      prev: Keyword.get(opts, :prev),
      sig: nil
    }
  end

  @doc """
  Get the CID for this commit.

  Computes a content-addressed identifier for the commit.
  In a full implementation, this would hash the DAG-CBOR representation.
  For now, this is a simplified version.

  ## Examples

      iex> mst_cid = AetherATProtoCore.CID.parse_cid!("bafyreie5cvv4h45feadgeuwhbcutmh6t2ceseocckahdoe6uat64zmz454")
      iex> commit = AetherATProtoCore.Commit.create("did:plc:abc123", mst_cid)
      iex> cid = AetherATProtoCore.Commit.cid(commit)
      iex> %AetherATProtoCore.CID{} = cid
  """
  @spec cid(t()) :: CID.t()
  def cid(%__MODULE__{} = commit) do
    # Simplified CID generation
    # In production, this would:
    # 1. Encode commit as DAG-CBOR
    # 2. Hash with SHA-256
    # 3. Create CID with multicodec prefix
    hash_input = "#{commit.did}#{commit.rev}#{CID.cid_to_string(commit.data)}"
    hash = :crypto.hash(:sha256, hash_input) |> Base.encode32(case: :lower, padding: false)
    CID.new(1, "dag-cbor", "b" <> hash)
  end

  @doc """
  Create a new commit that follows a previous commit.

  The revision must be greater than the previous commit's revision.

  ## Examples

      iex> mst_cid = AetherATProtoCore.CID.parse_cid!("bafyreie5cvv4h45feadgeuwhbcutmh6t2ceseocckahdoe6uat64zmz454")
      iex> prev_cid = AetherATProtoCore.CID.parse_cid!("bafyreibvjvcv745gig4mvqs4hctx4zfkono4rjejm2ta6gtyzkqxfjeily")
      iex> commit = AetherATProtoCore.Commit.create_next("did:plc:abc123", mst_cid, prev_cid)
      iex> commit.prev
      prev_cid
  """
  @spec create_next(String.t(), CID.t(), CID.t(), keyword()) :: t()
  def create_next(did, data_cid, prev_cid, opts \\ []) do
    opts = Keyword.put(opts, :prev, prev_cid)
    create(did, data_cid, opts)
  end

  @doc """
  Sign a commit with a signing function.

  The signing function should take the commit bytes and return a signature.
  This allows you to use any cryptography library in your application.

  ## Examples

      # Define your signing function
      signing_fn = fn bytes ->
        # Use your preferred crypto library
        :crypto.sign(:eddsa, :sha512, bytes, private_key)
      end

      # Sign the commit
      {:ok, signed_commit} = AetherATProtoCore.Commit.sign(commit, signing_fn)
  """
  @spec sign(t(), (binary() -> binary())) :: {:ok, t()} | {:error, term()}
  def sign(%__MODULE__{} = commit, signing_fn) when is_function(signing_fn, 1) do
    try do
      # Serialize commit for signing (without sig field)
      bytes = serialize_for_signing(commit)

      # Sign the bytes
      signature = signing_fn.(bytes)

      {:ok, %{commit | sig: signature}}
    rescue
      e -> {:error, {:signing_failed, e}}
    end
  end

  @doc """
  Verify a commit signature with a verification function.

  The verification function should take the commit bytes and signature,
  and return a boolean indicating if the signature is valid.

  ## Examples

      # Define your verification function
      verify_fn = fn bytes, sig ->
        # Use your preferred crypto library
        :crypto.verify(:eddsa, :sha512, bytes, sig, public_key)
      end

      # Verify the commit
      {:ok, true} = AetherATProtoCore.Commit.verify(commit, verify_fn)
  """
  @spec verify(t(), (binary(), binary() -> boolean())) :: {:ok, boolean()} | {:error, term()}
  def verify(%__MODULE__{sig: nil}, _verify_fn) do
    {:error, :unsigned_commit}
  end

  def verify(%__MODULE__{sig: sig} = commit, verify_fn) when is_function(verify_fn, 2) do
    try do
      # Serialize commit for verification (without sig field)
      bytes = serialize_for_signing(commit)

      # Verify the signature
      valid? = verify_fn.(bytes, sig)

      {:ok, valid?}
    rescue
      e -> {:error, {:verification_failed, e}}
    end
  end

  @doc """
  Check if a commit is signed.

  ## Examples

      iex> commit = %AetherATProtoCore.Commit{sig: nil}
      iex> AetherATProtoCore.Commit.signed?(commit)
      false

      iex> commit = %AetherATProtoCore.Commit{sig: <<1, 2, 3>>}
      iex> AetherATProtoCore.Commit.signed?(commit)
      true
  """
  @spec signed?(t()) :: boolean()
  def signed?(%__MODULE__{sig: nil}), do: false
  def signed?(%__MODULE__{sig: _sig}), do: true

  @doc """
  Validate a commit structure.

  Checks that all required fields are present and valid.

  ## Examples

      iex> mst_cid = AetherATProtoCore.CID.parse_cid!("bafyreie5cvv4h45feadgeuwhbcutmh6t2ceseocckahdoe6uat64zmz454")
      iex> commit = AetherATProtoCore.Commit.create("did:plc:abc123", mst_cid)
      iex> AetherATProtoCore.Commit.validate(commit)
      :ok
  """
  @spec validate(t()) :: :ok | {:error, term()}
  def validate(%__MODULE__{} = commit) do
    with :ok <- validate_did(commit.did),
         :ok <- validate_version(commit.version),
         :ok <- validate_data(commit.data),
         :ok <- validate_rev(commit.rev),
         :ok <- validate_prev(commit.prev) do
      :ok
    end
  end

  @doc """
  Compare two revisions to determine ordering.

  Returns `:gt` if rev1 > rev2, `:lt` if rev1 < rev2, or `:eq` if equal.

  ## Examples

      iex> AetherATProtoCore.Commit.compare_revs("3jzfcijpj2z2a", "3jzfcijpj2z29")
      :gt
  """
  @spec compare_revs(String.t(), String.t()) :: :gt | :lt | :eq
  def compare_revs(rev1, rev2) when is_binary(rev1) and is_binary(rev2) do
    cond do
      rev1 > rev2 -> :gt
      rev1 < rev2 -> :lt
      true -> :eq
    end
  end

  # Private functions

  defp serialize_for_signing(%__MODULE__{} = commit) do
    # Create a map without the sig field for signing
    # In a full implementation, this would use proper DAG-CBOR encoding
    # For now, we use Erlang's term_to_binary as a placeholder
    unsigned = %{
      did: commit.did,
      version: commit.version,
      data: CID.cid_to_string(commit.data),
      rev: commit.rev,
      prev: if(commit.prev, do: CID.cid_to_string(commit.prev), else: nil)
    }

    :erlang.term_to_binary(unsigned)
  end

  defp validate_did(did) when is_binary(did) do
    if String.starts_with?(did, "did:") do
      :ok
    else
      {:error, :invalid_did}
    end
  end

  defp validate_did(_), do: {:error, :invalid_did}

  defp validate_version(@version), do: :ok
  defp validate_version(_), do: {:error, :invalid_version}

  defp validate_data(%CID{}), do: :ok
  defp validate_data(_), do: {:error, :invalid_data_cid}

  defp validate_rev(rev) when is_binary(rev) do
    if TID.valid_tid?(rev) do
      :ok
    else
      {:error, :invalid_rev}
    end
  end

  defp validate_rev(_), do: {:error, :invalid_rev}

  defp validate_prev(nil), do: :ok
  defp validate_prev(%CID{}), do: :ok
  defp validate_prev(_), do: {:error, :invalid_prev_cid}
end
