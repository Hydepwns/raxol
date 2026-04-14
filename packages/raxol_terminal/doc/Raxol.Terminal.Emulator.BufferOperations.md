# `Raxol.Terminal.Emulator.BufferOperations`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/emulator/buffer_operations.ex#L1)

Buffer operation functions extracted from the main emulator module.
Handles active buffer management and buffer switching operations.

# `emulator`

```elixir
@type emulator() :: map()
```

# `clear_entire_screen_and_scrollback`

Clears the entire screen and scrollback buffer.

# `clear_scrollback`

Clears the scrollback buffer.

# `get_screen_buffer`

```elixir
@spec get_screen_buffer(map()) :: map() | nil
```

Gets the active buffer from the emulator based on active_buffer_type.

# `switch_to_alternate_buffer`

Switches to the alternate screen buffer.

# `switch_to_alternate_screen`

Switches to the alternate screen buffer.

# `switch_to_main_buffer`

Switches to the main screen buffer.

# `switch_to_normal_screen`

Switches to the normal (main) screen buffer.

# `update_active_buffer`

```elixir
@spec update_active_buffer(emulator(), map()) :: emulator()
```

Updates the active buffer with new buffer data.

# `write_to_output`

Writes data to the output buffer.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
