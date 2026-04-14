# `Raxol.Terminal.Mouse.MouseServer`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/mouse/mouse_server.ex#L1)

Provides unified mouse handling functionality for the terminal emulator.
This module handles mouse events, tracking, and state management.

# `mouse_button`

```elixir
@type mouse_button() :: :left | :middle | :right | :wheel_up | :wheel_down
```

# `mouse_config`

```elixir
@type mouse_config() :: %{
  optional(:tracking) =&gt; boolean(),
  optional(:reporting) =&gt; boolean(),
  optional(:sgr_mode) =&gt; boolean(),
  optional(:urxvt_mode) =&gt; boolean(),
  optional(:pixel_mode) =&gt; boolean()
}
```

# `mouse_event`

```elixir
@type mouse_event() :: :press | :release | :move | :drag | :click | :double_click
```

# `mouse_id`

```elixir
@type mouse_id() :: non_neg_integer()
```

# `mouse_modifier`

```elixir
@type mouse_modifier() :: :shift | :ctrl | :alt | :meta
```

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `cleanup`

```elixir
@spec cleanup() :: :ok
```

Cleans up resources.

# `close_mouse`

```elixir
@spec close_mouse(mouse_id()) :: :ok | {:error, term()}
```

Closes a mouse context.

# `create_mouse`

```elixir
@spec create_mouse(map()) :: {:ok, mouse_id()} | {:error, term()}
```

Creates a new mouse context with the given configuration.

# `get_active_mouse`

```elixir
@spec get_active_mouse() :: {:ok, mouse_id()} | {:error, :no_active_mouse}
```

Gets the active mouse context ID.

# `get_mice`

```elixir
@spec get_mice() :: [mouse_id()]
```

Gets the list of all mouse contexts.

# `get_mouse_button_state`

```elixir
@spec get_mouse_button_state(mouse_id()) :: {:ok, [mouse_button()]} | {:error, term()}
```

Gets the current mouse button state.

# `get_mouse_position`

```elixir
@spec get_mouse_position(mouse_id()) ::
  {:ok, {integer(), integer()}} | {:error, term()}
```

Gets the current mouse position.

# `get_mouse_state`

```elixir
@spec get_mouse_state(mouse_id()) :: {:ok, map()} | {:error, term()}
```

Gets the state of a specific mouse context.

# `handle_manager_cast`

# `handle_manager_info`

# `process_mouse_event`

```elixir
@spec process_mouse_event(mouse_id(), map()) :: :ok | {:error, term()}
```

Processes a mouse event from an event map.
The event map should contain: button, action, modifiers, x, y

# `process_mouse_event`

```elixir
@spec process_mouse_event(
  mouse_id(),
  mouse_event(),
  mouse_button(),
  {integer(), integer()},
  [mouse_modifier()]
) :: :ok | {:error, term()}
```

Processes a mouse event.

# `set_active_mouse`

```elixir
@spec set_active_mouse(mouse_id()) :: :ok | {:error, term()}
```

Sets the active mouse context.

# `start_link`

# `update_config`

```elixir
@spec update_config(map()) :: :ok
```

Updates the mouse manager configuration.

# `update_mouse_config`

```elixir
@spec update_mouse_config(mouse_id(), mouse_config()) :: :ok | {:error, term()}
```

Updates the configuration of a specific mouse context.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
