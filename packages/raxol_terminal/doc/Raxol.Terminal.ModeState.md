# `Raxol.Terminal.ModeState`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/mode_state.ex#L1)

Manages terminal mode state and transitions.

This module is responsible for:
- Managing mode state
- Handling mode transitions
- Validating mode changes
- Providing mode state queries

# `t`

```elixir
@type t() :: %Raxol.Terminal.ModeState{
  active_buffer_type: term(),
  alt_screen_mode: term(),
  alternate_buffer_active: term(),
  auto_repeat_mode: term(),
  auto_wrap: term(),
  bracketed_paste_mode: term(),
  column_width_mode: term(),
  cursor_keys_mode: term(),
  cursor_visible: term(),
  focus_events_enabled: term(),
  insert_mode: term(),
  interlacing_mode: term(),
  line_feed_mode: term(),
  mouse_report_mode: term(),
  origin_mode: term(),
  screen_mode_reverse: term()
}
```

# `lookup_private`

Looks up a DEC private mode code and returns the corresponding mode atom.

# `lookup_standard`

Looks up a standard mode code and returns the corresponding mode atom.

# `mode_enabled?`

Checks if a specific mode is enabled.

## Parameters
  * `state` - The current mode state
  * `mode` - The mode to check

## Returns
  * `boolean()` - Whether the mode is enabled

# `new`

Creates a new mode state with default values.

# `reset_alternate_buffer_mode`

Resets the alternate buffer mode.

## Parameters
  * `state` - The current mode state

## Returns
  * `t()` - The updated mode state

# `reset_mode`

Resets a mode to disabled state.

## Parameters
  * `state` - The current mode state
  * `mode` - The mode to disable

## Returns
  * `t()` - The updated mode state

# `set_alternate_buffer_mode`

Sets the alternate buffer mode.

## Parameters
  * `state` - The current mode state
  * `type` - The alternate buffer mode type

## Returns
  * `t()` - The updated mode state

# `set_mode`

Sets a mode to enabled state.

## Parameters
  * `state` - The current mode state
  * `mode` - The mode to enable

## Returns
  * `t()` - The updated mode state

---

*Consult [api-reference.md](api-reference.md) for complete listing*
