# `Raxol.Terminal.Style.Manager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/style/style_manager.ex#L1)

Manages text styling and formatting for the terminal emulator.
This module provides a clean interface for managing text styles, colors, and attributes.

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
@type text_style() :: %{
  background: color(),
  blink: boolean(),
  bold: boolean(),
  conceal: boolean(),
  double_height: :bottom | :none | :top,
  double_underline: boolean(),
  double_width: boolean(),
  encircled: boolean(),
  faint: boolean(),
  foreground: color(),
  fraktur: boolean(),
  framed: boolean(),
  hyperlink: nil | binary(),
  italic: boolean(),
  overlined: boolean(),
  reverse: boolean(),
  strikethrough: boolean(),
  underline: boolean()
}
```

# `ansi_code_to_color_name`

```elixir
@spec ansi_code_to_color_name(integer()) ::
  :black
  | :red
  | :green
  | :yellow
  | :blue
  | :magenta
  | :cyan
  | :white
  | :bright_black
  | :bright_red
  | :bright_green
  | :bright_yellow
  | :bright_blue
  | :bright_magenta
  | :bright_cyan
  | :bright_white
  | nil
```

Converts an ANSI color code to a color name.

# `apply_style`

```elixir
@spec apply_style(Raxol.Terminal.ANSI.TextFormatting.t(), atom()) ::
  Raxol.Terminal.ANSI.TextFormatting.t()
```

Applies a text attribute to the style.

# `effective_width`

```elixir
@spec effective_width(Raxol.Terminal.ANSI.TextFormatting.t(), String.t()) ::
  non_neg_integer()
```

Calculates the effective width of a character based on the current style.

# `format_sgr_params`

```elixir
@spec format_sgr_params(Raxol.Terminal.ANSI.TextFormatting.t()) :: String.t()
```

Formats SGR parameters for DECRQSS responses.

# `get_background`

```elixir
@spec get_background(Raxol.Terminal.ANSI.TextFormatting.t()) :: color()
```

Gets the background color.

# `get_current_style`

```elixir
@spec get_current_style(Raxol.Terminal.ANSI.TextFormatting.t()) ::
  Raxol.Terminal.ANSI.TextFormatting.t()
```

Gets the current style.

# `get_foreground`

```elixir
@spec get_foreground(Raxol.Terminal.ANSI.TextFormatting.t()) :: color()
```

Gets the foreground color.

# `get_hyperlink`

```elixir
@spec get_hyperlink(Raxol.Terminal.ANSI.TextFormatting.t()) :: String.t() | nil
```

Gets the hyperlink URI.

# `new`

```elixir
@spec new() :: Raxol.Terminal.ANSI.TextFormatting.t()
```

Creates a new text style with default values.

# `reset_size`

```elixir
@spec reset_size(Raxol.Terminal.ANSI.TextFormatting.t()) ::
  Raxol.Terminal.ANSI.TextFormatting.t()
```

Resets to single-width, single-height mode.

# `reset_style`

```elixir
@spec reset_style(Raxol.Terminal.ANSI.TextFormatting.t()) ::
  Raxol.Terminal.ANSI.TextFormatting.t()
```

Resets all text formatting attributes to their default values.

# `set_background`

```elixir
@spec set_background(Raxol.Terminal.ANSI.TextFormatting.t(), color()) ::
  Raxol.Terminal.ANSI.TextFormatting.t()
```

Sets the background color.

# `set_double_height_bottom`

```elixir
@spec set_double_height_bottom(Raxol.Terminal.ANSI.TextFormatting.t()) ::
  Raxol.Terminal.ANSI.TextFormatting.t()
```

Sets double-height bottom half mode for the current line.

# `set_double_height_top`

```elixir
@spec set_double_height_top(Raxol.Terminal.ANSI.TextFormatting.t()) ::
  Raxol.Terminal.ANSI.TextFormatting.t()
```

Sets double-height top half mode for the current line.

# `set_double_width`

```elixir
@spec set_double_width(Raxol.Terminal.ANSI.TextFormatting.t()) ::
  Raxol.Terminal.ANSI.TextFormatting.t()
```

Sets double-width mode for the current line.

# `set_foreground`

```elixir
@spec set_foreground(Raxol.Terminal.ANSI.TextFormatting.t(), color()) ::
  Raxol.Terminal.ANSI.TextFormatting.t()
```

Sets the foreground color.

# `set_hyperlink`

```elixir
@spec set_hyperlink(Raxol.Terminal.ANSI.TextFormatting.t(), String.t() | nil) ::
  Raxol.Terminal.ANSI.TextFormatting.t()
```

Sets a hyperlink URI.

# `set_style`

```elixir
@spec set_style(
  Raxol.Terminal.ANSI.TextFormatting.t(),
  Raxol.Terminal.ANSI.TextFormatting.t()
) ::
  Raxol.Terminal.ANSI.TextFormatting.t()
```

Sets the style to a new value.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
