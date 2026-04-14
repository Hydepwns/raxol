# `Raxol.Terminal.ANSI.SequenceHandler`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/ansi/sequence_handler.ex#L1)

Handles parsing and processing of ANSI escape sequences.
This module extracts the ANSI sequence parsing logic from the main emulator.

# `parse_ansi_sequence`

```elixir
@spec parse_ansi_sequence(binary()) :: {:incomplete, nil} | tuple()
```

Parses ANSI sequences from input and returns the parsed result.

# `parse_csi_clear_line`

```elixir
@spec parse_csi_clear_line(binary()) :: {:csi_clear_line, binary(), nil} | nil
```

Parses CSI clear line sequences.

# `parse_csi_clear_screen`

```elixir
@spec parse_csi_clear_screen(binary()) :: {:csi_clear_screen, binary(), nil} | nil
```

Parses CSI clear screen sequences.

# `parse_csi_cursor_back`

```elixir
@spec parse_csi_cursor_back(binary()) ::
  {:csi_cursor_back, binary(), binary(), nil} | nil
```

Parses CSI cursor back sequences.

# `parse_csi_cursor_down`

```elixir
@spec parse_csi_cursor_down(binary()) ::
  {:csi_cursor_down, binary(), binary(), nil} | nil
```

Parses CSI cursor down sequences.

# `parse_csi_cursor_forward`

```elixir
@spec parse_csi_cursor_forward(binary()) ::
  {:csi_cursor_forward, binary(), binary(), nil} | nil
```

Parses CSI cursor forward sequences.

# `parse_csi_cursor_hide`

```elixir
@spec parse_csi_cursor_hide(binary()) :: {:csi_cursor_hide, binary(), nil} | nil
```

Parses CSI cursor hide sequences.

# `parse_csi_cursor_pos`

```elixir
@spec parse_csi_cursor_pos(binary()) ::
  {:csi_cursor_pos, binary(), binary(), nil} | nil
```

Parses CSI cursor position sequences.

# `parse_csi_cursor_show`

```elixir
@spec parse_csi_cursor_show(binary()) :: {:csi_cursor_show, binary(), nil} | nil
```

Parses CSI cursor show sequences.

# `parse_csi_cursor_up`

```elixir
@spec parse_csi_cursor_up(binary()) :: {:csi_cursor_up, binary(), binary(), nil} | nil
```

Parses CSI cursor up sequences.

# `parse_csi_general`

```elixir
@spec parse_csi_general(binary()) ::
  {:csi_general, binary(), binary(), binary(), binary()} | nil
```

Parses CSI general sequences.

# `parse_csi_reset_mode`

```elixir
@spec parse_csi_reset_mode(binary()) ::
  {:csi_reset_mode, binary(), binary(), nil} | nil
```

Parses CSI reset mode sequences.

# `parse_csi_reset_standard_mode`

```elixir
@spec parse_csi_reset_standard_mode(binary()) ::
  {:csi_reset_standard_mode, binary(), binary(), nil} | nil
```

Parses CSI reset standard mode sequences.

# `parse_csi_set_mode`

```elixir
@spec parse_csi_set_mode(binary()) :: {:csi_set_mode, binary(), binary(), nil} | nil
```

Parses CSI set mode sequences.

# `parse_csi_set_scroll_region`

```elixir
@spec parse_csi_set_scroll_region(binary()) ::
  {:csi_set_scroll_region, binary(), binary(), nil} | nil
```

Parses CSI set scroll region sequences.

# `parse_csi_set_standard_mode`

```elixir
@spec parse_csi_set_standard_mode(binary()) ::
  {:csi_set_standard_mode, binary(), binary(), nil} | nil
```

Parses CSI set standard mode sequences.

# `parse_dcs`

```elixir
@spec parse_dcs(binary()) :: {:dcs, binary(), nil} | nil
```

Parses DCS (Device Control String) sequences.

# `parse_esc_equals`

```elixir
@spec parse_esc_equals(binary()) :: {:esc_equals, binary(), nil} | nil
```

Parses ESC equals sequences.

# `parse_esc_greater`

```elixir
@spec parse_esc_greater(binary()) :: {:esc_greater, binary(), nil} | nil
```

Parses ESC greater than sequences.

# `parse_mouse_event`

```elixir
@spec parse_mouse_event(binary()) :: {:mouse_event, binary(), binary(), nil} | nil
```

Parses mouse event sequences in the format ESC[M<button><x><y>.

# `parse_osc`

```elixir
@spec parse_osc(binary()) :: {:osc, binary(), nil} | nil
```

Parses OSC (Operating System Command) sequences.

# `parse_sgr`

```elixir
@spec parse_sgr(binary()) :: {:sgr, binary(), binary(), nil} | nil
```

Parses SGR (Select Graphic Rendition) sequences.

# `parse_unknown`

```elixir
@spec parse_unknown(binary()) :: {:unknown, binary(), nil} | nil
```

Parses unknown escape sequences.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
