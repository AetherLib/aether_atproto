defmodule Aether.ATProto.Lexicon do
  @moduledoc """
  Lexicon schema loading and validation for ATProto.

  Lexicons are ATProto's schema definition language, similar to JSON Schema
  or OpenAPI. They define the structure and constraints for:
  - Record types (e.g., `app.bsky.feed.post`)
  - XRPC queries and procedures
  - Event stream messages

  ## Usage

      # Load a lexicon schema from JSON
      {:ok, lexicon} = Aether.ATProto.Lexicon.load_schema(json_string)

      # Validate data against a schema
      data = %{
        "text" => "Hello, ATProto!",
        "createdAt" => "2024-01-15T12:00:00Z"
      }

      case Aether.ATProto.Lexicon.validate(lexicon, data) do
        {:ok, validated_data} -> # Data is valid
        {:error, errors} -> # Validation failed
      end

  ## Type System

  Lexicons support the following types:

  **Primitives:**
  - `null` - Null value
  - `boolean` - True or false
  - `integer` - Whole numbers
  - `string` - Text strings
  - `bytes` - Binary data (base64 encoded)
  - `cid-link` - Content identifier link
  - `blob` - Binary large object reference

  **Containers:**
  - `object` - Key-value map with defined properties
  - `array` - Ordered list of items

  **Meta:**
  - `ref` - Reference to another schema
  - `union` - One of multiple types
  - `unknown` - Any value (no validation)

  ## Constraints

  Types can have various constraints:
  - `minLength`/`maxLength` - String/array length bounds
  - `minimum`/`maximum` - Numeric value bounds
  - `enum` - Allowed values list
  - `required` - Required object properties
  - `const` - Fixed value
  - `default` - Default value if not provided

  ## Example

      # Simple record schema
      schema = %{
        "type" => "object",
        "properties" => %{
          "text" => %{
            "type" => "string",
            "maxLength" => 300
          },
          "createdAt" => %{
            "type" => "string",
            "format" => "datetime"
          }
        },
        "required" => ["text", "createdAt"]
      }

      lexicon = %Aether.ATProto.Lexicon{
        nsid: "app.bsky.feed.post",
        definition: schema
      }

      # Validate data
      Aether.ATProto.Lexicon.validate(lexicon, %{
        "text" => "Hello!",
        "createdAt" => "2024-01-15T12:00:00Z"
      })
      #=> {:ok, %{"text" => "Hello!", "createdAt" => "2024-01-15T12:00:00Z"}}
  """

  defstruct [:nsid, :version, :type, :definition]

  @type t :: %__MODULE__{
          nsid: String.t() | nil,
          version: integer() | nil,
          type: String.t() | nil,
          definition: map()
        }

  @type validation_error :: %{
          path: [String.t()],
          message: String.t()
        }

  @doc """
  Load a lexicon schema from a JSON string.

  ## Examples

      iex> json = ~s({"lexicon": 1, "id": "app.bsky.feed.post", "defs": {"main": {"type": "record"}}})
      iex> {:ok, lexicon} = Aether.ATProto.Lexicon.load_schema(json)
      iex> lexicon.nsid
      "app.bsky.feed.post"
  """
  @spec load_schema(String.t()) :: {:ok, t()} | {:error, term()}
  def load_schema(json_string) when is_binary(json_string) do
    case Jason.decode(json_string) do
      {:ok, schema_map} -> parse_schema(schema_map)
      {:error, reason} -> {:error, {:json_parse_error, reason}}
    end
  end

  @doc """
  Load a lexicon schema from a map.

  ## Examples

      iex> schema = %{"lexicon" => 1, "id" => "com.example.post", "defs" => %{"main" => %{"type" => "record"}}}
      iex> {:ok, lexicon} = Aether.ATProto.Lexicon.load_schema_map(schema)
      iex> lexicon.nsid
      "com.example.post"
  """
  @spec load_schema_map(map()) :: {:ok, t()} | {:error, term()}
  def load_schema_map(schema_map) when is_map(schema_map) do
    parse_schema(schema_map)
  end

  @doc """
  Validate data against a lexicon schema.

  Returns `{:ok, data}` if validation succeeds, or `{:error, errors}` if it fails.
  Errors include the path to the invalid field and a description of the issue.

  ## Examples

      iex> lexicon = %Aether.ATProto.Lexicon{
      ...>   definition: %{
      ...>     "type" => "object",
      ...>     "properties" => %{
      ...>       "text" => %{"type" => "string", "maxLength" => 10}
      ...>     },
      ...>     "required" => ["text"]
      ...>   }
      ...> }
      iex> Aether.ATProto.Lexicon.validate(lexicon, %{"text" => "Hello!"})
      {:ok, %{"text" => "Hello!"}}

      iex> lexicon = %Aether.ATProto.Lexicon{
      ...>   definition: %{
      ...>     "type" => "object",
      ...>     "properties" => %{
      ...>       "text" => %{"type" => "string", "maxLength" => 3}
      ...>     },
      ...>     "required" => ["text"]
      ...>   }
      ...> }
      iex> Aether.ATProto.Lexicon.validate(lexicon, %{"text" => "Hello!"})
      {:error, [%{path: ["text"], message: "string length 6 exceeds maximum 3"}]}
  """
  @spec validate(t(), term()) :: {:ok, term()} | {:error, [validation_error()]}
  def validate(%__MODULE__{definition: definition}, data) do
    case validate_value(data, definition, []) do
      {:ok, _} -> {:ok, data}
      {:error, errors} -> {:error, errors}
    end
  end

  # Private functions

  defp parse_schema(%{"lexicon" => 1, "id" => nsid, "defs" => defs}) do
    # Get main definition or first definition
    main_def = defs["main"] || Map.values(defs) |> List.first()

    {:ok,
     %__MODULE__{
       nsid: nsid,
       version: 1,
       type: main_def["type"],
       definition: main_def
     }}
  end

  defp parse_schema(%{"type" => _type} = schema) do
    # Simple schema without full lexicon wrapper
    {:ok, %__MODULE__{definition: schema}}
  end

  defp parse_schema(_), do: {:error, :invalid_schema}

  # Validation implementation

  defp validate_value(value, %{"type" => type} = schema, path) do
    validate_type(value, type, schema, path)
  end

  defp validate_value(_value, %{"const" => const_value}, _path) do
    {:ok, const_value}
  end

  defp validate_value(_value, _schema, _path) do
    # Unknown schema type, accept any value
    {:ok, :valid}
  end

  # Type validation

  defp validate_type(nil, "null", _schema, _path), do: {:ok, :valid}

  defp validate_type(value, "boolean", _schema, _path) when is_boolean(value),
    do: {:ok, :valid}

  defp validate_type(value, "boolean", _schema, path) when not is_boolean(value) do
    {:error, [error(path, "expected boolean, got #{inspect(value)}")]}
  end

  defp validate_type(value, "integer", schema, path) when is_integer(value) do
    with :ok <- validate_minimum(value, schema["minimum"], path),
         :ok <- validate_maximum(value, schema["maximum"], path),
         :ok <- validate_enum(value, schema["enum"], path) do
      {:ok, :valid}
    end
  end

  defp validate_type(value, "integer", _schema, path) when not is_integer(value) do
    {:error, [error(path, "expected integer, got #{inspect(value)}")]}
  end

  defp validate_type(value, "string", schema, path) when is_binary(value) do
    with :ok <- validate_min_length(value, schema["minLength"], path),
         :ok <- validate_max_length(value, schema["maxLength"], path),
         :ok <- validate_max_graphemes(value, schema["maxGraphemes"], path),
         :ok <- validate_enum(value, schema["enum"], path) do
      {:ok, :valid}
    end
  end

  defp validate_type(value, "string", _schema, path) when not is_binary(value) do
    {:error, [error(path, "expected string, got #{inspect(value)}")]}
  end

  defp validate_type(value, "object", schema, path) when is_map(value) do
    with :ok <- validate_required_properties(value, schema["required"], path),
         {:ok, _} <- validate_properties(value, schema["properties"], path) do
      {:ok, :valid}
    end
  end

  defp validate_type(value, "object", _schema, path) when not is_map(value) do
    {:error, [error(path, "expected object, got #{inspect(value)}")]}
  end

  defp validate_type(value, "array", schema, path) when is_list(value) do
    with :ok <- validate_array_length(value, schema, path),
         {:ok, _} <- validate_array_items(value, schema["items"], path) do
      {:ok, :valid}
    end
  end

  defp validate_type(value, "array", _schema, path) when not is_list(value) do
    {:error, [error(path, "expected array, got #{inspect(value)}")]}
  end

  defp validate_type(_value, "unknown", _schema, _path) do
    # Unknown type accepts anything
    {:ok, :valid}
  end

  defp validate_type(_value, "bytes", _schema, _path) do
    # TODO: Validate base64 encoded bytes
    {:ok, :valid}
  end

  defp validate_type(_value, "cid-link", _schema, _path) do
    # TODO: Validate CID format
    {:ok, :valid}
  end

  defp validate_type(_value, "blob", _schema, _path) do
    # TODO: Validate blob reference format
    {:ok, :valid}
  end

  defp validate_type(value, type, _schema, path) do
    {:error, [error(path, "unknown type: #{type} for value #{inspect(value)}")]}
  end

  # Constraint validation

  defp validate_minimum(_value, nil, _path), do: :ok

  defp validate_minimum(value, minimum, _path) when value >= minimum, do: :ok

  defp validate_minimum(value, minimum, path) do
    {:error, [error(path, "value #{value} is less than minimum #{minimum}")]}
  end

  defp validate_maximum(_value, nil, _path), do: :ok

  defp validate_maximum(value, maximum, _path) when value <= maximum, do: :ok

  defp validate_maximum(value, maximum, path) do
    {:error, [error(path, "value #{value} exceeds maximum #{maximum}")]}
  end

  defp validate_min_length(_value, nil, _path), do: :ok

  defp validate_min_length(value, min_length, path) do
    actual_length = String.length(value)

    if actual_length >= min_length do
      :ok
    else
      {:error, [error(path, "string length #{actual_length} is less than minimum #{min_length}")]}
    end
  end

  defp validate_max_length(_value, nil, _path), do: :ok

  defp validate_max_length(value, max_length, path) do
    actual_length = String.length(value)

    if actual_length <= max_length do
      :ok
    else
      {:error, [error(path, "string length #{actual_length} exceeds maximum #{max_length}")]}
    end
  end

  defp validate_max_graphemes(_value, nil, _path), do: :ok

  defp validate_max_graphemes(value, max_graphemes, path) do
    grapheme_count = String.length(value)

    if grapheme_count <= max_graphemes do
      :ok
    else
      {:error,
       [error(path, "string graphemes #{grapheme_count} exceeds maximum #{max_graphemes}")]}
    end
  end

  defp validate_enum(_value, nil, _path), do: :ok

  defp validate_enum(value, enum, path) when is_list(enum) do
    if value in enum do
      :ok
    else
      {:error, [error(path, "value #{inspect(value)} not in enum #{inspect(enum)}")]}
    end
  end

  # Object validation

  defp validate_required_properties(_object, nil, _path), do: :ok

  defp validate_required_properties(object, required, path) when is_list(required) do
    missing =
      Enum.filter(required, fn prop ->
        not Map.has_key?(object, prop)
      end)

    if Enum.empty?(missing) do
      :ok
    else
      errors =
        Enum.map(missing, fn prop ->
          error(path ++ [prop], "required property missing")
        end)

      {:error, errors}
    end
  end

  defp validate_properties(_object, nil, _path), do: {:ok, :valid}

  defp validate_properties(object, properties, path) when is_map(properties) do
    errors =
      Enum.flat_map(properties, fn {prop_name, prop_schema} ->
        case Map.fetch(object, prop_name) do
          {:ok, prop_value} ->
            case validate_value(prop_value, prop_schema, path ++ [prop_name]) do
              {:ok, _} -> []
              {:error, errs} -> errs
            end

          :error ->
            []
        end
      end)

    if Enum.empty?(errors) do
      {:ok, :valid}
    else
      {:error, errors}
    end
  end

  # Array validation

  defp validate_array_length(array, schema, path) do
    length = length(array)

    with :ok <- validate_array_min_length(length, schema["minLength"], path),
         :ok <- validate_array_max_length(length, schema["maxLength"], path) do
      :ok
    end
  end

  defp validate_array_min_length(_length, nil, _path), do: :ok

  defp validate_array_min_length(length, min_length, _path) when length >= min_length, do: :ok

  defp validate_array_min_length(length, min_length, path) do
    {:error, [error(path, "array length #{length} is less than minimum #{min_length}")]}
  end

  defp validate_array_max_length(_length, nil, _path), do: :ok

  defp validate_array_max_length(length, max_length, _path) when length <= max_length, do: :ok

  defp validate_array_max_length(length, max_length, path) do
    {:error, [error(path, "array length #{length} exceeds maximum #{max_length}")]}
  end

  defp validate_array_items(_array, nil, _path), do: {:ok, :valid}

  defp validate_array_items(array, items_schema, path) do
    errors =
      array
      |> Enum.with_index()
      |> Enum.flat_map(fn {item, index} ->
        case validate_value(item, items_schema, path ++ ["[#{index}]"]) do
          {:ok, _} -> []
          {:error, errs} -> errs
        end
      end)

    if Enum.empty?(errors) do
      {:ok, :valid}
    else
      {:error, errors}
    end
  end

  # Error helpers

  defp error(path, message) do
    %{path: path, message: message}
  end
end
