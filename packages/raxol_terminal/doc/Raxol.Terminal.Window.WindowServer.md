# `Raxol.Terminal.Window.WindowServer`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/window/window_server.ex#L1)

A unified window manager for terminal applications.

This module provides a GenServer-based window management system that handles
window creation, splitting, resizing, and other window operations.

# `state`

```elixir
@type state() :: %{
  windows: %{required(window_id()) =&gt; window_state()},
  active_window: window_id() | nil,
  next_id: non_neg_integer(),
  config: %{
    default_size: {non_neg_integer(), non_neg_integer()},
    max_size: {non_neg_integer(), non_neg_integer()},
    default_buffer_id: String.t() | nil,
    default_renderer_id: String.t() | nil
  }
}
```

# `t`

```elixir
@type t() :: window_state()
```

# `window_id`

```elixir
@type window_id() :: non_neg_integer()
```

# `window_state`

```elixir
@type window_state() :: %{
  id: window_id(),
  title: String.t() | nil,
  icon_name: String.t() | nil,
  size: {non_neg_integer(), non_neg_integer()},
  position: {non_neg_integer(), non_neg_integer()},
  maximized: boolean(),
  iconified: boolean(),
  previous_size: {non_neg_integer(), non_neg_integer()} | nil,
  stacking_order: :normal | :above | :below,
  parent_id: window_id() | nil,
  children: [window_id()],
  split_type: :horizontal | :vertical | :none,
  buffer_id: String.t() | nil,
  renderer_id: String.t() | nil
}
```

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `cleanup`

# `close_window`

# `create_window`

# `get_active_window`

# `get_window_state`

# `handle_manager_cast`

# `handle_manager_info`

# `move`

# `resize`

# `set_active_window`

# `set_icon_name`

# `set_maximized`

# `set_stacking_order`

# `set_title`

# `split_window`

# `start_link`

# `update_config`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
