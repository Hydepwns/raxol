# `Raxol.Terminal.Modes.Handlers.DECPrivateHandler`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/modes/handlers/dec_private_handler.ex#L1)

Handles DEC Private mode operations and their side effects.
Manages the implementation of DEC private mode changes and their effects on the terminal.

# `handle_alt_screen`

# `handle_alt_screen_buffer`

# `handle_alt_screen_save`

# `handle_auto_repeat_mode`

# `handle_auto_wrap_mode`

# `handle_bracketed_paste`

# `handle_column_width_mode`

# `handle_column_width_mode_normal`

# `handle_column_width_mode_wide`

# `handle_cursor_keys_mode`

# `handle_cursor_save_restore`

# `handle_cursor_visibility`

# `handle_focus_events`

# `handle_interlace_mode`

# `handle_mode`

```elixir
@spec handle_mode(
  Raxol.Terminal.Emulator.t(),
  atom(),
  Raxol.Terminal.Modes.Types.ModeTypes.mode_value()
) :: {:ok, Raxol.Terminal.Emulator.t()} | {:error, term()}
```

Handles a DEC private mode change (alias for handle_mode_change/3 for compatibility).

# `handle_mode_change`

```elixir
@spec handle_mode_change(
  atom(),
  Raxol.Terminal.Modes.Types.ModeTypes.mode_value(),
  Raxol.Terminal.Emulator.t()
) :: {:ok, Raxol.Terminal.Emulator.t()} | {:error, term()}
```

Handles a DEC private mode change and applies its effects to the emulator.

# `handle_mouse_report_cell_motion`

# `handle_mouse_report_sgr`

# `handle_mouse_report_x10`

# `handle_origin_mode`

# `handle_screen_mode`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
