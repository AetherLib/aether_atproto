defmodule Aether.ATProto.DID do
  @moduledoc """
  ATProto-specific DID handling built on W3C-compliant core.

  Supports DID methods commonly used in ATProto networks including:
  - plc: Placeholder DID method
  - web: Web-based DID method
  - key: Key-based DID method

  Extends core DID validation with ATProto ecosystem features.
  """

  alias Aether.DID
  alias Aether.Crypto

  defstruct [:method, :identifier, :fragment, :query, :params]

  @type t :: %__MODULE__{
          method: String.t(),
          identifier: String.t(),
          fragment: String.t() | nil,
          query: String.t() | nil,
          params: map() | nil
        }

  defmodule ParseError do
    defexception message: "Invalid DID format"
  end

  # Supported DID methods in ATProto
  @supported_methods ["plc", "web", "key"]

  # Regex patterns for ATProto-specific validation
  @plc_pattern ~r/^[a-z2-7]{24}$/
  @web_domain_pattern ~r/^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/
  @web_pattern ~r/^[a-zA-Z0-9.-]+(:[a-zA-Z0-9.-]+)*$/

  @doc """
  Parse a DID string with ATProto extensions (fragments, queries, method-specific validation).

  ## Examples

      iex> Aether.ATProto.DID.parse("did:plc:z72i7hdynmk24r6zlsdc6nxd")
      {:ok, %Aether.ATProto.DID{method: "plc", identifier: "z72i7hdynmk24r6zlsdc6nxd"}}

      iex> Aether.ATProto.DID.parse("did:web:example.com#fragment")
      {:ok, %Aether.ATProto.DID{method: "web", identifier: "example.com", fragment: "fragment"}}

      iex> Aether.ATProto.DID.parse("did:invalid:example")
      {:error, :unsupported_method}
  """
  @spec parse(String.t()) :: {:ok, t} | {:error, atom() | String.t()}
  def parse("did:" <> rest) when is_binary(rest) do
    with [method_raw, rest_with_identifier] <- String.split(rest, ":", parts: 2),
         method = String.downcase(method_raw),
         {:ok, core_did} <-
           DID.parse("did:" <> method_raw <> ":" <> extract_base_identifier(rest_with_identifier)),
         {identifier, fragment, query, params} <- parse_identifier_parts(rest_with_identifier) do
      validate_atproto_did(method, identifier, fragment, query, params, core_did)
    else
      {:error, reason} when is_binary(reason) -> {:error, reason}
      _ -> {:error, :invalid_format}
    end
  end

  def parse(_invalid), do: {:error, :invalid_format}

  @doc """
  Parse a DID string, raising an exception on error.

  ## Examples

      iex> Aether.ATProto.DID.parse!("did:plc:z72i7hdynmk24r6zlsdc6nxd")
      %Aether.ATProto.DID{method: "plc", identifier: "z72i7hdynmk24r6zlsdc6nxd"}

      iex> Aether.ATProto.DID.parse!("invalid")
      ** (Aether.ATProto.DID.ParseError) Invalid DID: invalid_format
  """
  @spec parse!(any) :: t | no_return
  def parse!(did_string) when is_binary(did_string) do
    case parse(did_string) do
      {:ok, did} -> did
      {:error, reason} -> raise ParseError, "Invalid DID: #{reason}"
    end
  end

  def parse!(%__MODULE__{} = did), do: did
  def parse!(_other), do: raise(ParseError, "Invalid DID: invalid_format")

  @doc """
  Check if a value is a valid ATProto DID.

  ## Examples

      iex> Aether.ATProto.DID.valid?("did:plc:z72i7hdynmk24r6zlsdc6nxd")
      true

      iex> Aether.ATProto.DID.valid?("did:invalid:example")
      false

      iex> Aether.ATProto.DID.valid?(%Aether.ATProto.DID{method: "plc", identifier: "test"})
      true
  """
  @spec valid?(any) :: boolean
  def valid?(did_string) when is_binary(did_string) do
    match?({:ok, _}, parse(did_string))
  end

  def valid?(%__MODULE__{}), do: true
  def valid?(_), do: false

  @doc """
  Convert a DID struct back to its string representation.

  ## Examples

      iex> did = %Aether.ATProto.DID{method: "plc", identifier: "z72i7hdynmk24r6zlsdc6nxd"}
      iex> Aether.ATProto.DID.to_string(did)
      "did:plc:z72i7hdynmk24r6zlsdc6nxd"

      iex> did = %Aether.ATProto.DID{method: "web", identifier: "example.com", fragment: "key1"}
      iex> Aether.ATProto.DID.to_string(did)
      "did:web:example.com#key1"
  """
  @spec to_string(t) :: String.t()
  def to_string(%__MODULE__{
        method: method,
        identifier: identifier,
        query: query,
        fragment: fragment
      }) do
    ["did", method, identifier]
    |> Enum.join(":")
    |> append_query(query)
    |> append_fragment(fragment)
  end

  def to_string(did_string) when is_binary(did_string), do: did_string

  @doc """
  Extract the method from a DID.

  ## Examples

      iex> Aether.ATProto.DID.method("did:plc:z72i7hdynmk24r6zlsdc6nxd")
      "plc"

      iex> Aether.ATProto.DID.method("did:web:example.com")
      "web"
  """
  @spec method(t | String.t()) :: String.t() | {:error, atom}
  def method(%__MODULE__{method: method}), do: method

  def method(did_string) when is_binary(did_string) do
    case parse(did_string) do
      {:ok, %__MODULE__{method: method}} -> method
      {:error, _} -> {:error, :invalid_did}
    end
  end

  @doc """
  Extract the identifier from a DID.

  ## Examples

      iex> Aether.ATProto.DID.identifier("did:plc:z72i7hdynmk24r6zlsdc6nxd")
      "z72i7hdynmk24r6zlsdc6nxd"

      iex> Aether.ATProto.DID.identifier("invalid")
      {:error, :invalid_did}
  """
  @spec identifier(t | String.t()) :: String.t() | {:error, atom}
  def identifier(%__MODULE__{identifier: identifier}), do: identifier

  def identifier(did_string) when is_binary(did_string) do
    case parse(did_string) do
      {:ok, %__MODULE__{identifier: identifier}} -> identifier
      {:error, _} -> {:error, :invalid_did}
    end
  end

  @doc """
  Check if a DID uses a specific method.

  ## Examples

      iex> Aether.ATProto.DID.is_method?("did:plc:z72i7hdynmk24r6zlsdc6nxd", "plc")
      true

      iex> Aether.ATProto.DID.is_method?("did:web:example.com", "plc")
      false
  """
  @spec is_method?(t | String.t(), String.t()) :: boolean
  def is_method?(%__MODULE__{method: method}, expected_method), do: method == expected_method

  def is_method?(did_string, expected_method)
      when is_binary(did_string) and is_binary(expected_method) do
    method(did_string) == expected_method
  end

  def is_method?(_, _), do: false

  @doc """
  Get the fragment from a DID.

  ## Examples

      iex> Aether.ATProto.DID.fragment("did:web:example.com#key1")
      "key1"

      iex> Aether.ATProto.DID.fragment("did:web:example.com")
      nil
  """
  @spec fragment(t | String.t()) :: String.t() | nil | {:error, atom}
  def fragment(%__MODULE__{fragment: fragment}), do: fragment

  def fragment(did_string) when is_binary(did_string) do
    case parse(did_string) do
      {:ok, %__MODULE__{fragment: fragment}} -> fragment
      {:error, _} -> {:error, :invalid_did}
    end
  end

  @doc """
  Get query parameters from a DID.

  ## Examples

      iex> Aether.ATProto.DID.params("did:web:example.com?version=1&test=true")
      %{"version" => "1", "test" => "true"}

      iex> Aether.ATProto.DID.params("did:web:example.com")
      nil
  """
  @spec params(t | String.t()) :: map() | nil | {:error, atom}
  def params(%__MODULE__{params: params}), do: params

  def params(did_string) when is_binary(did_string) do
    case parse(did_string) do
      {:ok, %__MODULE__{params: params}} -> params
      {:error, _} -> {:error, :invalid_did}
    end
  end

  @doc """
  Parse and validate a did:key to extract cryptographic information.

  ## Examples

      iex> {:ok, key_info} = Aether.ATProto.DID.parse_key("did:key:zQ3shokFTS3brHcDQrn82RUDfCZESWL1ZdCEJwekUDPQiYBme")
      iex> key_info.jwt_alg
      "ES256K"
  """
  @spec parse_key(t | String.t()) :: {:ok, map()} | {:error, atom}
  def parse_key(%__MODULE__{method: "key", identifier: identifier}) do
    try do
      parsed = Crypto.DID.parse_multikey(identifier)
      {:ok, parsed}
    rescue
      _error -> {:error, :invalid_key}
    end
  end

  def parse_key(%__MODULE__{method: _other}), do: {:error, :not_did_key}

  def parse_key(did_string) when is_binary(did_string) do
    case parse(did_string) do
      {:ok, did} -> parse_key(did)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Create a did:key from cryptographic key material.

  ## Examples

      iex> key_bytes = <<4, 14, 118, 218, 112, 253, 171, 169, 228, 134, 180, 102, 118, 151, 125, 68, 163, 148, 159, 76, 59, 236, 38, 108, 120, 157, 102, 219, 111, 171, 86, 59, 140, 252, 210, 171, 15, 194, 176, 116, 82, 82, 255, 93, 7, 114, 23, 20, 196, 157, 123, 190, 163, 7, 155, 162, 90, 242, 83, 121, 81, 128, 102, 172, 139>>
      iex> did_key = Aether.ATProto.DID.create_key("ES256", key_bytes)
      iex> String.starts_with?(did_key, "did:key:z")
      true
  """
  @spec create_key(String.t(), binary()) :: String.t()
  def create_key(jwt_alg, key_bytes) when is_binary(key_bytes) do
    Crypto.DID.format_did_key(jwt_alg, key_bytes)
  end

  @doc """
  Check if a DID method is supported by ATProto.

  ## Examples

      iex> Aether.ATProto.DID.supported_method?("plc")
      true

      iex> Aether.ATProto.DID.supported_method?("unsupported")
      false
  """
  @spec supported_method?(String.t()) :: boolean
  def supported_method?(method) when is_binary(method) do
    method in @supported_methods
  end

  @doc """
  Get all supported DID methods.

  ## Examples

      iex> Aether.ATProto.DID.supported_methods()
      ["plc", "web", "key"]
  """
  @spec supported_methods() :: list(String.t())
  def supported_methods, do: @supported_methods

  @doc """
  Normalize a DID string (convert to lowercase for certain methods).

  ## Examples

      iex> Aether.ATProto.DID.normalize("DID:PLC:Z72I7HDYNMK24R6ZLSDC6NXD")
      "did:plc:z72i7hdynmk24r6zlsdc6nxd"

      iex> Aether.ATProto.DID.normalize("DID:WEB:EXAMPLE.COM?VERSION=1#KEY1")
      "did:web:example.com?VERSION=1#KEY1"
  """
  @spec normalize(String.t()) :: String.t()
  def normalize(did_string) when is_binary(did_string) do
    case parse(did_string) do
      {:ok, did} -> normalize_valid_did(did_string, did)
      {:error, _} -> normalize_invalid_did(did_string)
    end
  end

  @doc """
  Extract the web domain from a web DID.

  ## Examples

      iex> Aether.ATProto.DID.web_domain("did:web:example.com:path")
      "example.com"

      iex> Aether.ATProto.DID.web_domain("did:plc:z72i7hdynmk24r6zlsdc6nxd")
      {:error, :not_web_did}
  """
  @spec web_domain(t | String.t()) :: String.t() | {:error, atom}
  def web_domain(%__MODULE__{method: "web", identifier: identifier}),
    do: extract_domain(identifier)

  def web_domain(%__MODULE__{}), do: {:error, :not_web_did}

  def web_domain(did_string) when is_binary(did_string) do
    case parse(did_string) do
      {:ok, %__MODULE__{method: "web", identifier: identifier}} -> extract_domain(identifier)
      {:ok, %__MODULE__{}} -> {:error, :not_web_did}
      {:error, _} -> {:error, :invalid_did}
    end
  end

  # Private implementation

  defp extract_base_identifier(rest_with_identifier) do
    rest_with_identifier
    |> String.split(["#", "?"])
    |> List.first()
  end

  defp parse_identifier_parts(rest) do
    {identifier_with_params, fragment} = split_fragment(rest)
    {identifier, query} = split_query(identifier_with_params)
    params = parse_query_params(query)
    {identifier, fragment, query, params}
  end

  defp split_fragment(string) do
    case String.split(string, "#", parts: 2) do
      [id, frag] -> {id, frag}
      [id] -> {id, nil}
    end
  end

  defp split_query(string) do
    case String.split(string, "?", parts: 2) do
      [id, q] -> {id, q}
      [id] -> {id, nil}
    end
  end

  defp parse_query_params(nil), do: nil

  defp parse_query_params(query_string) do
    query_string
    |> String.split("&")
    |> Map.new(fn
      pair ->
        case String.split(pair, "=", parts: 2) do
          [key, value] -> {key, value}
          [key] -> {key, true}
        end
    end)
  end

  defp validate_atproto_did(method, identifier, fragment, query, params, _core_did) do
    with :ok <- validate_method(method),
         :ok <- validate_identifier(method, identifier) do
      {:ok,
       %__MODULE__{
         method: method,
         identifier: identifier,
         fragment: fragment,
         query: query,
         params: params
       }}
    end
  end

  defp validate_method(method) when method in @supported_methods, do: :ok
  defp validate_method(_method), do: {:error, :unsupported_method}

  defp validate_identifier("plc", identifier) do
    identifier
    |> String.downcase()
    |> validate_pattern(@plc_pattern)
  end

  defp validate_identifier("web", identifier) do
    with [domain | _] <- String.split(identifier, ":"),
         true <- String.match?(identifier, @web_pattern),
         true <- String.match?(domain, @web_domain_pattern),
         true <- String.length(domain) <= 253 do
      :ok
    else
      _ -> {:error, :invalid_identifier}
    end
  end

  defp validate_identifier("key", identifier) do
    try do
      Crypto.DID.parse_multikey(identifier)
      :ok
    rescue
      _ -> {:error, :invalid_identifier}
    end
  end

  defp validate_identifier(_, _), do: {:error, :invalid_method}

  defp validate_pattern(string, pattern) do
    if String.match?(string, pattern), do: :ok, else: {:error, :invalid_identifier}
  end

  defp append_query(string, nil), do: string
  defp append_query(string, query), do: string <> "?" <> query

  defp append_fragment(string, nil), do: string
  defp append_fragment(string, fragment), do: string <> "#" <> fragment

  defp normalize_valid_did(original, %__MODULE__{method: method, identifier: identifier}) do
    normalized_method = String.downcase(method)

    normalized_identifier =
      case method do
        "plc" -> String.downcase(identifier)
        "web" -> normalize_web_identifier(identifier)
        "key" -> identifier
        _ -> identifier
      end

    ["did", normalized_method, normalized_identifier]
    |> Enum.join(":")
    |> append_query(extract_query(original))
    |> append_fragment(extract_fragment(original))
  end

  defp normalize_web_identifier(identifier) do
    parts = String.split(identifier, ":")
    [domain | path_parts] = parts
    normalized_domain = String.downcase(domain)

    case path_parts do
      [] -> normalized_domain
      _ -> [normalized_domain | path_parts] |> Enum.join(":")
    end
  end

  defp normalize_invalid_did(did_string) do
    if String.starts_with?(String.downcase(did_string), "did:") do
      <<"did:", rest::binary>> =
        String.downcase(String.slice(did_string, 0..3)) <> String.slice(did_string, 4..-1//1)

      case String.split(rest, ["?", "#"], parts: 2) do
        [method_and_id, rest_parts] ->
          separator = if String.contains?(did_string, "?"), do: "?", else: "#"
          build_normalized_did(String.downcase(method_and_id), separator, rest_parts)

        [method_and_id] ->
          build_normalized_did(String.downcase(method_and_id), nil, nil)
      end
    else
      did_string
    end
  end

  defp build_normalized_did(method_and_id, separator, rest_parts) do
    case String.split(method_and_id, ":", parts: 2) do
      [method, identifier] when not is_nil(separator) ->
        "did:#{method}:#{identifier}#{separator}#{rest_parts}"

      [method, identifier] ->
        "did:#{method}:#{identifier}"

      _ ->
        if separator,
          do: "did:#{method_and_id}#{separator}#{rest_parts}",
          else: "did:#{method_and_id}"
    end
  end

  defp extract_query(did_string) do
    with [_, rest] <- String.split(did_string, "?", parts: 2),
         [query | _] <- String.split(rest, "#", parts: 2) do
      query
    else
      _ -> nil
    end
  end

  defp extract_fragment(did_string) do
    case String.split(did_string, "#", parts: 2) do
      [_, fragment] -> fragment
      _ -> nil
    end
  end

  defp extract_domain(identifier) do
    identifier
    |> String.split(":")
    |> List.first()
  end
end
