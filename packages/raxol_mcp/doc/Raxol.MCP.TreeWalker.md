# `Raxol.MCP.TreeWalker`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/mcp/tree_walker.ex#L1)

Traverses a view element tree and derives namespaced MCP tools from widgets.

The view tree is the output of a TEA app's `view/1` function -- nested maps
with `:type`, `:id`, `:attrs`, `:children` keys. TreeWalker walks this tree,
finds widgets that implement `Raxol.MCP.ToolProvider`, calls `mcp_tools/1`
to get tool specs, namespaces them by widget ID, and wraps callbacks that
dispatch TEA messages through the session's Dispatcher.

## Usage

    context = %{dispatcher_pid: dispatcher_pid}
    tools = TreeWalker.derive_tools(view_tree, context)
    Raxol.MCP.Registry.register_tools(tools)

Tool names are namespaced as `"widget_id.action"`, e.g., `"search_input.type_into"`.
Nodes without an `:id` key are skipped (layout containers like `:column`, `:row`).

## Excluding Widgets

Set `mcp_exclude: true` in a widget's attrs to suppress tool derivation:

    %{type: :text_input, id: "internal", attrs: %{mcp_exclude: true}}

The widget and its children still render normally -- only MCP tool
exposure is suppressed. Useful for decorative or internal widgets.

# `context`

```elixir
@type context() :: %{
  dispatcher_pid: pid() | nil,
  type_map: %{required(atom()) =&gt; module()}
}
```

# `derive_tools`

```elixir
@spec derive_tools(map() | [map()], context()) :: [Raxol.MCP.Registry.tool_def()]
```

Derives MCP tool definitions from a view element tree.

Returns a list of `Registry.tool_def()` maps with namespaced names and
wrapped callbacks that dispatch TEA messages.

## Options in context

  * `:dispatcher_pid` - pid of the session's Dispatcher (for message dispatch)
  * `:type_map` - optional override for widget type -> module mapping

---

*Consult [api-reference.md](api-reference.md) for complete listing*
