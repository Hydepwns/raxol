# `Raxol.Terminal.State`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/terminal_state.ex#L1)

Provides state management for the terminal emulator.
This module handles operations like creating new states, saving and restoring states,
and managing state transitions.

# `cursor`

```elixir
@type cursor() :: %{
  position: {non_neg_integer(), non_neg_integer()},
  visible: boolean(),
  style: atom(),
  blink_state: boolean()
}
```

# `t`

```elixir
@type t() :: %{
  width: non_neg_integer(),
  height: non_neg_integer(),
  scrollback_limit: non_neg_integer(),
  memory_limit: non_neg_integer(),
  screen_buffer: Raxol.Terminal.ScreenBuffer.t(),
  cursor: cursor(),
  style: Raxol.Terminal.ANSI.TextFormatting.t(),
  scroll_region: term() | nil,
  saved_states: [map()]
}
```

# `get_cursor_position`

```elixir
@spec get_cursor_position(t()) :: {non_neg_integer(), non_neg_integer()}
```

Gets the current cursor position.

# `get_screen_buffer`

```elixir
@spec get_screen_buffer(t()) :: Raxol.Terminal.ScreenBuffer.t()
```

Gets the current screen buffer.

# `new`

```elixir
@spec new(
  non_neg_integer(),
  non_neg_integer(),
  non_neg_integer(),
  non_neg_integer()
) :: map()
```

Creates a new terminal state with the specified dimensions and limits.

# `restore_state`

```elixir
@spec restore_state(t()) :: {:ok, t()} | {:error, atom()}
```

Restores the most recently saved state.

# `save_state`

```elixir
@spec save_state(t()) :: t()
```

Saves the current state.

# `set_cursor_position`

```elixir
@spec set_cursor_position(t(), non_neg_integer(), non_neg_integer()) :: t()
```

Sets the cursor position.

# `set_screen_buffer`

```elixir
@spec set_screen_buffer(t(), Raxol.Terminal.ScreenBuffer.t()) :: t()
```

Sets the screen buffer.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
