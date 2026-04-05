defmodule Raxol.MCP.FocusLensTest do
  use ExUnit.Case, async: true

  alias Raxol.MCP.FocusLens

  defp sample_tools do
    noop = fn _ -> {:ok, "ok"} end

    [
      %{name: "btn1.click", description: "Click button 1", inputSchema: %{}, callback: noop},
      %{name: "btn2.click", description: "Click button 2", inputSchema: %{}, callback: noop},
      %{
        name: "input1.type_into",
        description: "Type into input",
        inputSchema: %{},
        callback: noop
      },
      %{
        name: "input1.get_value",
        description: "Get input value",
        inputSchema: %{},
        callback: noop
      },
      %{name: "input1.clear", description: "Clear input", inputSchema: %{}, callback: noop},
      %{name: "table1.sort", description: "Sort table", inputSchema: %{}, callback: noop},
      %{name: "table1.select_row", description: "Select row", inputSchema: %{}, callback: noop},
      %{name: "global_action", description: "A global action", inputSchema: %{}, callback: noop}
    ]
  end

  describe "filter/2 with :all mode" do
    test "returns all tools" do
      tools = sample_tools()
      result = FocusLens.filter(tools, mode: :all)
      assert length(result) == length(tools)
    end

    test "defaults to :all mode" do
      tools = sample_tools()
      result = FocusLens.filter(tools)
      assert length(result) == length(tools)
    end
  end

  describe "filter/2 with :focused mode" do
    test "returns tools for focused widget" do
      result = FocusLens.filter(sample_tools(), mode: :focused, focused_id: "input1")
      names = Enum.map(result, & &1.name)

      assert "input1.type_into" in names
      assert "input1.get_value" in names
      assert "input1.clear" in names
    end

    test "includes global tools (no dot in name)" do
      result = FocusLens.filter(sample_tools(), mode: :focused, focused_id: "input1")
      names = Enum.map(result, & &1.name)

      assert "global_action" in names
    end

    test "excludes tools from other widgets" do
      result = FocusLens.filter(sample_tools(), mode: :focused, focused_id: "input1")
      names = Enum.map(result, & &1.name)

      refute "btn1.click" in names
      refute "btn2.click" in names
      refute "table1.sort" in names
    end

    test "includes discover_tools when registry provided" do
      {:ok, registry} = Raxol.MCP.Registry.start_link(name: nil)

      result =
        FocusLens.filter(sample_tools(),
          mode: :focused,
          focused_id: "input1",
          registry: registry
        )

      names = Enum.map(result, & &1.name)
      assert "discover_tools" in names

      GenServer.stop(registry)
    end

    test "respects max_tools limit" do
      result =
        FocusLens.filter(sample_tools(), mode: :focused, focused_id: "input1", max_tools: 2)

      assert length(result) <= 2
    end

    test "falls back to truncated list when no focused_id" do
      result = FocusLens.filter(sample_tools(), mode: :focused, max_tools: 3)
      assert length(result) == 3
    end
  end

  describe "discover_tools_spec/1" do
    test "returns a valid tool def" do
      {:ok, registry} = Raxol.MCP.Registry.start_link(name: nil)

      spec = FocusLens.discover_tools_spec(registry)

      assert spec.name == "discover_tools"
      assert is_binary(spec.description)
      assert is_map(spec.inputSchema)
      assert is_function(spec.callback, 1)

      GenServer.stop(registry)
    end

    test "callback searches registered tools" do
      {:ok, registry} = Raxol.MCP.Registry.start_link(name: nil)

      Raxol.MCP.Registry.register_tools(registry, [
        %{
          name: "btn.click",
          description: "Click a button",
          inputSchema: %{},
          callback: fn _ -> {:ok, "ok"} end
        },
        %{
          name: "input.type",
          description: "Type into input",
          inputSchema: %{},
          callback: fn _ -> {:ok, "ok"} end
        }
      ])

      spec = FocusLens.discover_tools_spec(registry)

      assert {:ok, [%{type: "text", text: text}]} = spec.callback.(%{"query" => "click"})
      assert text =~ "btn.click"
      refute text =~ "input.type"

      GenServer.stop(registry)
    end
  end
end
