defmodule Raxol.Headless.McpToolsTest do
  use ExUnit.Case, async: false

  alias Raxol.Headless.McpTools

  describe "tools/0" do
    test "returns 6 tool definitions" do
      tools = McpTools.tools()
      assert length(tools) == 6
    end

    test "each tool has required fields" do
      for tool <- McpTools.tools() do
        assert is_binary(tool.name)
        assert is_binary(tool.description)
        assert is_map(tool.inputSchema)
        assert is_function(tool.callback, 1)
      end
    end

    test "tool names follow raxol_ prefix convention" do
      names = Enum.map(McpTools.tools(), & &1.name)

      assert "raxol_start" in names
      assert "raxol_screenshot" in names
      assert "raxol_send_key" in names
      assert "raxol_get_model" in names
      assert "raxol_stop" in names
      assert "raxol_list" in names
    end

    test "input schemas have type: object" do
      for tool <- McpTools.tools() do
        assert tool.inputSchema.type == "object"
      end
    end
  end

  describe "inject_into_tidewave/0" do
    test "returns error when tidewave not started" do
      # In test env, Tidewave ETS table won't exist
      assert {:error, :tidewave_not_started} = McpTools.inject_into_tidewave()
    end
  end
end
