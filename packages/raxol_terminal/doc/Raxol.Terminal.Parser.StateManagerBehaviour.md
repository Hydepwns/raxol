# `Raxol.Terminal.Parser.StateManagerBehaviour`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/parser/state_manager_behaviour.ex#L1)

Behaviour for terminal parser state management.

# `t`

```elixir
@type t() :: term()
```

# `get_charset_state`

```elixir
@callback get_charset_state(t()) :: map()
```

# `get_last_col_exceeded`

```elixir
@callback get_last_col_exceeded(t()) :: boolean()
```

# `get_mode_manager`

```elixir
@callback get_mode_manager(t()) :: map()
```

# `get_scroll_region`

```elixir
@callback get_scroll_region(t()) :: map()
```

# `get_state`

```elixir
@callback get_state(Raxol.Terminal.Emulator.Struct.t()) ::
  Raxol.Terminal.Parser.ParserState.t()
```

# `get_state_name`

```elixir
@callback get_state_name(Raxol.Terminal.Emulator.Struct.t()) :: atom()
```

# `get_state_stack`

```elixir
@callback get_state_stack(t()) :: list()
```

# `in_control_sequence_state?`

```elixir
@callback in_control_sequence_state?(Raxol.Terminal.Emulator.Struct.t()) :: boolean()
```

# `in_escape_state?`

```elixir
@callback in_escape_state?(Raxol.Terminal.Emulator.Struct.t()) :: boolean()
```

# `in_ground_state?`

```elixir
@callback in_ground_state?(Raxol.Terminal.Emulator.Struct.t()) :: boolean()
```

# `new`

```elixir
@callback new() :: Raxol.Terminal.Parser.ParserState.t()
```

# `reset_to_ground`

```elixir
@callback reset_to_ground(Raxol.Terminal.Emulator.Struct.t()) ::
  Raxol.Terminal.Emulator.Struct.t()
```

# `reset_to_initial_state`

```elixir
@callback reset_to_initial_state(t()) :: t()
```

# `set_state_name`

```elixir
@callback set_state_name(Raxol.Terminal.Emulator.Struct.t(), atom()) ::
  Raxol.Terminal.Emulator.Struct.t()
```

# `update_charset_state`

```elixir
@callback update_charset_state(t(), map()) :: t()
```

# `update_last_col_exceeded`

```elixir
@callback update_last_col_exceeded(t(), boolean()) :: t()
```

# `update_mode_manager`

```elixir
@callback update_mode_manager(t(), map()) :: t()
```

# `update_scroll_region`

```elixir
@callback update_scroll_region(t(), map()) :: t()
```

# `update_state`

```elixir
@callback update_state(
  Raxol.Terminal.Emulator.Struct.t(),
  Raxol.Terminal.Parser.ParserState.t()
) ::
  Raxol.Terminal.Emulator.Struct.t()
```

# `update_state_stack`

```elixir
@callback update_state_stack(t(), list()) :: t()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
