# `Raxol.Terminal.ANSI.TextFormatting`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/ansi/text_formatting.ex#L1)

Consolidated text formatting module for the terminal emulator.
Combines Core, Attributes, and Colors functionality.
Handles advanced text formatting features including double-width/height,
text attributes, and color management.

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

# `t`

```elixir
@type t() :: %Raxol.Terminal.ANSI.TextFormatting{
  background: color(),
  blink: boolean(),
  bold: boolean(),
  conceal: boolean(),
  double_height: :none | :top | :bottom,
  double_underline: boolean(),
  double_width: boolean(),
  encircled: boolean(),
  faint: boolean(),
  foreground: color(),
  fraktur: boolean(),
  framed: boolean(),
  hyperlink: String.t() | nil,
  italic: boolean(),
  overlined: boolean(),
  reverse: boolean(),
  strikethrough: boolean(),
  underline: boolean()
}
```

# `text_style`

```elixir
@type text_style() :: %{
  double_width: boolean(),
  double_height: :none | :top | :bottom,
  bold: boolean(),
  faint: boolean(),
  italic: boolean(),
  underline: boolean(),
  blink: boolean(),
  reverse: boolean(),
  conceal: boolean(),
  strikethrough: boolean(),
  fraktur: boolean(),
  double_underline: boolean(),
  framed: boolean(),
  encircled: boolean(),
  overlined: boolean(),
  foreground: color(),
  background: color(),
  hyperlink: String.t() | nil
}
```

# `ansi_code_to_color_name`

# `apply_color`

# `default_style`

# `effective_width`

# `format_sgr_params`

# `get_hyperlink`

# `get_paired_line_type`

# `needs_paired_line?`

# `new`

# `parse_sgr_param`

# `reset_background`

# `reset_conceal`

# `reset_double_underline`

# `reset_encircled`

# `reset_faint`

# `reset_foreground`

# `reset_fraktur`

# `reset_framed`

# `reset_strikethrough`

# `set_attribute`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
