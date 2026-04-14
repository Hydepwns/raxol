# `Raxol.Terminal.SessionManager.Pane`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/session_manager/types.ex#L79)

Terminal pane within a window.

Represents an individual pane/split within a window, containing
a terminal process and configuration.

# `t`

```elixir
@type t() :: %Raxol.Terminal.SessionManager.Pane{
  command: String.t() | nil,
  created_at: integer(),
  environment: map(),
  id: String.t(),
  position: {integer(), integer()},
  size: {integer(), integer()},
  status: :running | :stopped | :finished,
  terminal: pid(),
  window_id: String.t(),
  working_directory: String.t()
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
