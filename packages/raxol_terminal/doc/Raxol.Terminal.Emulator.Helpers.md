# `Raxol.Terminal.Emulator.Helpers`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/emulator/helpers.ex#L1)

Utility and helper functions for the terminal emulator.
Extracted from the main emulator module for clarity and reuse.

# `get_config_struct`

```elixir
@spec get_config_struct(Raxol.Terminal.Emulator.t()) :: any()
```

# `get_cursor_position`

```elixir
@spec get_cursor_position(Raxol.Terminal.Emulator.t()) ::
  {non_neg_integer(), non_neg_integer()}
```

Gets the current cursor position.
Returns {row, col} for consistency with ANSI standards.

# `get_cursor_position_struct`

# `get_cursor_struct`

```elixir
@spec get_cursor_struct(Raxol.Terminal.Emulator.t()) :: Raxol.Terminal.Cursor.t()
```

Gets the cursor struct from the emulator.

# `get_cursor_struct_for_test`

# `get_cursor_visible_struct`

# `get_mode_manager_cursor_visible`

# `get_mode_manager_struct`

```elixir
@spec get_mode_manager_struct(Raxol.Terminal.Emulator.t()) :: any()
```

# `get_mode_manager_struct_for_test`

# `get_screen_buffer`

```elixir
@spec get_screen_buffer(Raxol.Terminal.Emulator.t()) ::
  Raxol.Terminal.ScreenBuffer.t()
```

Gets the active buffer from the emulator.

# `get_window_manager_struct`

```elixir
@spec get_window_manager_struct(Raxol.Terminal.Emulator.t()) :: any()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
