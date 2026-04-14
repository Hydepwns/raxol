# `Raxol.Terminal.Commands.CSIHandler`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/commands/csi_handler.ex#L1)

Handlers for CSI (Control Sequence Introducer) commands.
This is a simplified version that delegates to the available handler modules.

# `handle_basic_command`

# `handle_bracketed_paste_end`

# `handle_bracketed_paste_start`

# `handle_csi_sequence`

# `handle_cursor_backward`

# `handle_cursor_column`

# `handle_cursor_command`

# `handle_cursor_down`

# `handle_cursor_forward`

# `handle_cursor_movement`

```elixir
@spec handle_cursor_movement(Raxol.Terminal.Emulator.t(), [integer()]) ::
  {:ok, Raxol.Terminal.Emulator.t()}
```

Handles cursor movement based on the command byte.
Returns `{:ok, emulator}` with the updated emulator struct.

# `handle_cursor_position`

# `handle_cursor_position`

# `handle_cursor_position_direct`

# `handle_cursor_up`

# `handle_deiconify`

# `handle_erase_display`

# `handle_erase_line`

# `handle_h_or_l`

# `handle_icon_name`

# `handle_icon_title`

# `handle_iconify`

# `handle_locking_shift`

Handles locking shift operations for character sets.

# `handle_lower`

# `handle_mode_change`

# `handle_q_deccusr`

# `handle_r`

# `handle_raise`

# `handle_s`

# `handle_screen_command`

# `handle_scroll_down`

# `handle_scroll_up`

# `handle_scs`

# `handle_single_shift`

Handles single shift operations for character sets.

# `handle_text_attributes`

# `handle_u`

# `handle_window_title`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
