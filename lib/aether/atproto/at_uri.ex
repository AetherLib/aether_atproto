defmodule Aether.ATProto.AtUri do
  @moduledoc """
  AT URI (at://) parsing and validation for ATProto.

  AT URIs are used to reference records and repositories in the AT Protocol.
  They can reference a repository (using just authority), a collection within
  a repository, or a specific record.

  ## Format

      at://AUTHORITY[/COLLECTION[/RKEY]][#FRAGMENT]

  Where:
  - `AUTHORITY` - A DID or handle identifying the repository
  - `COLLECTION` - An NSID identifying the record collection (e.g., `app.bsky.feed.post`)
  - `RKEY` - A record key identifying a specific record
  - `FRAGMENT` - Optional fragment identifier

  ## Examples

      # Repository reference (DID)
      iex> Aether.ATProto.AtUri.parse_at_uri("at://did:plc:z72i7hdynmk24r6zlsdc6nxd")
      {:ok, %Aether.ATProto.AtUri{authority: "did:plc:z72i7hdynmk24r6zlsdc6nxd"}}

      # Repository reference (handle)
      iex> Aether.ATProto.AtUri.parse_at_uri("at://alice.bsky.social")
      {:ok, %Aether.ATProto.AtUri{authority: "alice.bsky.social"}}

      # Collection reference
      iex> Aether.ATProto.AtUri.parse_at_uri("at://alice.bsky.social/app.bsky.feed.post")
      {:ok, %Aether.ATProto.AtUri{authority: "alice.bsky.social", collection: "app.bsky.feed.post"}}

      # Record reference
      iex> Aether.ATProto.AtUri.parse_at_uri("at://did:plc:z72i7hdynmk24r6zlsdc6nxd/app.bsky.feed.post/3jwdwj2ctlk26")
      {:ok, %Aether.ATProto.AtUri{authority: "did:plc:z72i7hdynmk24r6zlsdc6nxd", collection: "app.bsky.feed.post", rkey: "3jwdwj2ctlk26"}}

      # With fragment
      iex> Aether.ATProto.AtUri.parse_at_uri("at://alice.bsky.social/app.bsky.feed.post/123#anchor")
      {:ok, %Aether.ATProto.AtUri{authority: "alice.bsky.social", collection: "app.bsky.feed.post", rkey: "123", fragment: "anchor"}}
  """

  alias Aether.ATProto.DID

  defstruct [:authority, :collection, :rkey, :fragment]

  @type t :: %__MODULE__{
          authority: String.t(),
          collection: String.t() | nil,
          rkey: String.t() | nil,
          fragment: String.t() | nil
        }

  defmodule ParseError do
    defexception message: "Invalid AT URI format"
  end

  # Maximum AT URI length (8 kilobytes)
  @max_length 8192

  # NSID pattern: reverse domain notation (e.g., com.example.foo)
  @nsid_pattern ~r/^[a-zA-Z]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$/

  # Record key pattern: alphanumeric and some special characters
  @rkey_pattern ~r/^[a-zA-Z0-9._~:@!$&'\(\)*+,;=%\-]+$/

  @doc """
  Parse an AT URI string into structured data.

  Returns `{:ok, %Aether.ATProto.AtUri{}}` on success or `{:error, reason}` on failure.

  ## Examples

      iex> Aether.ATProto.AtUri.parse_at_uri("at://did:plc:z72i7hdynmk24r6zlsdc6nxd")
      {:ok, %Aether.ATProto.AtUri{authority: "did:plc:z72i7hdynmk24r6zlsdc6nxd"}}

      iex> Aether.ATProto.AtUri.parse_at_uri("at://alice.example.com/app.bsky.feed.post/123")
      {:ok, %Aether.ATProto.AtUri{authority: "alice.example.com", collection: "app.bsky.feed.post", rkey: "123"}}

      iex> Aether.ATProto.AtUri.parse_at_uri("invalid")
      {:error, :invalid_format}

      iex> Aether.ATProto.AtUri.parse_at_uri("at://")
      {:error, :missing_authority}
  """
  @spec parse_at_uri(String.t()) :: {:ok, t()} | {:error, atom()}
  def parse_at_uri("at://" <> rest) when is_binary(rest) do
    with :ok <- validate_length("at://" <> rest),
         {rest_without_fragment, fragment} <- extract_fragment(rest),
         {:ok, authority, collection, rkey} <- parse_path_components(rest_without_fragment) do
      {:ok,
       %__MODULE__{authority: authority, collection: collection, rkey: rkey, fragment: fragment}}
    end
  end

  def parse_at_uri(_invalid), do: {:error, :invalid_format}

  @doc """
  Parse an AT URI string, raising an exception on error.

  ## Examples

      iex> Aether.ATProto.AtUri.parse_at_uri!("at://alice.bsky.social")
      %Aether.ATProto.AtUri{authority: "alice.bsky.social"}

      iex> Aether.ATProto.AtUri.parse_at_uri!("invalid")
      ** (Aether.ATProto.AtUri.ParseError) Invalid AT URI: invalid_format
  """
  @spec parse_at_uri!(String.t()) :: t()
  def parse_at_uri!(at_uri_string) when is_binary(at_uri_string) do
    case parse_at_uri(at_uri_string) do
      {:ok, at_uri} -> at_uri
      {:error, reason} -> raise ParseError, "Invalid AT URI: #{reason}"
    end
  end

  def parse_at_uri!(%__MODULE__{} = at_uri), do: at_uri
  def parse_at_uri!(_other), do: raise(ParseError, "Invalid AT URI: invalid_format")

  @doc """
  Check if a value is a valid AT URI.

  ## Examples

      iex> Aether.ATProto.AtUri.valid_at_uri?("at://alice.bsky.social")
      true

      iex> Aether.ATProto.AtUri.valid_at_uri?("invalid")
      false

      iex> Aether.ATProto.AtUri.valid_at_uri?(%Aether.ATProto.AtUri{authority: "alice.bsky.social"})
      true
  """
  @spec valid_at_uri?(String.t() | t()) :: boolean()
  def valid_at_uri?(at_uri_string) when is_binary(at_uri_string) do
    match?({:ok, _}, parse_at_uri(at_uri_string))
  end

  def valid_at_uri?(%__MODULE__{}), do: true
  def valid_at_uri?(_), do: false

  @doc """
  Convert an AT URI struct back to its string representation.

  ## Examples

      iex> at_uri = %Aether.ATProto.AtUri{authority: "alice.bsky.social"}
      iex> Aether.ATProto.AtUri.at_uri_to_string(at_uri)
      "at://alice.bsky.social"

      iex> at_uri = %Aether.ATProto.AtUri{authority: "alice.bsky.social", collection: "app.bsky.feed.post", rkey: "123"}
      iex> Aether.ATProto.AtUri.at_uri_to_string(at_uri)
      "at://alice.bsky.social/app.bsky.feed.post/123"

      iex> at_uri = %Aether.ATProto.AtUri{authority: "alice.bsky.social", fragment: "anchor"}
      iex> Aether.ATProto.AtUri.at_uri_to_string(at_uri)
      "at://alice.bsky.social#anchor"
  """
  @spec at_uri_to_string(t() | String.t()) :: String.t()
  def at_uri_to_string(%__MODULE__{
        authority: authority,
        collection: collection,
        rkey: rkey,
        fragment: fragment
      }) do
    ["at://", authority]
    |> append_collection(collection)
    |> append_rkey(rkey)
    |> Enum.join()
    |> append_fragment(fragment)
  end

  def at_uri_to_string(at_uri_string) when is_binary(at_uri_string), do: at_uri_string

  @doc """
  Extract the authority from an AT URI.

  ## Examples

      iex> Aether.ATProto.AtUri.authority("at://alice.bsky.social/app.bsky.feed.post/123")
      "alice.bsky.social"

      iex> Aether.ATProto.AtUri.authority(%Aether.ATProto.AtUri{authority: "did:plc:z72i7hdynmk24r6zlsdc6nxd"})
      "did:plc:z72i7hdynmk24r6zlsdc6nxd"

      iex> Aether.ATProto.AtUri.authority("invalid")
      {:error, :invalid_at_uri}
  """
  @spec authority(String.t() | t()) :: String.t() | {:error, :invalid_at_uri}
  def authority(%__MODULE__{authority: authority}), do: authority

  def authority(at_uri_string) when is_binary(at_uri_string) do
    case parse_at_uri(at_uri_string) do
      {:ok, %__MODULE__{authority: authority}} -> authority
      {:error, _} -> {:error, :invalid_at_uri}
    end
  end

  @doc """
  Extract the collection from an AT URI.

  ## Examples

      iex> Aether.ATProto.AtUri.collection("at://alice.bsky.social/app.bsky.feed.post/123")
      "app.bsky.feed.post"

      iex> Aether.ATProto.AtUri.collection("at://alice.bsky.social")
      nil

      iex> Aether.ATProto.AtUri.collection(%Aether.ATProto.AtUri{authority: "alice.bsky.social", collection: "app.bsky.feed.post"})
      "app.bsky.feed.post"
  """
  @spec collection(String.t() | t()) :: String.t() | nil | {:error, :invalid_at_uri}
  def collection(%__MODULE__{collection: collection}), do: collection

  def collection(at_uri_string) when is_binary(at_uri_string) do
    case parse_at_uri(at_uri_string) do
      {:ok, %__MODULE__{collection: collection}} -> collection
      {:error, _} -> {:error, :invalid_at_uri}
    end
  end

  @doc """
  Extract the record key from an AT URI.

  ## Examples

      iex> Aether.ATProto.AtUri.rkey("at://alice.bsky.social/app.bsky.feed.post/123")
      "123"

      iex> Aether.ATProto.AtUri.rkey("at://alice.bsky.social/app.bsky.feed.post")
      nil

      iex> Aether.ATProto.AtUri.rkey(%Aether.ATProto.AtUri{authority: "alice.bsky.social", collection: "app.bsky.feed.post", rkey: "abc123"})
      "abc123"
  """
  @spec rkey(String.t() | t()) :: String.t() | nil | {:error, :invalid_at_uri}
  def rkey(%__MODULE__{rkey: rkey}), do: rkey

  def rkey(at_uri_string) when is_binary(at_uri_string) do
    case parse_at_uri(at_uri_string) do
      {:ok, %__MODULE__{rkey: rkey}} -> rkey
      {:error, _} -> {:error, :invalid_at_uri}
    end
  end

  @doc """
  Extract the fragment from an AT URI.

  ## Examples

      iex> Aether.ATProto.AtUri.fragment("at://alice.bsky.social#anchor")
      "anchor"

      iex> Aether.ATProto.AtUri.fragment("at://alice.bsky.social")
      nil

      iex> Aether.ATProto.AtUri.fragment(%Aether.ATProto.AtUri{authority: "alice.bsky.social", fragment: "section1"})
      "section1"
  """
  @spec fragment(String.t() | t()) :: String.t() | nil | {:error, :invalid_at_uri}
  def fragment(%__MODULE__{fragment: fragment}), do: fragment

  def fragment(at_uri_string) when is_binary(at_uri_string) do
    case parse_at_uri(at_uri_string) do
      {:ok, %__MODULE__{fragment: fragment}} -> fragment
      {:error, _} -> {:error, :invalid_at_uri}
    end
  end

  # Private functions

  defp validate_length(uri) when byte_size(uri) > @max_length, do: {:error, :uri_too_long}
  defp validate_length(_uri), do: :ok

  defp extract_fragment(string) do
    case String.split(string, "#", parts: 2) do
      [rest, frag] -> {rest, frag}
      [rest] -> {rest, nil}
    end
  end

  defp parse_path_components(string) do
    case String.split(string, "/", parts: 4) do
      [""] -> {:error, :missing_authority}
      [authority] -> validate_authority(authority, nil, nil)
      [authority, collection] -> validate_components(authority, collection, nil)
      [authority, collection, rkey] -> validate_components(authority, collection, rkey)
      _ -> {:error, :invalid_format}
    end
  end

  defp validate_components(authority, collection, rkey) do
    with :ok <- validate_authority_string(authority),
         :ok <- validate_collection(collection),
         :ok <- validate_rkey(rkey) do
      {:ok, authority, collection, rkey}
    end
  end

  defp validate_authority(authority, collection, rkey) do
    case validate_authority_string(authority) do
      :ok -> {:ok, authority, collection, rkey}
      error -> error
    end
  end

  defp validate_authority_string(""), do: {:error, :missing_authority}

  defp validate_authority_string(authority) do
    cond do
      String.starts_with?(authority, "did:") -> validate_did_authority(authority)
      true -> validate_handle_authority(authority)
    end
  end

  defp validate_did_authority(did) do
    case DID.parse_did(did) do
      {:ok, _} -> :ok
      {:error, _} -> {:error, :invalid_did}
    end
  end

  defp validate_handle_authority(handle) do
    # Handle validation: domain-like format
    # Allow alphanumeric, dots, hyphens
    if String.match?(
         handle,
         ~r/^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/
       ) do
      :ok
    else
      {:error, :invalid_handle}
    end
  end

  defp validate_collection(collection) do
    if String.match?(collection, @nsid_pattern) do
      :ok
    else
      {:error, :invalid_collection}
    end
  end

  defp validate_rkey(nil), do: :ok

  defp validate_rkey(rkey) do
    if String.match?(rkey, @rkey_pattern) and byte_size(rkey) <= 512 do
      :ok
    else
      {:error, :invalid_rkey}
    end
  end

  defp append_collection(parts, nil), do: parts
  defp append_collection(parts, collection), do: parts ++ ["/", collection]

  defp append_rkey(parts, nil), do: parts
  defp append_rkey(parts, rkey), do: parts ++ ["/", rkey]

  defp append_fragment(string, nil), do: string
  defp append_fragment(string, fragment), do: string <> "#" <> fragment
end
