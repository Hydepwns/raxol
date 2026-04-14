# `Raxol.Terminal.Font.Manager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/font/font_manager.ex#L1)

Manages font operations and settings for the terminal, including font family,
size, weight, and style.

# `custom_fonts`

```elixir
@type custom_fonts() :: %{required(String.t()) =&gt; String.t()}
```

# `fallback_fonts`

```elixir
@type fallback_fonts() :: [font_family()]
```

# `font_family`

```elixir
@type font_family() :: String.t()
```

# `font_size`

```elixir
@type font_size() :: non_neg_integer()
```

# `font_style`

```elixir
@type font_style() :: :normal | :italic | :oblique
```

# `font_weight`

```elixir
@type font_weight() :: :normal | :bold | :lighter | :bolder | 100..900
```

# `letter_spacing`

```elixir
@type letter_spacing() :: number()
```

# `line_height`

```elixir
@type line_height() :: number()
```

# `t`

```elixir
@type t() :: %Raxol.Terminal.Font.Manager{
  custom_fonts: custom_fonts(),
  fallback_fonts: fallback_fonts(),
  family: font_family(),
  letter_spacing: letter_spacing(),
  line_height: line_height(),
  size: font_size(),
  style: font_style(),
  weight: font_weight()
}
```

# `add_custom_font`

Adds a custom font.

# `get_custom_fonts`

Gets the current custom fonts.

# `get_fallback_fonts`

Gets the current fallback fonts.

# `get_family`

Gets the current font family.

# `get_font_stack`

Gets the complete font stack including fallbacks.

# `get_letter_spacing`

Gets the current letter spacing.

# `get_line_height`

Gets the current line height.

# `get_size`

Gets the current font size.

# `get_style`

Gets the current font style.

# `get_weight`

Gets the current font weight.

# `new`

Creates a new font manager instance with default settings.

# `remove_custom_font`

Removes a custom font.

# `reset`

Resets the font manager to its initial state.

# `set_fallback_fonts`

Sets the fallback fonts.

# `set_family`

Sets the font family.

# `set_letter_spacing`

Sets the letter spacing.

# `set_line_height`

Sets the line height.

# `set_size`

Sets the font size.

# `set_style`

Sets the font style.

# `set_weight`

Sets the font weight.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
