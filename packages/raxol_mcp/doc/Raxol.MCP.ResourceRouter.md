# `Raxol.MCP.ResourceRouter`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/mcp/resource_router.ex#L1)

Routes `raxol://` resource URIs to the appropriate data source.

Parses structured URIs and dispatches to the Registry for registered
resources, or to well-known handlers for pattern-based URIs.

## URI Patterns

- `raxol://session/{id}/model/{key}` -- model projection
- `raxol://session/{id}/widgets` -- widget tree
- `raxol://session/{id}/tools` -- available tools
- `raxol://session/{id}/context` -- full context tree

# `parsed`

```elixir
@type parsed() :: %{scheme: String.t(), session: String.t(), path: [String.t()]}
```

# `parse`

```elixir
@spec parse(String.t()) :: {:ok, parsed()} | {:error, :invalid_uri}
```

Parse a `raxol://` URI into structured components.

Returns `{:ok, parsed}` or `{:error, :invalid_uri}`.

# `resolve`

```elixir
@spec resolve(GenServer.server(), String.t()) :: {:ok, term()} | {:error, term()}
```

Resolve a resource URI to its content.

First tries a direct Registry lookup (for explicitly registered resources).
Falls back to pattern-based resolution for well-known URI structures.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
