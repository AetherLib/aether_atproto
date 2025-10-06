defmodule AetherATProtoCore.NSID do
  @moduledoc """
  NSID (Namespaced Identifier) parsing and validation for ATProto.

  NSIDs are used throughout ATProto to reference:
  - Lexicon schemas
  - Record types (e.g., `app.bsky.feed.post`)
  - XRPC method names (e.g., `com.atproto.repo.createRecord`)
  - Collections

  ## Format

  An NSID consists of a domain authority (in reverse domain notation) followed
  by a name:

      AUTHORITY.NAME

  For example: `com.example.fooBar`
  - Authority: `com.example` (reverse domain)
  - Name: `fooBar` (method/type name)

  ## Validation Rules

  **Authority** (Domain):
  - At least 2 segments
  - Maximum 253 characters total
  - Each segment: 1-63 characters
  - Lowercase ASCII letters, digits, hyphens only
  - Cannot start/end with hyphen
  - First segment cannot start with digit

  **Name**:
  - 1-63 characters
  - ASCII letters and digits only (case-sensitive)
  - Cannot start with a digit
  - No hyphens allowed

  **Total**:
  - At least 3 segments total
  - Maximum 317 characters

  ## Examples

      # Valid NSIDs
      iex> AetherATProtoCore.NSID.valid_nsid?("com.example.fooBar")
      true

      iex> AetherATProtoCore.NSID.valid_nsid?("app.bsky.feed.post")
      true

      iex> AetherATProtoCore.NSID.valid_nsid?("com.atproto.repo.createRecord")
      true

      # Invalid NSIDs
      iex> AetherATProtoCore.NSID.valid_nsid?("com.example")
      false

      iex> AetherATProtoCore.NSID.valid_nsid?("com.example.3foo")
      false

      iex> AetherATProtoCore.NSID.valid_nsid?("com.Example.foo")
      false

  ## Usage

      # Parse an NSID
      {:ok, nsid} = AetherATProtoCore.NSID.parse_nsid("com.example.fooBar")

      # Extract components
      AetherATProtoCore.NSID.authority(nsid)
      #=> "com.example"

      AetherATProtoCore.NSID.name(nsid)
      #=> "fooBar"

      # Convert back to string
      AetherATProtoCore.NSID.nsid_to_string(nsid)
      #=> "com.example.fooBar"
  """

  defstruct [:authority, :name]

  @type t :: %__MODULE__{
          authority: String.t(),
          name: String.t()
        }

  defmodule ParseError do
    defexception message: "Invalid NSID format"
  end

  # Maximum lengths per spec
  @max_total_length 317
  @max_authority_length 253
  @max_segment_length 63

  # Authority segment pattern (lowercase, letters/digits/hyphens)
  @authority_segment_pattern ~r/^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$/

  # Name pattern (case-sensitive, letters/digits only, no leading digit)
  @name_pattern ~r/^[a-zA-Z][a-zA-Z0-9]{0,62}$/

  @doc """
  Parse an NSID string into structured data.

  Returns `{:ok, %AetherATProtoCore.NSID{}}` on success or `{:error, reason}` on failure.

  ## Examples

      iex> AetherATProtoCore.NSID.parse_nsid("com.example.fooBar")
      {:ok, %AetherATProtoCore.NSID{authority: "com.example", name: "fooBar"}}

      iex> AetherATProtoCore.NSID.parse_nsid("app.bsky.feed.post")
      {:ok, %AetherATProtoCore.NSID{authority: "app.bsky.feed", name: "post"}}

      iex> AetherATProtoCore.NSID.parse_nsid("com.atproto.repo.createRecord")
      {:ok, %AetherATProtoCore.NSID{authority: "com.atproto.repo", name: "createRecord"}}

      iex> AetherATProtoCore.NSID.parse_nsid("com.example")
      {:error, :too_few_segments}

      iex> AetherATProtoCore.NSID.parse_nsid("com.example.3foo")
      {:error, :invalid_name}
  """
  @spec parse_nsid(String.t()) :: {:ok, t()} | {:error, atom()}
  def parse_nsid(nsid_string) when is_binary(nsid_string) do
    with :ok <- validate_ascii(nsid_string),
         {:ok, segments} <- split_segments(nsid_string),
         :ok <- validate_segment_count(segments),
         {:ok, authority_segments, name} <- split_authority_and_name(segments),
         :ok <- validate_length(nsid_string),
         :ok <- validate_authority_segments(authority_segments),
         :ok <- validate_name(name) do
      authority = Enum.join(authority_segments, ".")
      {:ok, %__MODULE__{authority: authority, name: name}}
    end
  end

  def parse_nsid(_), do: {:error, :invalid_input}

  @doc """
  Parse an NSID string, raising an exception on error.

  ## Examples

      iex> AetherATProtoCore.NSID.parse_nsid!("com.example.fooBar")
      %AetherATProtoCore.NSID{authority: "com.example", name: "fooBar"}

      iex> AetherATProtoCore.NSID.parse_nsid!("invalid")
      ** (AetherATProtoCore.NSID.ParseError) Invalid NSID: too_few_segments
  """
  @spec parse_nsid!(String.t()) :: t()
  def parse_nsid!(nsid_string) when is_binary(nsid_string) do
    case parse_nsid(nsid_string) do
      {:ok, nsid} -> nsid
      {:error, reason} -> raise ParseError, "Invalid NSID: #{reason}"
    end
  end

  def parse_nsid!(%__MODULE__{} = nsid), do: nsid
  def parse_nsid!(_other), do: raise(ParseError, "Invalid NSID: invalid_input")

  @doc """
  Check if a value is a valid NSID.

  ## Examples

      iex> AetherATProtoCore.NSID.valid_nsid?("com.example.fooBar")
      true

      iex> AetherATProtoCore.NSID.valid_nsid?("app.bsky.feed.post")
      true

      iex> AetherATProtoCore.NSID.valid_nsid?("com.example")
      false

      iex> AetherATProtoCore.NSID.valid_nsid?("COM.EXAMPLE.FOO")
      false

      iex> AetherATProtoCore.NSID.valid_nsid?(%AetherATProtoCore.NSID{authority: "com.example", name: "foo"})
      true
  """
  @spec valid_nsid?(String.t() | t()) :: boolean()
  def valid_nsid?(nsid_string) when is_binary(nsid_string) do
    match?({:ok, _}, parse_nsid(nsid_string))
  end

  def valid_nsid?(%__MODULE__{}), do: true
  def valid_nsid?(_), do: false

  @doc """
  Convert an NSID struct back to its string representation.

  ## Examples

      iex> nsid = %AetherATProtoCore.NSID{authority: "com.example", name: "fooBar"}
      iex> AetherATProtoCore.NSID.nsid_to_string(nsid)
      "com.example.fooBar"

      iex> AetherATProtoCore.NSID.nsid_to_string("com.example.fooBar")
      "com.example.fooBar"
  """
  @spec nsid_to_string(t() | String.t()) :: String.t()
  def nsid_to_string(%__MODULE__{authority: authority, name: name}) do
    "#{authority}.#{name}"
  end

  def nsid_to_string(nsid_string) when is_binary(nsid_string), do: nsid_string

  @doc """
  Extract the authority (domain) from an NSID.

  ## Examples

      iex> AetherATProtoCore.NSID.authority("com.example.fooBar")
      "com.example"

      iex> AetherATProtoCore.NSID.authority("app.bsky.feed.post")
      "app.bsky.feed"

      iex> AetherATProtoCore.NSID.authority(%AetherATProtoCore.NSID{authority: "com.atproto.repo", name: "getRecord"})
      "com.atproto.repo"

      iex> AetherATProtoCore.NSID.authority("invalid")
      {:error, :invalid_nsid}
  """
  @spec authority(String.t() | t()) :: String.t() | {:error, :invalid_nsid}
  def authority(%__MODULE__{authority: authority}), do: authority

  def authority(nsid_string) when is_binary(nsid_string) do
    case parse_nsid(nsid_string) do
      {:ok, %__MODULE__{authority: authority}} -> authority
      {:error, _} -> {:error, :invalid_nsid}
    end
  end

  @doc """
  Extract the name from an NSID.

  ## Examples

      iex> AetherATProtoCore.NSID.name("com.example.fooBar")
      "fooBar"

      iex> AetherATProtoCore.NSID.name("app.bsky.feed.post")
      "post"

      iex> AetherATProtoCore.NSID.name(%AetherATProtoCore.NSID{authority: "com.atproto.repo", name: "getRecord"})
      "getRecord"

      iex> AetherATProtoCore.NSID.name("invalid")
      {:error, :invalid_nsid}
  """
  @spec name(String.t() | t()) :: String.t() | {:error, :invalid_nsid}
  def name(%__MODULE__{name: name}), do: name

  def name(nsid_string) when is_binary(nsid_string) do
    case parse_nsid(nsid_string) do
      {:ok, %__MODULE__{name: name}} -> name
      {:error, _} -> {:error, :invalid_nsid}
    end
  end

  # Private functions

  defp validate_length(nsid) when byte_size(nsid) > @max_total_length, do: {:error, :too_long}
  defp validate_length(_nsid), do: :ok

  defp validate_ascii(nsid) do
    if String.match?(nsid, ~r/^[\x00-\x7F]*$/), do: :ok, else: {:error, :non_ascii}
  end

  defp split_segments(nsid) do
    segments = String.split(nsid, ".")
    {:ok, segments}
  end

  defp validate_segment_count(segments) when length(segments) < 3,
    do: {:error, :too_few_segments}

  defp validate_segment_count(_segments), do: :ok

  defp split_authority_and_name(segments) do
    # Last segment is the name, rest is authority
    {authority_segments, [name]} = Enum.split(segments, -1)
    {:ok, authority_segments, name}
  end

  defp validate_authority_segments(segments) do
    authority = Enum.join(segments, ".")

    with :ok <- validate_authority_length(authority),
         :ok <- validate_authority_segment_count(segments),
         :ok <- validate_first_authority_segment(List.first(segments)),
         :ok <- validate_all_authority_segments(segments) do
      :ok
    end
  end

  defp validate_authority_length(authority) when byte_size(authority) > @max_authority_length,
    do: {:error, :authority_too_long}

  defp validate_authority_length(_authority), do: :ok

  defp validate_authority_segment_count(segments) when length(segments) < 2,
    do: {:error, :authority_too_few_segments}

  defp validate_authority_segment_count(_segments), do: :ok

  defp validate_first_authority_segment(segment) do
    case segment do
      <<first::utf8, _rest::binary>> when first >= ?0 and first <= ?9 ->
        {:error, :authority_starts_with_digit}

      _ ->
        :ok
    end
  end

  defp validate_all_authority_segments(segments) do
    if Enum.all?(segments, &valid_authority_segment?/1) do
      :ok
    else
      {:error, :invalid_authority_segment}
    end
  end

  defp valid_authority_segment?(segment) do
    byte_size(segment) <= @max_segment_length &&
      String.match?(segment, @authority_segment_pattern)
  end

  defp validate_name(name) do
    cond do
      byte_size(name) > @max_segment_length -> {:error, :name_too_long}
      not String.match?(name, @name_pattern) -> {:error, :invalid_name}
      true -> :ok
    end
  end
end
