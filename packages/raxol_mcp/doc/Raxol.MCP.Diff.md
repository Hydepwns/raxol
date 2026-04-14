# `Raxol.MCP.Diff`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/mcp/diff.ex#L1)

Simple map diff utility for detecting resource/model changes.

Compares two maps and returns which keys were added, removed, or changed.
Used by the ToolSynchronizer to compute model projection diffs for
streaming notifications.

# `diff_result`

```elixir
@type diff_result() :: %{
  added: %{required(term()) =&gt; term()},
  removed: [term()],
  changed: %{required(term()) =&gt; {old :: term(), new :: term()}}
}
```

# `changed?`

```elixir
@spec changed?(diff_result()) :: boolean()
```

Returns true if the diff contains any changes.

# `diff`

```elixir
@spec diff(map(), map()) :: diff_result()
```

Compute the diff between two maps.

Returns a map with `:added`, `:removed`, and `:changed` keys.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
