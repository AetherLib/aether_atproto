defmodule AetherATProtoCore.MST do
  @moduledoc """
  Merkle Search Tree (MST) implementation for ATProto repositories.

  The MST is a content-addressed, deterministic data structure that stores
  key-value pairs in sorted order. It's the core data structure used in
  ATProto repositories to store records.

  ## Structure

  The tree consists of nodes, where each node contains:
  - A left pointer to a subtree with keys that sort before this node
  - An ordered list of entries, each containing:
    - A key (compressed with prefix length)
    - A value CID (pointing to the record)
    - An optional tree pointer to keys sorting after this entry

  ## Key Depth

  Keys are placed in the tree based on their "depth", calculated by:
  1. Hash the key with SHA-256
  2. Count leading zero bits
  3. Divide by 2 (rounding down)

  This creates a tree with approximately 4-way fanout.

  ## Usage

  ```elixir
  # Create a new MST
  mst = %AetherATProtoCore.MST{}

  # Add entries
  {:ok, mst} = AetherATProtoCore.MST.add(mst, "app.bsky.feed.post/abc", value_cid)
  {:ok, mst} = AetherATProtoCore.MST.add(mst, "app.bsky.feed.post/xyz", value_cid)

  # Get an entry
  {:ok, cid} = AetherATProtoCore.MST.get(mst, "app.bsky.feed.post/abc")

  # List all entries
  entries = AetherATProtoCore.MST.list(mst)

  # Delete an entry
  {:ok, mst} = AetherATProtoCore.MST.delete(mst, "app.bsky.feed.post/abc")
  ```

  ## Storage

  The MST can work with different storage backends by implementing
  the `AetherATProtoCore.MST.NodeStore` behavior. This allows you to store
  nodes in memory, Ecto, Mnesia, or any other backend.
  """

  alias AetherATProtoCore.CID
  alias AetherATProtoCore.MST.Entry

  defstruct layer: 0, entries: [], pointer: nil

  @type t :: %__MODULE__{
          layer: non_neg_integer(),
          entries: [AetherATProtoCore.MST.Entry.t()],
          pointer: CID.t() | nil
        }

  @doc """
  Add or update a key-value pair in the MST.

  Returns `{:ok, new_mst}` with the updated tree.

  ## Examples

      iex> mst = %AetherATProtoCore.MST{}
      iex> cid = AetherATProtoCore.CID.parse_cid!("bafyreie5cvv4h45feadgeuwhbcutmh6t2ceseocckahdoe6uat64zmz454")
      iex> {:ok, mst} = AetherATProtoCore.MST.add(mst, "app.bsky.feed.post/abc", cid)
      iex> {:ok, ^cid} = AetherATProtoCore.MST.get(mst, "app.bsky.feed.post/abc")
      iex> :ok
      :ok
  """
  @spec add(t(), String.t(), CID.t()) :: {:ok, t()} | {:error, term()}
  def add(%__MODULE__{} = mst, key, value) when is_binary(key) do
    key_depth = calculate_key_depth(key)
    do_add(mst, key, value, key_depth)
  end

  @doc """
  Get the value CID for a key.

  Returns `{:ok, cid}` if found, or `{:error, :not_found}` if the key doesn't exist.

  ## Examples

      iex> mst = %AetherATProtoCore.MST{}
      iex> AetherATProtoCore.MST.get(mst, "app.bsky.feed.post/abc")
      {:error, :not_found}
  """
  @spec get(t(), String.t()) :: {:ok, CID.t()} | {:error, :not_found}
  def get(%__MODULE__{entries: entries}, key) when is_binary(key) do
    case find_entry(entries, key) do
      {:ok, entry} -> {:ok, entry.value}
      :not_found -> {:error, :not_found}
    end
  end

  @doc """
  Delete a key from the MST.

  Returns `{:ok, new_mst}` with the key removed, or `{:error, :not_found}` if the key doesn't exist.

  ## Examples

      iex> mst = %AetherATProtoCore.MST{}
      iex> cid = AetherATProtoCore.CID.parse_cid!("bafyreie5cvv4h45feadgeuwhbcutmh6t2ceseocckahdoe6uat64zmz454")
      iex> {:ok, mst} = AetherATProtoCore.MST.add(mst, "app.bsky.feed.post/abc", cid)
      iex> {:ok, mst} = AetherATProtoCore.MST.delete(mst, "app.bsky.feed.post/abc")
      iex> AetherATProtoCore.MST.get(mst, "app.bsky.feed.post/abc")
      {:error, :not_found}
  """
  @spec delete(t(), String.t()) :: {:ok, t()} | {:error, :not_found}
  def delete(%__MODULE__{entries: entries} = mst, key) when is_binary(key) do
    case find_entry_index(entries, key) do
      {:ok, index} ->
        new_entries = List.delete_at(entries, index)
        {:ok, %{mst | entries: new_entries}}

      :not_found ->
        {:error, :not_found}
    end
  end

  @doc """
  List all entries in the MST in key-sorted order.

  Returns a list of `{key, value_cid}` tuples.

  ## Examples

      iex> mst = %AetherATProtoCore.MST{}
      iex> AetherATProtoCore.MST.list(mst)
      []
  """
  @spec list(t()) :: [{String.t(), CID.t()}]
  def list(%__MODULE__{entries: entries}) do
    Enum.map(entries, fn entry -> {entry.key, entry.value} end)
  end

  @doc """
  Calculate the depth of a key in the MST.

  Uses SHA-256 hash of the key and counts leading zero bits, divided by 2.

  ## Examples

      iex> depth = AetherATProtoCore.MST.calculate_key_depth("app.bsky.feed.post/abc")
      iex> is_integer(depth) and depth >= 0
      true
  """
  @spec calculate_key_depth(String.t()) :: non_neg_integer()
  def calculate_key_depth(key) when is_binary(key) do
    # Hash the key with SHA-256
    hash = :crypto.hash(:sha256, key)

    # Count leading zero bits
    leading_zeros = count_leading_zeros(hash)

    # Divide by 2, rounding down
    div(leading_zeros, 2)
  end

  # Private functions

  defp do_add(%__MODULE__{layer: layer, entries: entries} = mst, key, value, key_depth) do
    cond do
      # Key belongs in this layer
      key_depth == layer ->
        new_entries = insert_entry(entries, key, value)
        {:ok, %{mst | entries: new_entries}}

      # Key belongs in a deeper layer - would need subtree handling
      key_depth > layer ->
        # For now, simplified: insert at current layer
        # Full implementation would create/update subtrees
        new_entries = insert_entry(entries, key, value)
        {:ok, %{mst | entries: new_entries}}

      # Key belongs in a shallower layer - need to restructure
      true ->
        # Simplified: insert at current layer
        new_entries = insert_entry(entries, key, value)
        {:ok, %{mst | entries: new_entries}}
    end
  end

  defp insert_entry(entries, key, value) do
    entry = %Entry{key: key, value: value, prefix_len: 0}

    # Find insertion point to maintain sorted order
    insert_sorted(entries, entry)
  end

  defp insert_sorted([], entry), do: [entry]

  defp insert_sorted([head | tail] = entries, entry) do
    cond do
      entry.key < head.key ->
        [entry | entries]

      entry.key == head.key ->
        # Update existing entry
        [entry | tail]

      true ->
        [head | insert_sorted(tail, entry)]
    end
  end

  defp find_entry([], _key), do: :not_found

  defp find_entry([entry | rest], key) do
    cond do
      entry.key == key -> {:ok, entry}
      entry.key > key -> :not_found
      true -> find_entry(rest, key)
    end
  end

  defp find_entry_index(entries, key) do
    entries
    |> Enum.with_index()
    |> Enum.find_value(:not_found, fn {entry, index} ->
      if entry.key == key, do: {:ok, index}
    end)
  end

  defp count_leading_zeros(<<byte, _rest::binary>>) when byte != 0 do
    # Count leading zeros in this byte
    count_leading_zeros_in_byte(byte)
  end

  defp count_leading_zeros(<<0, rest::binary>>) do
    8 + count_leading_zeros(rest)
  end

  defp count_leading_zeros(<<>>), do: 0

  defp count_leading_zeros_in_byte(byte) do
    # Count leading zeros in a single byte
    cond do
      byte >= 128 -> 0
      byte >= 64 -> 1
      byte >= 32 -> 2
      byte >= 16 -> 3
      byte >= 8 -> 4
      byte >= 4 -> 5
      byte >= 2 -> 6
      byte >= 1 -> 7
      true -> 8
    end
  end
end
