# `Raxol.Terminal.Colors`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/colors.ex#L1)

Manages terminal colors and color-related operations.

# `color`

```elixir
@type color() :: String.t()
```

# `t`

```elixir
@type t() :: %Raxol.Terminal.Colors{
  background: color(),
  cursor_color: color(),
  foreground: color(),
  selection_background: color(),
  selection_foreground: color()
}
```

# `get_background`

```elixir
@spec get_background(t()) :: color()
```

Gets the current background color.

# `get_cursor_color`

```elixir
@spec get_cursor_color(t()) :: color()
```

Gets the current cursor color.

# `get_foreground`

```elixir
@spec get_foreground(t()) :: color()
```

Gets the current foreground color.

# `get_selection_background`

```elixir
@spec get_selection_background(t()) :: color()
```

Gets the current selection background color.

# `get_selection_foreground`

```elixir
@spec get_selection_foreground(t()) :: color()
```

Gets the current selection foreground color.

# `reset_background`

```elixir
@spec reset_background(t()) :: {:ok, t()}
```

Resets the background color to default.

# `reset_cursor_color`

```elixir
@spec reset_cursor_color(t()) :: {:ok, t()}
```

Resets the cursor color to default.

# `reset_foreground`

```elixir
@spec reset_foreground(t()) :: {:ok, t()}
```

Resets the foreground color to default.

# `reset_selection_background`

```elixir
@spec reset_selection_background(t()) :: {:ok, t()}
```

Resets the selection background color to default.

# `reset_selection_foreground`

```elixir
@spec reset_selection_foreground(t()) :: {:ok, t()}
```

Resets the selection foreground color to default.

# `set_background`

```elixir
@spec set_background(t(), color()) :: t()
```

Sets the background color.

# `set_cursor_color`

```elixir
@spec set_cursor_color(t(), color()) :: t()
```

Sets the cursor color.

# `set_foreground`

```elixir
@spec set_foreground(t(), color()) :: t()
```

Sets the foreground color.

# `set_selection_background`

```elixir
@spec set_selection_background(t(), color()) :: t()
```

Sets the selection background color.

# `set_selection_foreground`

```elixir
@spec set_selection_foreground(t(), color()) :: t()
```

Sets the selection foreground color.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
