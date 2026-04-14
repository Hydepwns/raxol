# `Raxol.MCP.Test.Session`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/mcp/test/session.ex#L1)

Struct representing a test session for MCP testing.

Holds references to the session ID, registry, and configuration.
All mutable state lives in the Headless GenServer and Registry ETS tables.

# `t`

```elixir
@type t() :: %Raxol.MCP.Test.Session{
  id: atom(),
  module: module() | String.t(),
  registry: GenServer.server(),
  registry_pid: pid(),
  settle_ms: non_neg_integer()
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
