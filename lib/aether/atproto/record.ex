defmodule Aether.ATProto.Record do
  @moduledoc """
  ATProto record data structure.

  Records in ATProto are data objects with a type (defined by a Lexicon schema)
  and arbitrary data fields. This module provides a simple struct wrapper and
  transformation functions for working with records.

  ## Usage

  Create records directly using struct syntax:

      %Aether.ATProto.Record{
        type: "app.bsky.feed.post",
        data: %{"text" => "Hello, ATProto!"}
      }

  Parse from external sources (XRPC responses):

      Aether.ATProto.Record.from_map(%{
        "$type" => "app.bsky.feed.post",
        "text" => "Hello, ATProto!",
        "createdAt" => "2024-01-15T12:00:00Z"
      })

  Convert to map for XRPC requests:

      record = %Aether.ATProto.Record{type: "app.bsky.feed.post", data: %{"text" => "Hi"}}
      Aether.ATProto.Record.to_map(record)
      #=> %{"$type" => "app.bsky.feed.post", "text" => "Hi"}

  ## Pattern Matching

  Use Elixir's pattern matching for working with records:

      # Extract type and data
      %Aether.ATProto.Record{type: type, data: data} = record

      # Update data immutably
      updated = %{record | data: Map.put(record.data, "text", "Updated")}

      # Match on specific types
      def handle_record(%Aether.ATProto.Record{type: "app.bsky.feed.post"} = post) do
        # Handle post
      end

  ## Record Structure

  - `type` - The Lexicon schema NSID (e.g., "app.bsky.feed.post")
  - `data` - Map containing the record's data fields
  - `cid` - Optional Content Identifier if loaded from repository
  """

  defstruct [:type, :data, :cid]

  @type t :: %__MODULE__{
          type: String.t(),
          data: map(),
          cid: String.t() | nil
        }

  # NSID pattern for type validation (reverse domain notation, lowercase only)
  @nsid_pattern ~r/^[a-z]([a-z0-9-]{0,61}[a-z0-9])?(\.[a-z]([a-z0-9-]{0,61}[a-z0-9])?)+\.[a-z]([a-z0-9-]{0,61}[a-z0-9])?$/

  @doc """
  Transform a map with `$type` field into a Record struct.

  Useful for parsing records from XRPC responses or JSON.

  ## Examples

      iex> Aether.ATProto.Record.from_map(%{
      ...>   "$type" => "app.bsky.feed.post",
      ...>   "text" => "Hello",
      ...>   "createdAt" => "2024-01-15T12:00:00Z"
      ...> })
      {:ok, %Aether.ATProto.Record{
        type: "app.bsky.feed.post",
        data: %{"text" => "Hello", "createdAt" => "2024-01-15T12:00:00Z"}
      }}

      iex> Aether.ATProto.Record.from_map(%{"text" => "Missing type"})
      {:error, :missing_type}

      iex> Aether.ATProto.Record.from_map(%{"$type" => "InvalidType"})
      {:error, :invalid_type}
  """
  @spec from_map(map()) :: {:ok, t()} | {:error, :missing_type | :invalid_type}
  def from_map(%{"$type" => type} = map) when is_binary(type) do
    if valid_type?(type) do
      # Extract CID if present
      cid = Map.get(map, "$cid") || Map.get(map, "cid")

      # Remove protocol fields from data
      data =
        map
        |> Map.delete("$type")
        |> Map.delete("$cid")
        |> Map.delete("cid")

      {:ok, %__MODULE__{type: type, data: data, cid: cid}}
    else
      {:error, :invalid_type}
    end
  end

  def from_map(_map), do: {:error, :missing_type}

  @doc """
  Transform a Record struct into a map with `$type` field.

  Useful for preparing records for XRPC requests or JSON serialization.

  ## Examples

      iex> record = %Aether.ATProto.Record{
      ...>   type: "app.bsky.feed.post",
      ...>   data: %{"text" => "Hello", "createdAt" => "2024-01-15T12:00:00Z"}
      ...> }
      iex> Aether.ATProto.Record.to_map(record)
      %{
        "$type" => "app.bsky.feed.post",
        "text" => "Hello",
        "createdAt" => "2024-01-15T12:00:00Z"
      }

      iex> record = %Aether.ATProto.Record{
      ...>   type: "app.bsky.feed.post",
      ...>   data: %{"text" => "Hello"},
      ...>   cid: "bafyreib2rxk3rybk"
      ...> }
      iex> Aether.ATProto.Record.to_map(record)
      %{
        "$type" => "app.bsky.feed.post",
        "text" => "Hello",
        "cid" => "bafyreib2rxk3rybk"
      }
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{type: type, data: data, cid: nil}) do
    Map.put(data, "$type", type)
  end

  def to_map(%__MODULE__{type: type, data: data, cid: cid}) when is_binary(cid) do
    data
    |> Map.put("$type", type)
    |> Map.put("cid", cid)
  end

  @doc """
  Validate that a type string is a valid NSID.

  ## Examples

      iex> Aether.ATProto.Record.valid_type?("app.bsky.feed.post")
      true

      iex> Aether.ATProto.Record.valid_type?("com.example.myapp.record")
      true

      iex> Aether.ATProto.Record.valid_type?("InvalidType")
      false

      iex> Aether.ATProto.Record.valid_type?("single")
      false
  """
  @spec valid_type?(String.t()) :: boolean()
  def valid_type?(type) when is_binary(type) do
    String.match?(type, @nsid_pattern)
  end

  def valid_type?(_), do: false

  @doc """
  Immutably update a field in the record's data.

  Returns a new Record struct with the updated data.

  ## Examples

      iex> record = %Aether.ATProto.Record{
      ...>   type: "app.bsky.feed.post",
      ...>   data: %{"text" => "Original"}
      ...> }
      iex> updated = Aether.ATProto.Record.put_in_data(record, "text", "Updated")
      iex> updated.data["text"]
      "Updated"

      iex> record = %Aether.ATProto.Record{
      ...>   type: "app.bsky.feed.post",
      ...>   data: %{"text" => "Hello"}
      ...> }
      iex> updated = Aether.ATProto.Record.put_in_data(record, "likes", 42)
      iex> updated.data
      %{"text" => "Hello", "likes" => 42}
  """
  @spec put_in_data(t(), String.t(), term()) :: t()
  def put_in_data(%__MODULE__{data: data} = record, key, value) when is_binary(key) do
    %{record | data: Map.put(data, key, value)}
  end

  @doc """
  Get a field from the record's data with an optional default.

  ## Examples

      iex> record = %Aether.ATProto.Record{
      ...>   type: "app.bsky.feed.post",
      ...>   data: %{"text" => "Hello", "likes" => 10}
      ...> }
      iex> Aether.ATProto.Record.get_from_data(record, "text")
      "Hello"

      iex> record = %Aether.ATProto.Record{
      ...>   type: "app.bsky.feed.post",
      ...>   data: %{"text" => "Hello"}
      ...> }
      iex> Aether.ATProto.Record.get_from_data(record, "likes", 0)
      0
  """
  @spec get_from_data(t(), String.t(), term()) :: term()
  def get_from_data(%__MODULE__{data: data}, key, default \\ nil) when is_binary(key) do
    Map.get(data, key, default)
  end
end
