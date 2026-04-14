# `Raxol.Terminal.ANSI.Window`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/ansi/window.ex#L1)

Consolidated window handling for the terminal emulator.
Combines WindowEvents and WindowManipulation functionality.
Supports window events, resizing, positioning, and state management.

# `window_border_style`

```elixir
@type window_border_style() :: :none | :single | :double | :rounded | :custom
```

# `window_event`

```elixir
@type window_event() :: {:window_event, window_event_type(), map()}
```

# `window_event_type`

```elixir
@type window_event_type() ::
  :close
  | :minimize
  | :maximize
  | :restore
  | :focus
  | :blur
  | :move
  | :resize
  | :state_change
  | :show
  | :hide
  | :activate
  | :deactivate
  | :drag_start
  | :drag_end
  | :drop
```

# `window_position`

```elixir
@type window_position() :: {non_neg_integer(), non_neg_integer()}
```

# `window_size`

```elixir
@type window_size() :: {non_neg_integer(), non_neg_integer()}
```

# `window_state`

```elixir
@type window_state() :: :normal | :minimized | :maximized | :fullscreen
```

# `clear_screen`

# `disable_window_events`

# `disable_window_manipulation`

# `enable_window_events`

# `enable_window_manipulation`

# `format_event`

# `format_move`

# `format_resize`

# `format_title`

# `move_cursor`

# `new`

# `process_sequence`

# `process_window_event`

# `set_position`

# `set_title`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
