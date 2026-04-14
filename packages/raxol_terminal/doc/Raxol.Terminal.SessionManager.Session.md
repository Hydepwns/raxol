# `Raxol.Terminal.SessionManager.Session`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/session_manager/types.ex#L1)

Terminal session structure.

Represents a terminal multiplexing session with multiple windows, clients,
and lifecycle management.

# `t`

```elixir
@type t() :: %Raxol.Terminal.SessionManager.Session{
  active_window: String.t() | nil,
  clients: [term()],
  created_at: integer(),
  hooks: map(),
  id: String.t(),
  last_activity: integer(),
  metadata: map(),
  name: String.t(),
  persistence_config: map(),
  resource_limits: map(),
  status: :active | :inactive | :detached,
  windows: [term()]
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
