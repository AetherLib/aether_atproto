defmodule Aether.ATProto.DID do
  @moduledoc """
  Decentralized Identifier (DID) handling for ATProto.

  Supports DID methods commonly used in ATProto networks including:
  - plc: Placeholder DID method
  - web: Web-based DID method
  - key: Key-based DID method
  """

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

  # Regex patterns for validation
  @plc_pattern ~r/^[a-z2-7]{24}$/
  @web_domain_pattern ~r/^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$/
  @web_pattern ~r/^[a-zA-Z0-9.-]+(:[a-zA-Z0-9.-]+)*$/

  @doc """
  Parse a DID string into structured data.

  ## Examples

      iex> Aether.ATProto.DID.parse_did("did:plc:z72i7hdynmk24r6zlsdc6nxd")
      {:ok, %Aether.ATProto.DID{method: "plc", identifier: "z72i7hdynmk24r6zlsdc6nxd"}}

      iex> Aether.ATProto.DID.parse_did("did:web:example.com")
      {:ok, %Aether.ATProto.DID{method: "web", identifier: "example.com"}}

      iex> Aether.ATProto.DID.parse_did("did:key:zQ3shokFTS3brHcDQrn82RUDfCZESWL1ZdCEJwekUDPQiYBme")
      {:ok, %Aether.ATProto.DID{method: "key", identifier: "zQ3shokFTS3brHcDQrn82RUDfCZESWL1ZdCEJwekUDPQiYBme"}}

      iex> Aether.ATProto.DID.parse_did("did:web:example.com:user#fragment")
      {:ok, %Aether.ATProto.DID{method: "web", identifier: "example.com:user", fragment: "fragment"}}
  """
  def parse_did("did:" <> rest) when is_binary(rest) do
    with [method_raw, rest_with_identifier] <- String.split(rest, ":", parts: 2),
         method = String.downcase(method_raw),
         {identifier, fragment, query, params} <- parse_identifier_parts(rest_with_identifier) do
      validate_did(method, identifier, fragment, query, params)
    else
      _ -> {:error, :invalid_format}
    end
  end

  def parse_did(_invalid), do: {:error, :invalid_format}

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

  defp validate_did(method, identifier, fragment, query, params) do
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

  # Allow uppercase PLC DIDs but normalize to lowercase
  defp validate_identifier("plc", identifier) do
    identifier
    |> String.downcase()
    |> validate_pattern(@plc_pattern)
  end

  # For web DIDs, the identifier can be a domain or domain with path segments separated by colons
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

  # Use Crypto.DID module to validate did:key format
  defp validate_identifier("key", identifier) do
    try do
      # This will validate the multikey format and parse it
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

  @doc """
  Parse a DID string, raising an exception on error.

  ## Examples

      iex> Aether.ATProto.DID.parse_did!("did:plc:z72i7hdynmk24r6zlsdc6nxd")
      %Aether.ATProto.DID{method: "plc", identifier: "z72i7hdynmk24r6zlsdc6nxd"}

      iex> Aether.ATProto.DID.parse_did!("invalid")
      ** (Aether.ATProto.DID.ParseError) Invalid DID: invalid_format
  """
  def parse_did!(did_string) when is_binary(did_string) do
    case parse_did(did_string) do
      {:ok, did} -> did
      {:error, reason} -> raise ParseError, "Invalid DID: #{reason}"
    end
  end

  def parse_did!(%__MODULE__{} = did), do: did
  def parse_did!(_other), do: raise(ParseError, "Invalid DID: invalid_format")

  @doc """
  Check if a value is a valid DID.

  ## Examples

      iex> Aether.ATProto.DID.valid_did?("did:plc:z72i7hdynmk24r6zlsdc6nxd")
      true

      iex> Aether.ATProto.DID.valid_did?("invalid")
      false

      iex> Aether.ATProto.DID.valid_did?(%Aether.ATProto.DID{method: "plc", identifier: "test"})
      true
  """
  def valid_did?(did_string) when is_binary(did_string) do
    match?({:ok, _}, parse_did(did_string))
  end

  def valid_did?(%__MODULE__{}), do: true
  def valid_did?(_), do: false

  @doc """
  Convert a DID struct back to its string representation.

  ## Examples

      iex> did = %Aether.ATProto.DID{method: "plc", identifier: "z72i7hdynmk24r6zlsdc6nxd"}
      iex> Aether.ATProto.DID.did_to_string(did)
      "did:plc:z72i7hdynmk24r6zlsdc6nxd"

      iex> did = %Aether.ATProto.DID{method: "web", identifier: "example.com", fragment: "key1"}
      iex> Aether.ATProto.DID.did_to_string(did)
      "did:web:example.com#key1"

      iex> did = %Aether.ATProto.DID{method: "web", identifier: "example.com", query: "version=1", fragment: "key1"}
      iex> Aether.ATProto.DID.did_to_string(did)
      "did:web:example.com?version=1#key1"
  """
  def did_to_string(%__MODULE__{
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

  def did_to_string(did_string) when is_binary(did_string), do: did_string

  defp append_query(string, nil), do: string
  defp append_query(string, query), do: string <> "?" <> query

  defp append_fragment(string, nil), do: string
  defp append_fragment(string, fragment), do: string <> "#" <> fragment

  @doc """
  Extract the method from a DID.

  ## Examples

      iex> Aether.ATProto.DID.did_method("did:plc:z72i7hdynmk24r6zlsdc6nxd")
      "plc"

      iex> Aether.ATProto.DID.did_method("did:web:example.com")
      "web"

      iex> Aether.ATProto.DID.did_method("invalid")
      {:error, :invalid_did}
  """
  def did_method(%__MODULE__{method: method}), do: method

  def did_method(did_string) when is_binary(did_string) do
    case parse_did(did_string) do
      {:ok, %__MODULE__{method: method}} -> method
      {:error, _} -> {:error, :invalid_did}
    end
  end

  @doc """
  Extract the identifier from a DID.

  ## Examples

      iex> Aether.ATProto.DID.did_identifier("did:plc:z72i7hdynmk24r6zlsdc6nxd")
      "z72i7hdynmk24r6zlsdc6nxd"

      iex> Aether.ATProto.DID.did_identifier("invalid")
      {:error, :invalid_did}
  """
  def did_identifier(%__MODULE__{identifier: identifier}), do: identifier

  def did_identifier(did_string) when is_binary(did_string) do
    case parse_did(did_string) do
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

      iex> Aether.ATProto.DID.is_method?("invalid", "plc")
      false
  """
  def is_method?(%__MODULE__{method: method}, expected_method), do: method == expected_method

  def is_method?(did_string, expected_method)
      when is_binary(did_string) and is_binary(expected_method) do
    did_method(did_string) == expected_method
  end

  def is_method?(_, _), do: false

  @doc """
  Get the fragment from a DID.

  ## Examples

      iex> Aether.ATProto.DID.did_fragment("did:web:example.com#key1")
      "key1"

      iex> Aether.ATProto.DID.did_fragment("did:web:example.com")
      nil
  """
  def did_fragment(%__MODULE__{fragment: fragment}), do: fragment

  def did_fragment(did_string) when is_binary(did_string) do
    case parse_did(did_string) do
      {:ok, %__MODULE__{fragment: fragment}} -> fragment
      {:error, _} -> {:error, :invalid_did}
    end
  end

  @doc """
  Get query parameters from a DID.

  ## Examples

      iex> Aether.ATProto.DID.did_params("did:web:example.com?version=1&test=true")
      %{"version" => "1", "test" => "true"}

      iex> Aether.ATProto.DID.did_params("did:web:example.com")
      nil
  """
  def did_params(%__MODULE__{params: params}), do: params

  def did_params(did_string) when is_binary(did_string) do
    case parse_did(did_string) do
      {:ok, %__MODULE__{params: params}} -> params
      {:error, _} -> {:error, :invalid_did}
    end
  end

  @doc """
  Parse and validate a did:key to extract cryptographic information.

  ## Examples

      # Parse a known secp256k1 did:key
      iex> {:ok, parsed} = Aether.ATProto.DID.parse_did_key("did:key:zQ3shokFTS3brHcDQrn82RUDfCZESWL1ZdCEJwekUDPQiYBme")
      iex> parsed.jwt_alg
      "ES256K"
      iex> byte_size(parsed.key_bytes)
      33

      # Parse a known P-256 did:key
      iex> {:ok, parsed} = Aether.ATProto.DID.parse_did_key("did:key:zDnaeRew34GY2i2HL8jdcWrw1HcV9J7W37m2jUiK7sG7xZB2T")
      iex> parsed.jwt_alg
      "ES256"
      iex> byte_size(parsed.key_bytes)
      33

      # Handle non-did:key methods
      iex> Aether.ATProto.DID.parse_did_key("did:web:example.com")
      {:error, :not_did_key}

      # Handle invalid did:key
      iex> Aether.ATProto.DID.parse_did_key("did:key:invalid")
      {:error, %ArgumentError{}}
  """
  """
  def parse_did_key(%__MODULE__{method: "key", identifier: identifier}) do
    try do
      parsed = Crypto.DID.parse_multikey(identifier)
      {:ok, parsed}
    rescue
      error -> {:error, error}
    end
  end

  def parse_did_key(%__MODULE__{method: _other}) do
    {:error, :not_did_key}
  end

  def parse_did_key(did_string) when is_binary(did_string) do
    case parse_did(did_string) do
      {:ok, did} -> parse_did_key(did)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc \"""
  Create a did:key from cryptographic key material.

  ## Examples

      # Using a known P-256 test vector
      iex> key_bytes = <<0x04, 0x6B, 0x9D, 0x3D, 0xAD, 0x2E, 0x1B, 0x8C, 0x1C, 0x05, 0xB1, 0x98, 0x75, 0xB6, 0x65, 0x9F, 0x4D, 0xE2, 0x3C, 0x3B, 0x66, 0x7B, 0xF2, 0x97, 0xBA, 0x9A, 0xA4, 0x77, 0x40, 0x78, 0x71, 0x37, 0xD8, 0x4F, 0xE3, 0x42, 0xE2, 0xFE, 0x1A, 0x7F, 0x9B, 0x8E, 0xE7, 0xEB, 0x4A, 0x7C, 0x0F, 0x9E, 0x16, 0x2B, 0xCE, 0x33, 0x57, 0x6B, 0x31, 0x5E, 0xCE, 0xCB, 0xB6, 0x40, 0x68, 0x37, 0xBF, 0x51, 0xF5>>
      iex> Aether.ATProto.DID.create_did_key("ES256", key_bytes)
      "did:key:zDnaeRew34GY2i2HL8jdcWrw1HcV9J7W37m2jUiK7sG7xZB2T"

      # Using a known secp256k1 test vector
      iex> key_bytes = <<0x04, 0x02, 0x66, 0x7B, 0x8C, 0x34, 0x6E, 0x6D, 0x10, 0xC5, 0x5A, 0xEC, 0x76, 0x8B, 0x5C, 0x8F, 0x3E, 0x9F, 0x5A, 0x72, 0x28, 0x8E, 0x05, 0xAF, 0x1D, 0x7E, 0x17, 0xCA, 0x4E, 0x3C, 0x5C, 0x2F, 0x7D, 0x5F, 0x09, 0x7D, 0xEA, 0x0F, 0x2B, 0x5F, 0x1D, 0x5A, 0x6E, 0x6A, 0x8A, 0x7C, 0x4F, 0x9D, 0x8C, 0x5A, 0x7F, 0x65, 0x6F, 0x5F, 0x6C, 0x7E, 0x5F, 0x7E, 0x7D, 0x4E, 0x5F, 0x6C, 0x7D, 0x6E, 0x6C>>
      iex> Aether.ATProto.DID.create_did_key("ES256K", key_bytes)
      "did:key:zQ3shokFTS3brHcDQrn82RUDfCZESWL1ZdCEJwekUDPQiYBme"
  """

  def create_did_key(jwt_alg, key_bytes) when is_binary(key_bytes) do
    Crypto.DID.format_did_key(jwt_alg, key_bytes)
  end

  @doc """
  Check if a DID method is supported.

  ## Examples

      iex> Aether.ATProto.DID.supported_method?("plc")
      true

      iex> Aether.ATProto.DID.supported_method?("unsupported")
      false
  """
  def supported_method?(method) when is_binary(method) do
    method in @supported_methods
  end

  @doc """
  Get all supported DID methods.

  ## Examples

      iex> Aether.ATProto.DID.supported_methods()
      ["plc", "web", "key"]
  """
  def supported_methods, do: @supported_methods

  @doc """
  Normalize a DID string (convert to lowercase for certain methods).

  ## Examples

      iex> Aether.ATProto.DID.normalize("DID:PLC:Z72I7HDYNMK24R6ZLSDC6NXD")
      "did:plc:z72i7hdynmk24r6zlsdc6nxd"

      iex> Aether.ATProto.DID.normalize("DID:WEB:EXAMPLE.COM?VERSION=1#KEY1")
      "did:web:example.com?VERSION=1#KEY1"

      iex> Aether.ATProto.DID.normalize("DID:KEY:ZQ3SHOKFTS3BRHCDQRN82RUDFCZESWL1ZDCEJWEKUDPQIYBME")
      "did:key:ZQ3SHOKFTS3BRHCDQRN82RUDFCZESWL1ZDCEJWEKUDPQIYBME"
  """
  def normalize(did_string) when is_binary(did_string) do
    case parse_did(did_string) do
      {:ok, did} -> normalize_valid_did(did_string, did)
      {:error, _} -> normalize_invalid_did(did_string)
    end
  end

  defp normalize_valid_did(original, %__MODULE__{method: method, identifier: identifier}) do
    normalized_method = String.downcase(method)

    # Normalize identifier based on method
    normalized_identifier =
      case method do
        "plc" -> String.downcase(identifier)
        "web" -> normalize_web_identifier(identifier)
        # did:key identifiers are case-sensitive
        "key" -> identifier
        _ -> identifier
      end

    ["did", normalized_method, normalized_identifier]
    |> Enum.join(":")
    |> append_query(extract_query(original))
    |> append_fragment(extract_fragment(original))
  end

  defp normalize_web_identifier(identifier) do
    # For web DIDs, only the domain part should be lowercased
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
      # Extract the DID prefix and rest
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

  @doc """
  Extract the web domain from a web DID.

  ## Examples

      iex> Aether.ATProto.DID.web_domain("did:web:example.com:path")
      "example.com"

      iex> Aether.ATProto.DID.web_domain("did:plc:z72i7hdynmk24r6zlsdc6nxd")
      {:error, :not_web_did}
  """
  def web_domain(%__MODULE__{method: "web", identifier: identifier}),
    do: extract_domain(identifier)

  def web_domain(%__MODULE__{}), do: {:error, :not_web_did}

  def web_domain(did_string) when is_binary(did_string) do
    case parse_did(did_string) do
      {:ok, %__MODULE__{method: "web", identifier: identifier}} -> extract_domain(identifier)
      {:ok, %__MODULE__{}} -> {:error, :not_web_did}
      {:error, _} -> {:error, :invalid_did}
    end
  end

  defp extract_domain(identifier) do
    identifier
    |> String.split(":")
    |> List.first()
  end
end
