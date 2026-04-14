# `Raxol.Terminal.ANSI.Mouse`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/ansi/mouse.ex#L1)

Consolidated mouse handling for the terminal emulator.
Combines MouseEvents and MouseTracking functionality.
Supports various mouse tracking modes and event reporting.

# `focus_event`

```elixir
@type focus_event() :: :focus_in | :focus_out
```

# `modifier`

```elixir
@type modifier() :: :shift | :alt | :ctrl | :meta
```

# `mouse_action`

```elixir
@type mouse_action() :: :press | :release | :move | :drag
```

# `mouse_button`

```elixir
@type mouse_button() ::
  :left | :middle | :right | :wheel_up | :wheel_down | :release | :none
```

# `mouse_event`

```elixir
@type mouse_event() :: {mouse_button(), mouse_action(), integer(), integer()}
```

# `mouse_mode`

```elixir
@type mouse_mode() ::
  :basic
  | :normal
  | :highlight
  | :cell
  | :button
  | :all
  | :any
  | :focus
  | :utf8
  | :sgr
  | :urxvt
  | :sgr_pixels
```

# `mouse_state`

```elixir
@type mouse_state() :: %{
  enabled: boolean(),
  mode: mouse_mode(),
  button_state: mouse_button(),
  modifiers: MapSet.t(modifier()),
  position: {integer(), integer()},
  last_position: {integer(), integer()},
  drag_state: :none | :dragging | :drag_end
}
```

# `decode_button`

# `decode_modifiers`

# `disable`

# `disable_mouse_tracking`

# `enable`

# `enable_mouse_tracking`

# `format_focus_event`

# `format_mouse_event`

# `generate_report`

# `new`

# `parse_focus_sequence`

# `parse_mouse_sequence`

# `process_event`

# `update_button_state`

# `update_position`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
