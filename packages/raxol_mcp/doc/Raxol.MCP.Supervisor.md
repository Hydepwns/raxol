# `Raxol.MCP.Supervisor`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/mcp/supervisor.ex#L1)

Supervision tree for the MCP subsystem.

Starts the Registry and Server. The stdio transport is NOT started
automatically (it takes over stdin/stdout) -- use `mix mcp.server`
or start it explicitly.

## Children (rest_for_one)

1. `Raxol.MCP.Registry` -- ETS-backed tool/resource store
2. `Raxol.MCP.Server` -- transport-agnostic message router

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `start_link`

```elixir
@spec start_link(keyword()) :: Supervisor.on_start()
```

Start the MCP supervisor.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
