defmodule Raxol.MCP.ResourceRouterTest do
  use ExUnit.Case, async: true

  alias Raxol.MCP.{Registry, ResourceRouter}

  setup do
    {:ok, registry} = Registry.start_link(name: :"router_reg_#{System.unique_integer()}")
    %{registry: registry}
  end

  describe "parse/1" do
    test "parses session URI with path" do
      assert {:ok, parsed} = ResourceRouter.parse("raxol://session/abc123/model/counters")
      assert parsed.scheme == "raxol"
      assert parsed.session == "abc123"
      assert parsed.path == ["model", "counters"]
    end

    test "parses session URI without path" do
      assert {:ok, parsed} = ResourceRouter.parse("raxol://session/abc123")
      assert parsed.session == "abc123"
      assert parsed.path == []
    end

    test "parses multi-segment path" do
      assert {:ok, parsed} = ResourceRouter.parse("raxol://session/s1/model/deep/nested")
      assert parsed.path == ["model", "deep", "nested"]
    end

    test "rejects non-session raxol URIs" do
      assert {:error, :invalid_uri} = ResourceRouter.parse("raxol://other/thing")
    end

    test "rejects non-raxol URIs" do
      assert {:error, :invalid_uri} = ResourceRouter.parse("https://example.com")
    end
  end

  describe "resolve/2" do
    test "resolves registered resources directly", %{registry: r} do
      :ok =
        Registry.register_resources(r, [
          %{
            uri: "raxol://session/s1/model/count",
            name: "Count",
            description: "Counter value",
            callback: fn -> {:ok, 42} end
          }
        ])

      assert {:ok, 42} = ResourceRouter.resolve(r, "raxol://session/s1/model/count")
    end

    test "falls back to pattern-based resolution for /tools", %{registry: r} do
      :ok =
        Registry.register_tools(r, [
          %{
            name: "test_tool",
            description: "A tool",
            inputSchema: %{},
            callback: fn _ -> {:ok, "ok"} end
          }
        ])

      assert {:ok, tools} = ResourceRouter.resolve(r, "raxol://session/s1/tools")
      assert is_list(tools)
      assert hd(tools).name == "test_tool"
    end

    test "falls back to pattern-based resolution for /resources", %{registry: r} do
      :ok =
        Registry.register_resources(r, [
          %{
            uri: "raxol://x",
            name: "X",
            description: "X",
            callback: fn -> {:ok, nil} end
          }
        ])

      assert {:ok, resources} = ResourceRouter.resolve(r, "raxol://session/s1/resources")
      assert is_list(resources)
    end

    test "returns not_found for unknown patterns", %{registry: r} do
      assert {:error, :resource_not_found} =
               ResourceRouter.resolve(r, "raxol://session/s1/unknown/path")
    end
  end
end
