defmodule Aether.DID do
  @moduledoc """
  Core W3C-compliant DID validation and parsing.

  Provides basic DID syntax validation according to W3C DID Core specification
  without any method-specific logic or ecosystem dependencies.
  """

  defstruct [:method, :id]

  @type t :: %__MODULE__{
          method: String.t(),
          id: String.t()
        }

  @type did_string :: String.t()

  @did_prefix "did:"
  @max_length 2048

  defmodule Error do
    defexception message: "DID validation error"

    @impl true
    def exception(message) when is_binary(message) do
      %Error{message: message}
    end

    def exception(reason) do
      %Error{message: "DID validation error: #{inspect(reason)}"}
    end
  end

  @doc """
  Parse a DID string into structured data with W3C-compliant validation.

  ## Examples

      iex> DID.Core.parse("did:web:example.com")
      {:ok, %DID.Core{method: "web", id: "example.com"}}

      iex> DID.Core.parse("did:invalid🚫:example")
      {:error, "Invalid character at position 11 in DID method name"}

      iex> DID.Core.parse("did:custom:example%20test")
      {:ok, %DID.Core{method: "custom", id: "example%20test"}}
  """
  @spec parse(did_string) :: {:ok, t} | {:error, String.t()}
  def parse(did) when is_binary(did) do
    with :ok <- validate_string(did),
         :ok <- validate_length(did),
         :ok <- validate_prefix(did),
         {:ok, method, id} <- extract_parts(did),
         :ok <- assert_did_method(method, did),
         :ok <- assert_did_msid(id, did) do
      {:ok, %__MODULE__{method: method, id: id}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def parse(_), do: {:error, "DID must be a string"}

  @doc """
  Asserts that the input is a valid DID string per W3C specification.

  Raises `DID.Core.Error` if invalid.

  ## Examples

      iex> DID.Core.assert_did("did:web:example.com")
      :ok

      iex> DID.Core.assert_did("invalid")
      ** (DID.Core.Error) DID requires "did:" prefix
  """
  @spec assert_did(any) :: :ok | no_return
  def assert_did(input) do
    case parse(input) do
      {:ok, _} -> :ok
      {:error, reason} -> raise Error, reason
    end
  end

  @doc """
  Checks if the input is a valid W3C-compliant DID.

  ## Examples

      iex> DID.Core.is_did?("did:web:example.com")
      true

      iex> DID.Core.is_did?("invalid")
      false

      iex> DID.Core.is_did?(123)
      false
  """
  @spec is_did?(any) :: boolean
  def is_did?(input) do
    case parse(input) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  @doc """
  Converts input to a validated DID struct.

  Raises `DID.Core.Error` if invalid.

  ## Examples

      iex> DID.Core.as_did("did:web:example.com")
      %DID.Core{method: "web", id: "example.com"}

      iex> DID.Core.as_did("invalid")
      ** (DID.Core.Error) DID requires "did:" prefix
  """
  @spec as_did(any) :: t | no_return
  def as_did(input) do
    case parse(input) do
      {:ok, did} -> did
      {:error, reason} -> raise Error, reason
    end
  end

  @doc """
  Extracts the method from a DID string.

  Assumes the input is a valid DID.

  ## Examples

      iex> DID.Core.extract_method("did:web:example.com")
      "web"
  """
  @spec extract_method(did_string) :: String.t()
  def extract_method(did) do
    did
    |> String.split(":")
    |> Enum.at(1)
  end

  @doc """
  DID Method-name check function.

  Check if the input is a valid DID method name, at the position between
  `start` (inclusive) and `end` (exclusive).

  ## Examples

      iex> DID.Core.assert_did_method("web", "did:web:example.com")
      :ok

      iex> DID.Core.assert_did_method("web🚫", "did:web🚫:example")
      {:error, "Invalid character at position 3 in DID method name"}
  """
  @spec assert_did_method(String.t(), String.t()) :: :ok | {:error, String.t()}
  def assert_did_method(method, original_did \\ "") when is_binary(method) do
    method
    |> String.to_charlist()
    |> Enum.with_index()
    |> Enum.find_value(:ok, fn {char, index} ->
      unless valid_method_char?(char) do
        {:error,
         "Invalid character at position #{index + String.length(@did_prefix)} in DID method name"}
      end
    end)
  end

  @doc """
  DID Method-specific identifier check function.

  Check if the input is a valid DID method-specific identifier, at the position
  between `start` (inclusive) and `end` (exclusive).

  ## Examples

      iex> DID.Core.assert_did_msid("example.com", "did:web:example.com")
      :ok

      iex> DID.Core.assert_did_msid("example🚫", "did:web:example🚫")
      {:error, "Disallowed character in DID at position 15"}
  """
  @spec assert_did_msid(String.t(), String.t()) :: :ok | {:error, String.t()}
  def assert_did_msid(msid, original_did \\ "") when is_binary(msid) do
    case validate_msid(
           msid,
           original_did,
           String.length(@did_prefix) + String.length(extract_method(original_did)) + 1
         ) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Convert a DID struct back to string representation.

  ## Examples

      iex> did = %DID.Core{method: "web", id: "example.com"}
      iex> DID.Core.to_string(did)
      "did:web:example.com"
  """
  @spec to_string(t) :: did_string
  def to_string(%__MODULE__{method: method, id: id}) do
    "did:#{method}:#{id}"
  end

  # Private implementation

  defp validate_string(input) when is_binary(input), do: :ok
  defp validate_string(_), do: {:error, "DID must be a string"}

  defp validate_length(did) do
    if String.length(did) > @max_length do
      {:error, "DID is too long (#{@max_length} chars max)"}
    else
      :ok
    end
  end

  defp validate_prefix(did) do
    if String.starts_with?(did, @did_prefix) do
      :ok
    else
      {:error, "DID requires \"#{@did_prefix}\" prefix"}
    end
  end

  defp extract_parts(did) do
    parts = String.split(did, ":", parts: 3)

    case parts do
      ["did", method, id] when id != "" -> {:ok, method, id}
      ["did", method, ""] -> {:error, "DID method-specific id must not be empty"}
      ["did", ""] -> {:error, "Empty method name"}
      _ -> {:error, "Missing colon after method name"}
    end
  end

  defp valid_method_char?(char) do
    char in ?a..?z or char in ?0..?9
  end

  defp valid_msid_char?(char) do
    char in ?a..?z or
      char in ?A..?Z or
      char in ?0..?9 or
      char in [?., ?-, ?_, ?:, ?%]
  end

  defp validate_msid("", _original_did, _position),
    do: {:error, "DID method-specific id must not be empty"}

  defp validate_msid(msid, original_did, start_position) do
    msid_chars = String.to_charlist(msid)
    validate_msid_chars(msid_chars, original_did, start_position, 0)
  end

  defp validate_msid_chars([], _original_did, _start_position, _index), do: :ok

  defp validate_msid_chars([?: | t], original_did, start_position, index) do
    if t == [] do
      {:error, "DID cannot end with \":\""}
    else
      validate_msid_chars(t, original_did, start_position, index + 1)
    end
  end

  defp validate_msid_chars([?% | [h1, h2 | t]], original_did, start_position, index) do
    if valid_hex_digit?(h1) and valid_hex_digit?(h2) do
      validate_msid_chars(t, original_did, start_position, index + 3)
    else
      {:error, "Invalid pct-encoded character at position #{start_position + index}"}
    end
  end

  defp validate_msid_chars([?% | _], _original_did, start_position, index) do
    {:error, "Incomplete pct-encoded character at position #{start_position + index}"}
  end

  defp validate_msid_chars([char | t], original_did, start_position, index) do
    if valid_msid_char?(char) do
      validate_msid_chars(t, original_did, start_position, index + 1)
    else
      {:error, "Disallowed character in DID at position #{start_position + index}"}
    end
  end

  defp valid_hex_digit?(char) do
    char in ?0..?9 or char in ?A..?F or char in ?a..?f
  end
end
