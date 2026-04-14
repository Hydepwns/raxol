# `Raxol.Terminal.Input.MouseHandler`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/input/mouse_handler.ex#L1)

Comprehensive mouse event handling for terminal applications.

Supports multiple mouse protocols:
- X10: Original mouse tracking (button press only)
- X11: Mouse tracking with button release
- SGR: Extended mouse protocol with precise coordinates
- URXVT: Extended protocol variant

## Features

- Button press/release detection
- Mouse movement tracking
- Scroll wheel support
- Drag operations
- Multi-button chord detection
- High-precision coordinate reporting (SGR mode)

## Usage

    # Parse a mouse event sequence
    MouseHandler.parse_mouse_event("[<0;10;20M")
    {:ok, %{type: :press, button: :left, x: 10, y: 20}}

    # Enable mouse tracking
    MouseHandler.enable_mouse_tracking(:sgr)

    # Handle mouse event
    MouseHandler.handle_event(state, event)

# `button`

```elixir
@type button() ::
  :left
  | :middle
  | :right
  | :wheel_up
  | :wheel_down
  | :button4
  | :button5
  | :button6
  | :button7
  | :button8
  | :button9
  | :button10
  | :button11
```

# `event_type`

```elixir
@type event_type() :: :press | :release | :move | :drag | :scroll
```

# `mouse_event`

```elixir
@type mouse_event() :: %{
  type: event_type(),
  button: button() | nil,
  x: non_neg_integer(),
  y: non_neg_integer(),
  modifiers: map(),
  protocol: atom(),
  timestamp: non_neg_integer()
}
```

# `mouse_mode`

```elixir
@type mouse_mode() :: :off | :x10 | :x11 | :button_event | :any_event | :sgr | :urxvt
```

# `state`

```elixir
@type state() :: %{
  mode: mouse_mode(),
  pressed_buttons: MapSet.t(button()),
  last_position: {non_neg_integer(), non_neg_integer()} | nil,
  drag_start: {non_neg_integer(), non_neg_integer()} | nil,
  click_count: non_neg_integer(),
  last_click_time: non_neg_integer() | nil,
  double_click_threshold: non_neg_integer()
}
```

# `detect_best_mode`

Returns the optimal mouse mode for the current terminal.

Detects terminal capabilities and returns the best supported mode.

# `disable_mouse_tracking`

Disables all mouse tracking modes.

# `enable_mouse_tracking`

Enables mouse tracking with the specified mode.

Returns the escape sequence to send to the terminal.

# `handle_event`

Processes a mouse event and updates the handler state.

Tracks button states, detects drag operations, and counts clicks.

# `new`

Creates a new mouse handler state.

# `parse_mouse_event`

Parses a mouse event sequence from terminal input.

Automatically detects the protocol used and returns a parsed event.

# `set_mouse_mode`

Generates control sequences to set mouse reporting modes.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
