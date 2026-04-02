defmodule Raxol.Agent.Action.SchemaTest do
  use ExUnit.Case, async: true

  alias Raxol.Agent.Action.Schema

  @schema [
    path: [type: :string, required: true, description: "File path"],
    timeout: [type: :integer, default: 5000],
    verbose: [type: :boolean],
    format: [type: :string, enum: ["json", "text"], default: "text"]
  ]

  describe "validate/2" do
    test "passes with all required fields present" do
      assert {:ok, params} = Schema.validate(%{path: "/tmp/foo"}, @schema)
      assert params.path == "/tmp/foo"
    end

    test "applies defaults for missing optional fields" do
      assert {:ok, params} = Schema.validate(%{path: "/tmp/foo"}, @schema)
      assert params.timeout == 5000
      assert params.format == "text"
    end

    test "preserves explicit values over defaults" do
      assert {:ok, params} = Schema.validate(%{path: "/tmp", timeout: 1000}, @schema)
      assert params.timeout == 1000
    end

    test "errors on missing required field" do
      assert {:error, errors} = Schema.validate(%{}, @schema)
      assert {_field, reason} = List.keyfind(errors, :path, 0)
      assert reason =~ "required"
    end

    test "errors on wrong type" do
      assert {:error, errors} = Schema.validate(%{path: 123}, @schema)
      assert {_field, reason} = List.keyfind(errors, :path, 0)
      assert reason =~ "type"
    end

    test "errors on integer field with string value" do
      assert {:error, errors} = Schema.validate(%{path: "ok", timeout: "slow"}, @schema)
      assert {_field, reason} = List.keyfind(errors, :timeout, 0)
      assert reason =~ "type"
    end

    test "errors on enum violation" do
      assert {:error, errors} = Schema.validate(%{path: "ok", format: "xml"}, @schema)
      assert {_field, reason} = List.keyfind(errors, :format, 0)
      assert reason =~ "one of"
    end

    test "passes with valid enum value" do
      assert {:ok, params} = Schema.validate(%{path: "ok", format: "json"}, @schema)
      assert params.format == "json"
    end

    test "boolean field accepts true/false" do
      assert {:ok, params} = Schema.validate(%{path: "ok", verbose: true}, @schema)
      assert params.verbose == true
    end

    test "boolean field rejects non-boolean" do
      assert {:error, errors} = Schema.validate(%{path: "ok", verbose: "yes"}, @schema)
      assert {_field, _reason} = List.keyfind(errors, :verbose, 0)
    end

    test "collects multiple errors" do
      assert {:error, errors} = Schema.validate(%{timeout: "bad"}, @schema)
      assert length(errors) >= 2
    end

    test "validates list type" do
      schema = [tags: [type: :list, required: true]]
      assert {:ok, _} = Schema.validate(%{tags: ["a", "b"]}, schema)
      assert {:error, _} = Schema.validate(%{tags: "not_a_list"}, schema)
    end

    test "validates typed list" do
      schema = [ids: [type: {:list, :integer}, required: true]]
      assert {:ok, _} = Schema.validate(%{ids: [1, 2, 3]}, schema)
      assert {:error, _} = Schema.validate(%{ids: [1, "two", 3]}, schema)
    end

    test "validates map type" do
      schema = [config: [type: :map]]
      assert {:ok, _} = Schema.validate(%{config: %{a: 1}}, schema)
      assert {:error, _} = Schema.validate(%{config: "nope"}, schema)
    end

    test "validates atom type" do
      schema = [mode: [type: :atom, required: true]]
      assert {:ok, _} = Schema.validate(%{mode: :fast}, schema)
      assert {:error, _} = Schema.validate(%{mode: "fast"}, schema)
    end

    test "float type accepts integers" do
      schema = [score: [type: :float]]
      assert {:ok, _} = Schema.validate(%{score: 3}, schema)
      assert {:ok, _} = Schema.validate(%{score: 3.14}, schema)
    end

    test "empty schema validates any map" do
      assert {:ok, %{a: 1}} = Schema.validate(%{a: 1}, [])
    end

    test "extra fields pass through" do
      assert {:ok, params} = Schema.validate(%{path: "ok", extra: "value"}, @schema)
      assert params.extra == "value"
    end
  end

  describe "to_json_schema/3" do
    test "produces valid function tool definition" do
      result = Schema.to_json_schema(@schema, "read_file", "Read a file")

      assert result["type"] == "function"
      assert result["function"]["name"] == "read_file"
      assert result["function"]["description"] == "Read a file"

      params = result["function"]["parameters"]
      assert params["type"] == "object"
      assert "path" in params["required"]
      refute "timeout" in params["required"]

      assert params["properties"]["path"]["type"] == "string"
      assert params["properties"]["path"]["description"] == "File path"
      assert params["properties"]["timeout"]["type"] == "integer"
      assert params["properties"]["format"]["enum"] == ["json", "text"]
    end

    test "boolean becomes boolean in JSON Schema" do
      schema = [flag: [type: :boolean, description: "A flag"]]
      result = Schema.to_json_schema(schema, "test", "")
      assert result["function"]["parameters"]["properties"]["flag"]["type"] == "boolean"
    end

    test "float becomes number in JSON Schema" do
      schema = [score: [type: :float]]
      result = Schema.to_json_schema(schema, "test", "")
      assert result["function"]["parameters"]["properties"]["score"]["type"] == "number"
    end

    test "list becomes array in JSON Schema" do
      schema = [items: [type: :list]]
      result = Schema.to_json_schema(schema, "test", "")
      assert result["function"]["parameters"]["properties"]["items"]["type"] == "array"
    end

    test "map becomes object in JSON Schema" do
      schema = [config: [type: :map]]
      result = Schema.to_json_schema(schema, "test", "")
      assert result["function"]["parameters"]["properties"]["config"]["type"] == "object"
    end
  end
end
