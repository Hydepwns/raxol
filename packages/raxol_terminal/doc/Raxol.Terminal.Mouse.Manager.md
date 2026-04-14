# `Raxol.Terminal.Mouse.Manager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/mouse/mouse_manager.ex#L1)

Manages mouse events and tracking in the terminal, including button clicks,
movement, and wheel events.

# `button_state`

```elixir
@type button_state() :: :none | :left | :middle | :right | :wheel_up | :wheel_down
```

# `mouse_mode`

```elixir
@type mouse_mode() :: :normal | :button_event | :any_event | :highlight_tracking
```

# `position`

```elixir
@type position() :: {non_neg_integer(), non_neg_integer()}
```

# `t`

```elixir
@type t() :: %Raxol.Terminal.Mouse.Manager{
  button_state: button_state(),
  cell_motion_tracking: boolean(),
  enabled: boolean(),
  highlight_tracking: boolean(),
  last_position: position() | nil,
  mode: mouse_mode(),
  pixel_position_tracking: boolean(),
  sgr_mode: boolean(),
  tracking_enabled: boolean(),
  urxvt_mode: boolean()
}
```

# `disable`

Disables mouse tracking.

# `disable_cell_motion_tracking`

Disables cell motion tracking.

# `disable_highlight_tracking`

Disables highlight tracking.

# `disable_pixel_position_tracking`

Disables pixel position tracking.

# `disable_sgr_mode`

Disables SGR mode.

# `disable_urxvt_mode`

Disables URXVT mode.

# `enable`

Enables mouse tracking.

# `enable_cell_motion_tracking`

Enables cell motion tracking.

# `enable_highlight_tracking`

Enables highlight tracking.

# `enable_pixel_position_tracking`

Enables pixel position tracking.

# `enable_sgr_mode`

Enables SGR mode.

# `enable_urxvt_mode`

Enables URXVT mode.

# `enabled?`

Checks if mouse tracking is enabled.

# `get_button_state`

Gets the current button state.

# `get_mode`

Gets the current mouse tracking mode.

# `get_position`

Gets the last known mouse position.

# `new`

Creates a new mouse manager instance.

# `reset`

Resets the mouse manager to its initial state.

# `set_button_state`

Updates the button state.

# `set_mode`

Sets the mouse tracking mode.

# `set_position`

Updates the last known mouse position.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
