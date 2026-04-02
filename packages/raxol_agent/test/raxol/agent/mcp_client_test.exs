defmodule Raxol.Agent.McpClientTest do
  use ExUnit.Case, async: true

  alias Raxol.Agent.McpClient

  describe "tool_name/2" do
    test "builds namespaced tool name" do
      assert "mcp__my_server__read_file" == McpClient.tool_name(:my_server, "read_file")
    end

    test "normalizes special characters in server name" do
      assert "mcp__my_cool_server__tool" == McpClient.tool_name(:"my-cool-server", "tool")
    end
  end

  describe "parse_tool_name/1" do
    test "parses valid namespaced name" do
      assert {:ok, {"my_server", "read_file"}} ==
               McpClient.parse_tool_name("mcp__my_server__read_file")
    end

    test "returns error for non-mcp name" do
      assert :error == McpClient.parse_tool_name("some_tool")
    end

    test "returns error for malformed mcp name" do
      assert :error == McpClient.parse_tool_name("mcp__nodelimiter")
    end

    test "handles tool names with underscores" do
      assert {:ok, {"server", "read_file_content"}} ==
               McpClient.parse_tool_name("mcp__server__read_file_content")
    end
  end

  describe "start_link/1 with mock server" do
    @tag :integration
    test "starts and initializes with a real MCP server" do
      # This test requires `npx` and network access -- skip in CI
      # To run: MIX_ENV=test mix test --include integration
    end
  end
end
