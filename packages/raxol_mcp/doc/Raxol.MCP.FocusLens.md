# `Raxol.MCP.FocusLens`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/mcp/focus_lens.ex#L1)

Attention-aware tool filtering for MCP surfaces.

Complex UIs can expose 100+ tools, but LLM tool selection degrades
past ~20. FocusLens filters the full tool set to a manageable subset
based on which widget has focus.

## Modes

  * `:all` -- return all tools (default for headless sessions)
  * `:focused` -- return tools for the focused widget + globals
  * `:hover` -- return tools for focused widget + hovered widget + globals

In `:focused` and `:hover` modes, a `discover_tools` meta-tool is
always included so agents can search the full set by keyword.

## Usage

    all_tools = TreeWalker.derive_tools(view_tree, context)

    # Headless: show everything
    FocusLens.filter(all_tools, mode: :all)

    # Interactive: show focused + globals
    FocusLens.filter(all_tools, mode: :focused, focused_id: "search_input")

    # Mouse tracking: anticipatory tool exposure
    FocusLens.filter(all_tools,
      mode: :hover,
      focused_id: "search_input",
      hover_id: "submit_btn"
    )

# `tool_def`

```elixir
@type tool_def() :: Raxol.MCP.Registry.tool_def()
```

# `discover_tools_spec`

```elixir
@spec discover_tools_spec(GenServer.server()) :: tool_def()
```

Returns the `discover_tools` meta-tool spec.

This tool lets agents search the full tool set by keyword when
FocusLens is hiding tools. Pass a registry reference so the tool
can query all registered tools.

# `filter`

```elixir
@spec filter(
  [tool_def()],
  keyword()
) :: [tool_def()]
```

Filters a list of tools based on focus state.

## Options

  * `:mode` - `:all` (default), `:focused`, or `:hover`
  * `:focused_id` - widget ID that currently has focus
  * `:hover_id` - widget ID under the mouse cursor (for `:hover` mode)
  * `:max_tools` - maximum number of tools to return (default: 15)
  * `:registry` - Registry reference for `discover_tools` (optional)

---

*Consult [api-reference.md](api-reference.md) for complete listing*
