# `Raxol.MCP.StructuredScreenshot`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/mcp/structured_screenshot.ex#L1)

Converts a view tree into a clean, JSON-friendly widget summary.

Used by the `raxol_screenshot` MCP tool to return structured content
alongside the plain text capture. Strips callbacks and normalizes
widget nodes to a consistent shape.

# `widget_summary`

```elixir
@type widget_summary() :: %{
  :type =&gt; atom(),
  :id =&gt; String.t() | nil,
  :children =&gt; [widget_summary()],
  optional(:content) =&gt; String.t()
}
```

# `from_view_tree`

```elixir
@spec from_view_tree(map() | list() | nil) :: [widget_summary()]
```

Convert a view tree map to a list of widget summaries.

Each node retains `:type`, `:id`, `:content` (if text), and recursed
`:children`. All callbacks and style details are stripped.

# `to_json`

```elixir
@spec to_json([widget_summary()]) :: String.t()
```

Encode a widget summary list to a JSON string.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
