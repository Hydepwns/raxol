defmodule Raxol.Agent.Action.ToolConverterTest do
  use ExUnit.Case, async: true

  alias Raxol.Agent.Action.ToolConverter

  defmodule ReadFile do
    use Raxol.Agent.Action,
      name: "read_file",
      description: "Read a file from disk",
      schema: [
        input: [
          path: [type: :string, required: true, description: "File path"]
        ]
      ]

    @impl true
    def run(%{path: path}, _ctx) do
      {:ok, %{content: "contents of #{path}", path: path}}
    end
  end

  defmodule CountLines do
    use Raxol.Agent.Action,
      name: "count_lines",
      description: "Count lines in text",
      schema: [
        input: [
          text: [type: :string, required: true, description: "Text to count"]
        ]
      ]

    @impl true
    def run(%{text: text}, _ctx) do
      {:ok, %{line_count: length(String.split(text, "\n"))}}
    end
  end

  @actions [ReadFile, CountLines]

  describe "to_tool_definitions/1" do
    test "converts action modules to tool definitions" do
      defs = ToolConverter.to_tool_definitions(@actions)
      assert length(defs) == 2

      [read_def, count_def] = defs
      assert read_def["function"]["name"] == "read_file"
      assert count_def["function"]["name"] == "count_lines"
      assert read_def["type"] == "function"
    end

    test "includes parameter schemas" do
      [read_def | _] = ToolConverter.to_tool_definitions(@actions)
      props = read_def["function"]["parameters"]["properties"]
      assert props["path"]["type"] == "string"
      assert "path" in read_def["function"]["parameters"]["required"]
    end
  end

  describe "dispatch_tool_call/3" do
    test "dispatches to matching action with atom-keyed args" do
      tool_call = %{"name" => "read_file", "arguments" => %{path: "/tmp/test.txt"}}
      assert {:ok, result} = ToolConverter.dispatch_tool_call(tool_call, @actions)
      assert result.content == "contents of /tmp/test.txt"
    end

    test "dispatches with string-keyed args" do
      tool_call = %{"name" => "read_file", "arguments" => %{"path" => "/tmp/test.txt"}}
      assert {:ok, result} = ToolConverter.dispatch_tool_call(tool_call, @actions)
      assert result.content == "contents of /tmp/test.txt"
    end

    test "dispatches with JSON string args" do
      tool_call = %{
        "name" => "count_lines",
        "arguments" => ~s({"text": "line1\\nline2\\nline3"})
      }

      assert {:ok, result} = ToolConverter.dispatch_tool_call(tool_call, @actions)
      assert result.line_count == 3
    end

    test "returns error for unknown tool" do
      tool_call = %{"name" => "nonexistent", "arguments" => %{}}

      assert {:error, {:unknown_tool, "nonexistent"}} =
               ToolConverter.dispatch_tool_call(tool_call, @actions)
    end

    test "passes context through" do
      defmodule CtxAction do
        use Raxol.Agent.Action,
          name: "ctx_action",
          description: "Reads context",
          schema: [input: []]

        @impl true
        def run(_params, ctx), do: {:ok, %{user: Map.get(ctx, :user)}}
      end

      tool_call = %{"name" => "ctx_action", "arguments" => %{}}

      assert {:ok, result} =
               ToolConverter.dispatch_tool_call(tool_call, [CtxAction], %{user: "alice"})

      assert result.user == "alice"
    end

    test "returns validation error for bad input" do
      tool_call = %{"name" => "read_file", "arguments" => %{}}

      assert {:error, errors} = ToolConverter.dispatch_tool_call(tool_call, @actions)
      assert is_list(errors)
    end
  end

  describe "format_tool_result/2" do
    test "formats result as tool role message" do
      result = ToolConverter.format_tool_result("call_123", %{content: "hello"})
      assert result.role == "tool"
      assert result.tool_call_id == "call_123"
      assert result.content == ~s({"content":"hello"})
    end
  end
end
