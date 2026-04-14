# `Raxol.Terminal.StyleBuffer`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/style_buffer.ex#L1)

Manages terminal style state and operations.
This module handles text attributes, colors, and formatting for terminal output.

# `position`

```elixir
@type position() :: {non_neg_integer(), non_neg_integer()}
```

# `region`

```elixir
@type region() :: {position(), position()}
```

# `style`

```elixir
@type style() :: %{
  foreground: String.t() | nil,
  background: String.t() | nil,
  bold: boolean(),
  italic: boolean(),
  underline: boolean(),
  attributes: [atom()]
}
```

# `t`

```elixir
@type t() :: %Raxol.Terminal.StyleBuffer{
  current_style: style(),
  default_style: style(),
  height: non_neg_integer(),
  style_map: %{required(position()) =&gt; style()},
  width: non_neg_integer()
}
```

# `apply_style_to_region`

```elixir
@spec apply_style_to_region(
  t(),
  style(),
  {non_neg_integer(), non_neg_integer()},
  {non_neg_integer(), non_neg_integer()}
) :: t()
```

Applies a style to a rectangular region.

# `get_default_style`

```elixir
@spec get_default_style(t()) :: style()
```

Gets the default style.

# `get_style`

```elixir
@spec get_style(t()) :: style()
```

Gets the current style.

# `get_style_at`

```elixir
@spec get_style_at(t(), non_neg_integer(), non_neg_integer()) :: style()
```

Gets the style at a specific position (x, y).
Returns the style at the position or the current style if not set.

# `merge_styles`

```elixir
@spec merge_styles(style(), style()) :: style()
```

Merges two styles.

# `new`

```elixir
@spec new(non_neg_integer(), non_neg_integer()) :: t()
```

Creates a new style buffer with the given dimensions.

# `reset_style`

```elixir
@spec reset_style(t()) :: t()
```

Resets the style to default.

# `set_attributes`

```elixir
@spec set_attributes(t(), [atom()]) :: t()
```

Sets text attributes (list of atoms).

# `set_background`

```elixir
@spec set_background(t(), String.t()) :: t()
```

Sets the background color.

# `set_default_style`

```elixir
@spec set_default_style(t(), style()) :: t()
```

Sets the default style.

# `set_foreground`

```elixir
@spec set_foreground(t(), String.t()) :: t()
```

Sets the foreground color.

# `validate_style`

```elixir
@spec validate_style(style()) :: :ok | {:error, String.t()}
```

Validates a style map.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
