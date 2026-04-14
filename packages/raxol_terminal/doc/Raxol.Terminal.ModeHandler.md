# `Raxol.Terminal.ModeHandler`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/mode_handler.ex#L1)

Handles terminal mode management functions.
This module extracts the mode handling logic from the main emulator.

# `mode_updates`

```elixir
@spec mode_updates() :: map()
```

Returns the mapping of mode names to their corresponding update functions.

# `update_alternate_buffer_active_direct`

```elixir
@spec update_alternate_buffer_active_direct(Raxol.Terminal.ModeManager.t(), boolean()) ::
  Raxol.Terminal.ModeManager.t()
```

Updates the alternate buffer active state in the mode manager.

# `update_auto_repeat_mode_direct`

```elixir
@spec update_auto_repeat_mode_direct(Raxol.Terminal.ModeManager.t(), boolean()) ::
  Raxol.Terminal.ModeManager.t()
```

Updates the auto repeat mode in the mode manager.

# `update_auto_wrap_direct`

```elixir
@spec update_auto_wrap_direct(Raxol.Terminal.ModeManager.t(), boolean()) ::
  Raxol.Terminal.ModeManager.t()
```

Updates the auto wrap mode in the mode manager.

# `update_bracketed_paste_mode_direct`

```elixir
@spec update_bracketed_paste_mode_direct(Raxol.Terminal.ModeManager.t(), boolean()) ::
  Raxol.Terminal.ModeManager.t()
```

Updates the bracketed paste mode in the mode manager.

# `update_column_width_80_direct`

```elixir
@spec update_column_width_80_direct(Raxol.Terminal.ModeManager.t(), boolean()) ::
  Raxol.Terminal.ModeManager.t()
```

Updates the column width 80 mode in the mode manager.

# `update_column_width_132_direct`

```elixir
@spec update_column_width_132_direct(Raxol.Terminal.ModeManager.t(), boolean()) ::
  Raxol.Terminal.ModeManager.t()
```

Updates the column width 132 mode in the mode manager.

# `update_cursor_keys_mode_direct`

```elixir
@spec update_cursor_keys_mode_direct(Raxol.Terminal.ModeManager.t(), boolean()) ::
  Raxol.Terminal.ModeManager.t()
```

Updates the cursor keys mode in the mode manager.

# `update_cursor_visible_direct`

```elixir
@spec update_cursor_visible_direct(Raxol.Terminal.ModeManager.t(), boolean()) ::
  Raxol.Terminal.ModeManager.t()
```

Updates the cursor visible mode in the mode manager.

# `update_insert_mode_direct`

```elixir
@spec update_insert_mode_direct(Raxol.Terminal.ModeManager.t(), boolean()) ::
  Raxol.Terminal.ModeManager.t()
```

Updates the insert mode in the mode manager.

# `update_interlacing_mode_direct`

```elixir
@spec update_interlacing_mode_direct(Raxol.Terminal.ModeManager.t(), boolean()) ::
  Raxol.Terminal.ModeManager.t()
```

Updates the interlacing mode in the mode manager.

# `update_line_feed_mode_direct`

```elixir
@spec update_line_feed_mode_direct(Raxol.Terminal.ModeManager.t(), boolean()) ::
  Raxol.Terminal.ModeManager.t()
```

Updates the line feed mode in the mode manager.

# `update_origin_mode_direct`

```elixir
@spec update_origin_mode_direct(Raxol.Terminal.ModeManager.t(), boolean()) ::
  Raxol.Terminal.ModeManager.t()
```

Updates the origin mode in the mode manager.

# `update_screen_mode_reverse_direct`

```elixir
@spec update_screen_mode_reverse_direct(Raxol.Terminal.ModeManager.t(), boolean()) ::
  Raxol.Terminal.ModeManager.t()
```

Updates the screen mode reverse in the mode manager.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
