# `Raxol.Terminal.CharsetManager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/charset_manager.ex#L1)

Manages the terminal character sets.

# `t`

```elixir
@type t() :: %Raxol.Terminal.CharsetManager{
  designated_charsets: map(),
  g_set: atom(),
  single_shift: atom() | nil,
  state: map()
}
```

# `apply_single_shift`

```elixir
@spec apply_single_shift(t(), atom()) :: t()
```

Applies a single shift to the state.

Single shift temporarily invokes G2 or G3 for the next character only.
Valid shifts are :g2 (SS2) and :g3 (SS3).

# `clear_single_shift`

```elixir
@spec clear_single_shift(t()) :: t()
```

Clears the single shift after processing one character.

This should be called after processing a character when a single shift is active.

# `designate_charset`

```elixir
@spec designate_charset(t(), atom(), atom()) :: t()
```

Designates a charset for the given g-set.

# `get_current_g_set`

```elixir
@spec get_current_g_set(t()) :: atom()
```

Gets the current g-set.

# `get_designated_charset`

```elixir
@spec get_designated_charset(t(), atom()) :: atom()
```

Gets the designated charset for the given g-set.

# `get_single_shift`

```elixir
@spec get_single_shift(t()) :: atom() | nil
```

Gets the current single shift.

Returns the currently active single shift (:g2 or :g3), or nil if no single shift is active.

# `get_state`

```elixir
@spec get_state(t()) :: map()
```

Gets the current state.

# `invoke_g_set`

```elixir
@spec invoke_g_set(t(), atom()) :: t()
```

Invokes the given g-set.

# `reset_state`

```elixir
@spec reset_state(t()) :: t()
```

Resets the state to its initial values.

# `update_state`

```elixir
@spec update_state(t(), map()) :: t()
```

Updates the state.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
