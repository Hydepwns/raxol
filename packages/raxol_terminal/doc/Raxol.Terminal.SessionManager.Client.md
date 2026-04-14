# `Raxol.Terminal.SessionManager.Client`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/session_manager/types.ex#L114)

Client connection to a session.

Represents a client connected to a terminal session, tracking connection
type, activity, terminal size, and capabilities.

# `connection_type`

```elixir
@type connection_type() :: :local | :remote | :shared
```

# `t`

```elixir
@type t() :: %Raxol.Terminal.SessionManager.Client{
  capabilities: [atom()],
  connected_at: integer(),
  connection_type: connection_type(),
  id: String.t(),
  last_activity: integer(),
  metadata: map(),
  session_id: String.t(),
  terminal_size: {integer(), integer()}
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
