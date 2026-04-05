defmodule Raxol.MCP.Property.ToolProviderTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Raxol.MCP.ToolProvider

  # -- Mock widgets with varying tool counts --

  defmodule VariableWidget do
    @behaviour Raxol.MCP.ToolProvider

    @impl true
    def mcp_tools(state) do
      count = state[:tool_count] || 1

      for i <- 1..count do
        %{
          name: "action_#{i}",
          description: "Action #{i}",
          inputSchema: %{type: "object", properties: %{}}
        }
      end
    end

    @impl true
    def handle_tool_call("action_" <> _, _args, _ctx), do: {:ok, "done"}
    def handle_tool_call(_, _, _), do: {:error, :unknown}
  end

  defmodule StateDependentWidget do
    @behaviour Raxol.MCP.ToolProvider

    @impl true
    def mcp_tools(%{active: false}), do: []

    def mcp_tools(%{items: items}) when is_list(items) do
      base = [
        %{
          name: "get_items",
          description: "Get items",
          inputSchema: %{type: "object", properties: %{}}
        }
      ]

      if length(items) > 0 do
        base ++
          [
            %{
              name: "select",
              description: "Select an item",
              inputSchema: %{
                type: "object",
                properties: %{index: %{type: "integer"}},
                required: ["index"]
              }
            }
          ]
      else
        base
      end
    end

    def mcp_tools(_), do: []

    @impl true
    def handle_tool_call("get_items", _args, ctx) do
      {:ok, ctx.widget_state[:items] || []}
    end

    def handle_tool_call("select", %{"index" => i}, ctx) do
      items = ctx.widget_state[:items] || []

      if i >= 0 and i < length(items) do
        {:ok, "Selected #{Enum.at(items, i)}", [{:select, i}]}
      else
        {:error, "Index #{i} out of range"}
      end
    end

    def handle_tool_call(_, _, _), do: {:error, :unknown}
  end

  # -- Properties --

  describe "tool_provider?/1" do
    property "returns true for any module with both callbacks" do
      check all(
              module <- member_of([VariableWidget, StateDependentWidget]),
              max_runs: 50
            ) do
        assert ToolProvider.tool_provider?(module)
      end
    end

    property "returns false for stdlib modules" do
      check all(
              module <- member_of([String, Enum, Map, List, Kernel, IO, File]),
              max_runs: 50
            ) do
        refute ToolProvider.tool_provider?(module)
      end
    end
  end

  describe "mcp_tools/1 contract" do
    property "always returns a list of maps with required keys" do
      check all(
              tool_count <- integer(1..10),
              max_runs: 200
            ) do
        state = %{tool_count: tool_count}
        tools = VariableWidget.mcp_tools(state)

        assert is_list(tools)
        assert length(tools) == tool_count

        for tool <- tools do
          assert is_binary(tool.name)
          assert is_binary(tool.description)
          assert is_map(tool.inputSchema)
          assert String.length(tool.name) > 0
        end
      end
    end

    property "tool names are unique within a widget" do
      check all(
              tool_count <- integer(1..10),
              max_runs: 200
            ) do
        tools = VariableWidget.mcp_tools(%{tool_count: tool_count})
        names = Enum.map(tools, & &1.name)
        assert names == Enum.uniq(names)
      end
    end

    property "state-dependent widget produces correct tools based on state" do
      check all(
              item_count <- integer(0..10),
              active <- boolean(),
              max_runs: 300
            ) do
        items = if item_count > 0, do: for(i <- 1..item_count, do: "item_#{i}"), else: []
        state = %{items: items, active: active}
        tools = StateDependentWidget.mcp_tools(state)

        if not active do
          assert tools == []
        else
          names = Enum.map(tools, & &1.name)
          assert "get_items" in names

          if item_count > 0 do
            assert "select" in names
          else
            refute "select" in names
          end
        end
      end
    end
  end

  describe "handle_tool_call/3 contract" do
    property "valid actions return {:ok, _} or {:ok, _, _}" do
      check all(
              action_num <- integer(1..10),
              max_runs: 200
            ) do
        ctx = %{widget_id: "test", widget_state: %{}, dispatcher_pid: nil}
        result = VariableWidget.handle_tool_call("action_#{action_num}", %{}, ctx)
        assert match?({:ok, _}, result)
      end
    end

    property "unknown actions return {:error, _}" do
      check all(
              action <- string(:alphanumeric, min_length: 1, max_length: 20),
              not String.starts_with?(action, "action_"),
              max_runs: 200
            ) do
        ctx = %{widget_id: "test", widget_state: %{}, dispatcher_pid: nil}
        result = VariableWidget.handle_tool_call(action, %{}, ctx)
        assert match?({:error, _}, result)
      end
    end

    property "select with valid index succeeds, invalid index errors" do
      check all(
              item_count <- integer(1..20),
              index <- integer(-5..25),
              max_runs: 500
            ) do
        items = for(i <- 1..item_count, do: "item_#{i}")
        ctx = %{widget_id: "w", widget_state: %{items: items}, dispatcher_pid: nil}
        result = StateDependentWidget.handle_tool_call("select", %{"index" => index}, ctx)

        if index >= 0 and index < item_count do
          assert match?({:ok, _, _}, result)
        else
          assert match?({:error, _}, result)
        end
      end
    end
  end
end
