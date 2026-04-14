# `Raxol.Terminal.EmulatorBehaviour`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/emulator_behaviour.ex#L1)

Defines the behaviour for the core Terminal Emulator.

This contract outlines the essential functions for managing terminal state,
processing input, and handling resizing.

# `t`

```elixir
@type t() :: map()
```

# `get_cursor_position`

```elixir
@callback get_cursor_position(emulator :: t()) :: {non_neg_integer(), non_neg_integer()}
```

Gets the current cursor position (0-based).

# `get_cursor_visible`

```elixir
@callback get_cursor_visible(emulator :: t()) :: boolean()
```

Gets the current cursor visibility state.

# `get_screen_buffer`

```elixir
@callback get_screen_buffer(emulator :: t()) :: map()
```

Returns the currently active screen buffer.

# `new`

```elixir
@callback new() :: t()
```

Creates a new emulator with default dimensions and options.

# `new`

```elixir
@callback new(width :: non_neg_integer(), height :: non_neg_integer()) :: t()
```

Creates a new emulator with specified dimensions and default options.

# `new`

```elixir
@callback new(
  width :: non_neg_integer(),
  height :: non_neg_integer(),
  opts :: keyword()
) :: t()
```

Creates a new emulator with specified dimensions and options.

# `new`

```elixir
@callback new(
  width :: non_neg_integer(),
  height :: non_neg_integer(),
  session_id :: any(),
  client_options :: map()
) :: {:ok, t()} | {:error, any()}
```

Creates a new emulator with specified dimensions, session ID, and client options.

# `process_input`

```elixir
@callback process_input(emulator :: t(), input :: String.t()) :: {t(), String.t()}
```

Processes input data (e.g., user typing, escape sequences).

# `resize`

```elixir
@callback resize(
  emulator :: t(),
  new_width :: non_neg_integer(),
  new_height :: non_neg_integer()
) :: t()
```

Resizes the emulator's screen buffers.

# `update_active_buffer`

```elixir
@callback update_active_buffer(
  emulator :: t(),
  new_buffer :: map()
) :: t()
```

Updates the currently active screen buffer in the emulator state.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
