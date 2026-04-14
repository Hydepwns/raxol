# `Raxol.Terminal.SessionManager.Window`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/session_manager/types.ex#L40)

Terminal window within a session.

Represents an individual window/pane within a terminal session,
containing an emulator and associated metadata.

# `layout_type`

```elixir
@type layout_type() ::
  :main_horizontal | :main_vertical | :even_horizontal | :even_vertical | :tiled
```

# `t`

```elixir
@type t() :: %Raxol.Terminal.SessionManager.Window{
  active_pane: String.t() | nil,
  created_at: integer(),
  id: String.t(),
  layout: layout_type(),
  metadata: map(),
  name: String.t(),
  panes: [term()],
  session_id: String.t(),
  status: :active | :inactive
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
