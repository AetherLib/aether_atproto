defmodule Aether.ATProto.LexiconTest do
  use ExUnit.Case, async: true
  doctest Aether.ATProto.Lexicon

  alias Aether.ATProto.Lexicon

  describe "load_schema/1" do
    test "loads a full lexicon schema from JSON" do
      json = ~s({
        "lexicon": 1,
        "id": "app.bsky.feed.post",
        "defs": {
          "main": {
            "type": "record",
            "key": "tid",
            "record": {
              "type": "object",
              "properties": {
                "text": {"type": "string", "maxLength": 300}
              }
            }
          }
        }
      })

      assert {:ok, lexicon} = Lexicon.load_schema(json)
      assert lexicon.nsid == "app.bsky.feed.post"
      assert lexicon.version == 1
      assert lexicon.type == "record"
    end

    test "loads a simple schema from JSON" do
      json = ~s({
        "type": "object",
        "properties": {
          "text": {"type": "string"}
        }
      })

      assert {:ok, lexicon} = Lexicon.load_schema(json)
      assert lexicon.definition["type"] == "object"
    end

    test "returns error for invalid JSON" do
      assert {:error, {:json_parse_error, _}} = Lexicon.load_schema("invalid json")
    end
  end

  describe "load_schema_map/1" do
    test "loads schema from map" do
      schema = %{
        "lexicon" => 1,
        "id" => "com.example.record",
        "defs" => %{
          "main" => %{"type" => "record"}
        }
      }

      assert {:ok, lexicon} = Lexicon.load_schema_map(schema)
      assert lexicon.nsid == "com.example.record"
    end

    test "loads simple schema from map" do
      schema = %{"type" => "string", "maxLength" => 100}

      assert {:ok, lexicon} = Lexicon.load_schema_map(schema)
      assert lexicon.definition["type"] == "string"
    end
  end

  describe "validate/2 - primitives" do
    test "validates null" do
      lexicon = %Lexicon{definition: %{"type" => "null"}}
      assert {:ok, nil} = Lexicon.validate(lexicon, nil)
    end

    test "validates boolean" do
      lexicon = %Lexicon{definition: %{"type" => "boolean"}}
      assert {:ok, true} = Lexicon.validate(lexicon, true)
      assert {:ok, false} = Lexicon.validate(lexicon, false)
    end

    test "rejects non-boolean for boolean type" do
      lexicon = %Lexicon{definition: %{"type" => "boolean"}}
      assert {:error, [%{path: [], message: msg}]} = Lexicon.validate(lexicon, "not a boolean")
      assert msg =~ "expected boolean"
    end

    test "validates integer" do
      lexicon = %Lexicon{definition: %{"type" => "integer"}}
      assert {:ok, 42} = Lexicon.validate(lexicon, 42)
      assert {:ok, -10} = Lexicon.validate(lexicon, -10)
      assert {:ok, 0} = Lexicon.validate(lexicon, 0)
    end

    test "rejects non-integer for integer type" do
      lexicon = %Lexicon{definition: %{"type" => "integer"}}
      assert {:error, [%{path: [], message: msg}]} = Lexicon.validate(lexicon, "not a number")
      assert msg =~ "expected integer"
    end

    test "validates string" do
      lexicon = %Lexicon{definition: %{"type" => "string"}}
      assert {:ok, "hello"} = Lexicon.validate(lexicon, "hello")
      assert {:ok, ""} = Lexicon.validate(lexicon, "")
    end

    test "rejects non-string for string type" do
      lexicon = %Lexicon{definition: %{"type" => "string"}}
      assert {:error, [%{path: [], message: msg}]} = Lexicon.validate(lexicon, 123)
      assert msg =~ "expected string"
    end
  end

  describe "validate/2 - integer constraints" do
    test "validates minimum" do
      lexicon = %Lexicon{definition: %{"type" => "integer", "minimum" => 0}}
      assert {:ok, 0} = Lexicon.validate(lexicon, 0)
      assert {:ok, 10} = Lexicon.validate(lexicon, 10)

      assert {:error, [%{message: msg}]} = Lexicon.validate(lexicon, -1)
      assert msg =~ "less than minimum"
    end

    test "validates maximum" do
      lexicon = %Lexicon{definition: %{"type" => "integer", "maximum" => 100}}
      assert {:ok, 100} = Lexicon.validate(lexicon, 100)
      assert {:ok, 50} = Lexicon.validate(lexicon, 50)

      assert {:error, [%{message: msg}]} = Lexicon.validate(lexicon, 101)
      assert msg =~ "exceeds maximum"
    end

    test "validates enum" do
      lexicon = %Lexicon{definition: %{"type" => "integer", "enum" => [1, 2, 3]}}
      assert {:ok, 1} = Lexicon.validate(lexicon, 1)
      assert {:ok, 2} = Lexicon.validate(lexicon, 2)

      assert {:error, [%{message: msg}]} = Lexicon.validate(lexicon, 4)
      assert msg =~ "not in enum"
    end
  end

  describe "validate/2 - string constraints" do
    test "validates minLength" do
      lexicon = %Lexicon{definition: %{"type" => "string", "minLength" => 3}}
      assert {:ok, "abc"} = Lexicon.validate(lexicon, "abc")
      assert {:ok, "abcd"} = Lexicon.validate(lexicon, "abcd")

      assert {:error, [%{message: msg}]} = Lexicon.validate(lexicon, "ab")
      assert msg =~ "less than minimum"
    end

    test "validates maxLength" do
      lexicon = %Lexicon{definition: %{"type" => "string", "maxLength" => 5}}
      assert {:ok, "hello"} = Lexicon.validate(lexicon, "hello")
      assert {:ok, "hi"} = Lexicon.validate(lexicon, "hi")

      assert {:error, [%{message: msg}]} = Lexicon.validate(lexicon, "hello world")
      assert msg =~ "exceeds maximum"
    end

    test "validates maxGraphemes" do
      lexicon = %Lexicon{definition: %{"type" => "string", "maxGraphemes" => 5}}
      assert {:ok, "hello"} = Lexicon.validate(lexicon, "hello")

      assert {:error, [%{message: msg}]} = Lexicon.validate(lexicon, "hello!")
      assert msg =~ "exceeds maximum"
    end

    test "validates enum" do
      lexicon = %Lexicon{definition: %{"type" => "string", "enum" => ["yes", "no", "maybe"]}}
      assert {:ok, "yes"} = Lexicon.validate(lexicon, "yes")

      assert {:error, [%{message: msg}]} = Lexicon.validate(lexicon, "unknown")
      assert msg =~ "not in enum"
    end
  end

  describe "validate/2 - objects" do
    test "validates simple object" do
      lexicon = %Lexicon{
        definition: %{
          "type" => "object",
          "properties" => %{
            "name" => %{"type" => "string"},
            "age" => %{"type" => "integer"}
          }
        }
      }

      data = %{"name" => "Alice", "age" => 30}
      assert {:ok, ^data} = Lexicon.validate(lexicon, data)
    end

    test "validates required properties" do
      lexicon = %Lexicon{
        definition: %{
          "type" => "object",
          "properties" => %{
            "name" => %{"type" => "string"},
            "email" => %{"type" => "string"}
          },
          "required" => ["name", "email"]
        }
      }

      # Valid
      data = %{"name" => "Alice", "email" => "alice@example.com"}
      assert {:ok, ^data} = Lexicon.validate(lexicon, data)

      # Missing required field
      assert {:error, [%{path: ["email"], message: msg}]} =
               Lexicon.validate(lexicon, %{"name" => "Alice"})

      assert msg =~ "required property missing"
    end

    test "validates nested objects" do
      lexicon = %Lexicon{
        definition: %{
          "type" => "object",
          "properties" => %{
            "user" => %{
              "type" => "object",
              "properties" => %{
                "name" => %{"type" => "string"}
              },
              "required" => ["name"]
            }
          },
          "required" => ["user"]
        }
      }

      data = %{"user" => %{"name" => "Alice"}}
      assert {:ok, ^data} = Lexicon.validate(lexicon, data)

      # Missing nested required field
      assert {:error, errors} = Lexicon.validate(lexicon, %{"user" => %{}})
      assert Enum.any?(errors, fn %{path: path} -> path == ["user", "name"] end)
    end

    test "accepts additional properties not in schema" do
      lexicon = %Lexicon{
        definition: %{
          "type" => "object",
          "properties" => %{
            "name" => %{"type" => "string"}
          }
        }
      }

      data = %{"name" => "Alice", "extra" => "value"}
      assert {:ok, ^data} = Lexicon.validate(lexicon, data)
    end

    test "rejects non-object for object type" do
      lexicon = %Lexicon{definition: %{"type" => "object"}}
      assert {:error, [%{message: msg}]} = Lexicon.validate(lexicon, "not an object")
      assert msg =~ "expected object"
    end
  end

  describe "validate/2 - arrays" do
    test "validates array of primitives" do
      lexicon = %Lexicon{
        definition: %{
          "type" => "array",
          "items" => %{"type" => "string"}
        }
      }

      data = ["hello", "world"]
      assert {:ok, ^data} = Lexicon.validate(lexicon, data)
    end

    test "validates array of objects" do
      lexicon = %Lexicon{
        definition: %{
          "type" => "array",
          "items" => %{
            "type" => "object",
            "properties" => %{
              "id" => %{"type" => "integer"},
              "name" => %{"type" => "string"}
            },
            "required" => ["id"]
          }
        }
      }

      data = [
        %{"id" => 1, "name" => "Alice"},
        %{"id" => 2, "name" => "Bob"}
      ]

      assert {:ok, ^data} = Lexicon.validate(lexicon, data)
    end

    test "validates array minLength" do
      lexicon = %Lexicon{
        definition: %{
          "type" => "array",
          "items" => %{"type" => "string"},
          "minLength" => 2
        }
      }

      assert {:ok, ["a", "b"]} = Lexicon.validate(lexicon, ["a", "b"])

      assert {:error, [%{message: msg}]} = Lexicon.validate(lexicon, ["a"])
      assert msg =~ "less than minimum"
    end

    test "validates array maxLength" do
      lexicon = %Lexicon{
        definition: %{
          "type" => "array",
          "items" => %{"type" => "string"},
          "maxLength" => 3
        }
      }

      assert {:ok, ["a", "b", "c"]} = Lexicon.validate(lexicon, ["a", "b", "c"])

      assert {:error, [%{message: msg}]} = Lexicon.validate(lexicon, ["a", "b", "c", "d"])
      assert msg =~ "exceeds maximum"
    end

    test "reports errors with array indices in path" do
      lexicon = %Lexicon{
        definition: %{
          "type" => "array",
          "items" => %{"type" => "integer"}
        }
      }

      assert {:error, [%{path: path, message: msg}]} =
               Lexicon.validate(lexicon, [1, 2, "not a number"])

      assert path == ["[2]"]
      assert msg =~ "expected integer"
    end

    test "rejects non-array for array type" do
      lexicon = %Lexicon{definition: %{"type" => "array"}}
      assert {:error, [%{message: msg}]} = Lexicon.validate(lexicon, "not an array")
      assert msg =~ "expected array"
    end
  end

  describe "validate/2 - special types" do
    test "validates unknown type (accepts anything)" do
      lexicon = %Lexicon{definition: %{"type" => "unknown"}}
      assert {:ok, "string"} = Lexicon.validate(lexicon, "string")
      assert {:ok, 123} = Lexicon.validate(lexicon, 123)
      assert {:ok, %{"any" => "value"}} = Lexicon.validate(lexicon, %{"any" => "value"})
    end

    test "validates bytes type (placeholder)" do
      lexicon = %Lexicon{definition: %{"type" => "bytes"}}
      assert {:ok, "base64data"} = Lexicon.validate(lexicon, "base64data")
    end

    test "validates cid-link type (placeholder)" do
      lexicon = %Lexicon{definition: %{"type" => "cid-link"}}
      assert {:ok, "bafyreib2rxk3rybk"} = Lexicon.validate(lexicon, "bafyreib2rxk3rybk")
    end

    test "validates blob type (placeholder)" do
      lexicon = %Lexicon{definition: %{"type" => "blob"}}
      assert {:ok, %{"cid" => "..."}} = Lexicon.validate(lexicon, %{"cid" => "..."})
    end
  end

  describe "validate/2 - const" do
    test "validates const value" do
      lexicon = %Lexicon{definition: %{"const" => "fixed_value"}}
      # Const accepts any input and validates it as the const value
      assert {:ok, %{}} = Lexicon.validate(lexicon, %{})
      assert {:ok, "anything"} = Lexicon.validate(lexicon, "anything")
    end
  end

  describe "validate/2 - real-world schemas" do
    test "validates a simple post record" do
      lexicon = %Lexicon{
        definition: %{
          "type" => "object",
          "properties" => %{
            "text" => %{"type" => "string", "maxLength" => 300},
            "createdAt" => %{"type" => "string"}
          },
          "required" => ["text", "createdAt"]
        }
      }

      post = %{
        "text" => "Hello, ATProto!",
        "createdAt" => "2024-01-15T12:00:00Z"
      }

      assert {:ok, ^post} = Lexicon.validate(lexicon, post)
    end

    test "rejects post with text too long" do
      lexicon = %Lexicon{
        definition: %{
          "type" => "object",
          "properties" => %{
            "text" => %{"type" => "string", "maxLength" => 10}
          },
          "required" => ["text"]
        }
      }

      post = %{"text" => "This text is way too long"}

      assert {:error, [%{path: ["text"], message: msg}]} = Lexicon.validate(lexicon, post)
      assert msg =~ "exceeds maximum"
    end

    test "validates array of tags" do
      lexicon = %Lexicon{
        definition: %{
          "type" => "object",
          "properties" => %{
            "tags" => %{
              "type" => "array",
              "items" => %{"type" => "string", "maxLength" => 64},
              "maxLength" => 8
            }
          }
        }
      }

      data = %{"tags" => ["elixir", "atproto", "bluesky"]}
      assert {:ok, ^data} = Lexicon.validate(lexicon, data)

      # Too many tags
      too_many_tags = %{"tags" => List.duplicate("tag", 9)}

      assert {:error, [%{path: ["tags"], message: msg}]} =
               Lexicon.validate(lexicon, too_many_tags)

      assert msg =~ "exceeds maximum"
    end
  end

  describe "validate/2 - error reporting" do
    test "reports multiple errors" do
      lexicon = %Lexicon{
        definition: %{
          "type" => "object",
          "properties" => %{
            "name" => %{"type" => "string"},
            "age" => %{"type" => "integer"}
          },
          "required" => ["name", "age"]
        }
      }

      assert {:error, errors} = Lexicon.validate(lexicon, %{})
      assert length(errors) == 2
      assert Enum.any?(errors, fn %{path: path} -> path == ["name"] end)
      assert Enum.any?(errors, fn %{path: path} -> path == ["age"] end)
    end

    test "reports errors with correct paths" do
      lexicon = %Lexicon{
        definition: %{
          "type" => "object",
          "properties" => %{
            "profile" => %{
              "type" => "object",
              "properties" => %{
                "email" => %{"type" => "string"}
              },
              "required" => ["email"]
            }
          },
          "required" => ["profile"]
        }
      }

      assert {:error, [%{path: path}]} = Lexicon.validate(lexicon, %{"profile" => %{}})
      assert path == ["profile", "email"]
    end
  end

  describe "edge cases" do
    test "validates empty object" do
      lexicon = %Lexicon{definition: %{"type" => "object"}}
      assert {:ok, %{}} = Lexicon.validate(lexicon, %{})
    end

    test "validates empty array" do
      lexicon = %Lexicon{definition: %{"type" => "array"}}
      assert {:ok, []} = Lexicon.validate(lexicon, [])
    end

    test "validates empty string" do
      lexicon = %Lexicon{definition: %{"type" => "string"}}
      assert {:ok, ""} = Lexicon.validate(lexicon, "")
    end

    test "handles schema without properties" do
      lexicon = %Lexicon{definition: %{"type" => "object", "required" => ["field"]}}
      assert {:error, errors} = Lexicon.validate(lexicon, %{})
      assert length(errors) == 1
    end
  end
end
