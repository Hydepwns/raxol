# `Raxol.MCP.ContextTree`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/mcp/context_tree.ex#L1)

Assembles a structured context tree from multiple sources.

The context tree provides a unified view of session state for AI agents.
Different sources contribute subtrees (model projections, widget tree,
tools, agents, notifications). Built on demand -- no cached state.

## Sources

- `:model` -- TEA model projections from registered resources
- `:widgets` -- current widget tree (types, IDs, bounds)
- `:tools` -- list of available MCP tools
- `:session` -- session metadata (id, uptime)

## Roles

`filter_for_role/2` restricts the tree based on a role atom:

- `:full` -- everything (default)
- `:observer` -- model + widgets + session (no tools)
- `:operator` -- model + widgets + tools + session

# `context`

```elixir
@type context() :: %{
  registry: GenServer.server(),
  session_id: term(),
  view_tree: map() | list() | nil,
  model: map() | nil
}
```

# `role`

```elixir
@type role() :: :full | :observer | :operator
```

# `source`

```elixir
@type source() :: :model | :widgets | :tools | :session
```

# `build`

```elixir
@spec build([source()], context()) :: map()
```

Build a context tree from the given sources.

The `context` map must include `:registry` and `:session_id`.
Optional keys: `:view_tree`, `:model`.

# `build_all`

```elixir
@spec build_all(context()) :: map()
```

Build a full context tree with all sources.

# `filter_for_role`

```elixir
@spec filter_for_role(map(), role()) :: map()
```

Filter a context tree for a given role.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
