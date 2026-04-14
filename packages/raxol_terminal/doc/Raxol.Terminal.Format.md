# `Raxol.Terminal.Format`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/format.ex#L1)

Unified terminal text formatting and styling operations.

This module manages formatting state (bold, italic, colors, etc.) and provides
functions for applying ANSI escape codes to text. It consolidates the
previously separate FormattingManager and Formatting.Manager modules.

## Usage

    iex> format = Format.new()
    iex> format = Format.set_foreground(format, 196)
    iex> format = Format.toggle_bold(format)
    iex> Format.apply_formatting(format, "Hello")
    "[1m[38;5;196mHello[39m[22m"

# `format`

```elixir
@type format() :: %{
  bold: boolean(),
  faint: boolean(),
  italic: boolean(),
  underline: boolean(),
  blink: boolean(),
  reverse: boolean(),
  conceal: boolean(),
  strikethrough: boolean(),
  foreground: term() | nil,
  background: term() | nil,
  font: non_neg_integer()
}
```

Terminal text attributes

# `t`

```elixir
@type t() :: %Raxol.Terminal.Format{
  current_format: format(),
  saved_format: format() | nil
}
```

Format state with current and saved formats

# `apply_format`

```elixir
@spec apply_format(t(), map()) :: t()
```

Applies a map of format updates to the current state.

# `apply_formatting`

```elixir
@spec apply_formatting(t(), String.t()) :: String.t()
```

Applies the current formatting to a string, wrapping it with ANSI escape codes.

Each attribute that is enabled will add the appropriate SGR codes around the text.

# `attribute_set?`

```elixir
@spec attribute_set?(t(), atom()) :: boolean()
```

Checks if the specified attribute is set.

# `get_background`

```elixir
@spec get_background(t()) :: term() | nil
```

Gets the current background color.

# `get_foreground`

```elixir
@spec get_foreground(t()) :: term() | nil
```

Gets the current foreground color.

# `get_format`

```elixir
@spec get_format(t()) :: format()
```

Gets the current formatting state.

# `get_set_attributes`

```elixir
@spec get_set_attributes(t()) :: [{atom(), true}]
```

Returns a list of all attributes that are currently set to true.

# `new`

```elixir
@spec new() :: %Raxol.Terminal.Format{
  current_format: %{
    bold: false,
    faint: false,
    italic: false,
    underline: false,
    blink: false,
    reverse: false,
    conceal: false,
    strikethrough: false,
    foreground: nil,
    background: nil,
    font: 0
  },
  saved_format: nil
}
```

Creates a new formatting state with default values.

# `reset_attribute`

```elixir
@spec reset_attribute(t(), atom()) :: t()
```

Resets the specified attribute to false.

# `reset_format`

```elixir
@spec reset_format(t()) :: t()
```

Resets the current format to default values.

# `restore_format`

```elixir
@spec restore_format(t()) :: t()
```

Restores the previously saved format state.

Returns unchanged state if no format was saved.

# `save_format`

```elixir
@spec save_format(t()) :: t()
```

Saves the current format state for later restoration.

# `set_attribute`

```elixir
@spec set_attribute(t(), atom()) :: t()
```

Sets the specified attribute to true.

# `set_background`

```elixir
@spec set_background(t(), term() | nil) :: t()
```

Sets the background color.

Color can be an 8-bit color code (0-255) or nil for default.

# `set_font`

```elixir
@spec set_font(t(), non_neg_integer()) :: t()
```

Sets the font number (0-9 for standard ANSI fonts).

# `set_foreground`

```elixir
@spec set_foreground(t(), term() | nil) :: t()
```

Sets the foreground color.

Color can be an 8-bit color code (0-255) or nil for default.

# `to_ansi_sequences`

```elixir
@spec to_ansi_sequences(t()) :: {String.t(), String.t()}
```

Generates the ANSI escape sequence for the current format without text.

Returns a tuple of {start_sequence, end_sequence} that can be used to wrap text.

# `toggle_blink`

```elixir
@spec toggle_blink(t()) :: t()
```

Toggles blink formatting.

# `toggle_bold`

```elixir
@spec toggle_bold(t()) :: t()
```

Toggles bold formatting.

# `toggle_conceal`

```elixir
@spec toggle_conceal(t()) :: t()
```

Toggles conceal formatting.

# `toggle_faint`

```elixir
@spec toggle_faint(t()) :: t()
```

Toggles faint formatting.

# `toggle_italic`

```elixir
@spec toggle_italic(t()) :: t()
```

Toggles italic formatting.

# `toggle_reverse`

```elixir
@spec toggle_reverse(t()) :: t()
```

Toggles reverse video formatting.

# `toggle_strikethrough`

```elixir
@spec toggle_strikethrough(t()) :: t()
```

Toggles strikethrough formatting.

# `toggle_underline`

```elixir
@spec toggle_underline(t()) :: t()
```

Toggles underline formatting.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
