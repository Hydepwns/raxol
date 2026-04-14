# `Raxol.MCP.ToolProvider`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/mcp/tool_provider.ex#L1)

Behaviour for widgets that expose MCP tools.

Each interactive widget can implement this behaviour to declare what
semantic actions (tools) are available given its current state. The
`TreeWalker` traverses the view tree, calls `mcp_tools/1` on each
widget that implements this behaviour, and registers the resulting
tools with the MCP Registry.

## Tool Specs

`mcp_tools/1` returns a list of tool spec maps:

    %{
      name: "click",
      description: "Click the Submit button",
      inputSchema: %{type: "object", properties: %{}}
    }

The `name` is the action name (e.g., "click", "type_into"). The
TreeWalker namespaces it with the widget ID: `"submit_btn.click"`.

## Handle Tool Call

`handle_tool_call/3` executes the action. It receives the action name,
arguments map, and a context map with `:widget_id`, `:widget_state`,
and `:dispatcher_pid`.

Return values:
- `{:ok, result}` -- pure read, no state change
- `{:ok, result, [message]}` -- result + TEA messages to dispatch
- `{:error, reason}` -- failure

## Example

    defmodule MyApp.Button do
      @behaviour Raxol.MCP.ToolProvider

      @impl Raxol.MCP.ToolProvider
      def mcp_tools(%{attrs: %{disabled: true}}), do: []
      def mcp_tools(state) do
        [%{
          name: "click",
          description: "Click the '#{state[:attrs][:label] || "Button"}' button",
          inputSchema: %{type: "object", properties: %{}}
        }]
      end

      @impl Raxol.MCP.ToolProvider
      def handle_tool_call("click", _args, context) do
        {:ok, "Clicked", [context.widget_state[:attrs][:on_click]]}
      end
    end

# `context`

```elixir
@type context() :: %{
  widget_id: String.t(),
  widget_state: map(),
  dispatcher_pid: pid() | nil
}
```

# `result`

```elixir
@type result() :: {:ok, term()} | {:ok, term(), [term()]} | {:error, term()}
```

# `tool_spec`

```elixir
@type tool_spec() :: %{name: String.t(), description: String.t(), inputSchema: map()}
```

# `handle_tool_call`

```elixir
@callback handle_tool_call(
  name :: String.t(),
  args :: map(),
  context :: context()
) :: result()
```

Handles an MCP tool call for this widget.

`name` is the action name (e.g., "click", "type_into") without the
widget ID namespace prefix.

`args` is the arguments map from the MCP client.

`context` contains `:widget_id`, `:widget_state`, and `:dispatcher_pid`.

# `mcp_tools`

```elixir
@callback mcp_tools(widget_state :: map()) :: [tool_spec()]
```

Returns the list of MCP tool specs for the widget's current state.

Called by `TreeWalker` during view tree traversal. The widget state
is the raw map from the view tree (the output of `view/1`), not the
internal component struct.

# `tool_provider?`

```elixir
@spec tool_provider?(module()) :: boolean()
```

Returns true if the given module implements the ToolProvider behaviour.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
