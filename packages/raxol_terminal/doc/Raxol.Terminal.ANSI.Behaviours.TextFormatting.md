# `Raxol.Terminal.ANSI.Behaviours.TextFormatting`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/ansi/behaviours.ex#L99)

Defines the behaviour for text formatting in the terminal.
This includes handling text attributes, colors, and special text modes.

# `color`

```elixir
@type color() ::
  :black
  | :red
  | :green
  | :yellow
  | :blue
  | :magenta
  | :cyan
  | :white
  | {:rgb, non_neg_integer(), non_neg_integer(), non_neg_integer()}
  | {:index, non_neg_integer()}
  | nil
```

# `text_style`

```elixir
@type text_style() :: map()
```

# `apply_attribute`

```elixir
@callback apply_attribute(text_style(), atom()) :: text_style()
```

# `get_background`

```elixir
@callback get_background(text_style()) :: color()
```

# `get_foreground`

```elixir
@callback get_foreground(text_style()) :: color()
```

# `new`

```elixir
@callback new() :: text_style()
```

# `reset_attributes`

```elixir
@callback reset_attributes(text_style()) :: text_style()
```

# `reset_blink`

```elixir
@callback reset_blink(text_style()) :: text_style()
```

# `reset_bold`

```elixir
@callback reset_bold(text_style()) :: text_style()
```

# `reset_framed_encircled`

```elixir
@callback reset_framed_encircled(text_style()) :: text_style()
```

# `reset_italic`

```elixir
@callback reset_italic(text_style()) :: text_style()
```

# `reset_overlined`

```elixir
@callback reset_overlined(text_style()) :: text_style()
```

# `reset_reverse`

```elixir
@callback reset_reverse(text_style()) :: text_style()
```

# `reset_size`

```elixir
@callback reset_size(text_style()) :: text_style()
```

# `reset_underline`

```elixir
@callback reset_underline(text_style()) :: text_style()
```

# `set_attributes`

```elixir
@callback set_attributes(text_style(), [atom()]) :: text_style()
```

# `set_background`

```elixir
@callback set_background(text_style(), color()) :: text_style()
```

# `set_blink`

```elixir
@callback set_blink(text_style()) :: text_style()
```

# `set_bold`

```elixir
@callback set_bold(text_style()) :: text_style()
```

# `set_conceal`

```elixir
@callback set_conceal(text_style()) :: text_style()
```

# `set_custom`

```elixir
@callback set_custom(text_style(), atom(), any()) :: text_style()
```

# `set_double_height_bottom`

```elixir
@callback set_double_height_bottom(text_style()) :: text_style()
```

# `set_double_height_top`

```elixir
@callback set_double_height_top(text_style()) :: text_style()
```

# `set_double_underline`

```elixir
@callback set_double_underline(text_style()) :: text_style()
```

# `set_double_width`

```elixir
@callback set_double_width(text_style()) :: text_style()
```

# `set_encircled`

```elixir
@callback set_encircled(text_style()) :: text_style()
```

# `set_faint`

```elixir
@callback set_faint(text_style()) :: text_style()
```

# `set_foreground`

```elixir
@callback set_foreground(text_style(), color()) :: text_style()
```

# `set_fraktur`

```elixir
@callback set_fraktur(text_style()) :: text_style()
```

# `set_framed`

```elixir
@callback set_framed(text_style()) :: text_style()
```

# `set_hyperlink`

```elixir
@callback set_hyperlink(text_style(), String.t() | nil) :: text_style()
```

# `set_italic`

```elixir
@callback set_italic(text_style()) :: text_style()
```

# `set_overlined`

```elixir
@callback set_overlined(text_style()) :: text_style()
```

# `set_reverse`

```elixir
@callback set_reverse(text_style()) :: text_style()
```

# `set_strikethrough`

```elixir
@callback set_strikethrough(text_style()) :: text_style()
```

# `set_underline`

```elixir
@callback set_underline(text_style()) :: text_style()
```

# `update_attrs`

```elixir
@callback update_attrs(text_style(), map()) :: text_style()
```

# `validate`

```elixir
@callback validate(text_style()) :: {:ok, text_style()} | {:error, String.t()}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
