# `Raxol.Terminal.Emulator.Style`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/emulator/style.ex#L1)

Handles text styling and formatting for the terminal emulator.
Provides functions for managing character attributes, colors, and text formatting.

# `blink`

```elixir
@type blink() :: :none | :slow | :rapid
```

# `color`

```elixir
@type color() :: {0..255, 0..255, 0..255} | :default
```

# `decoration`

```elixir
@type decoration() ::
  :none | :underline | :double_underline | :overline | :strikethrough
```

# `intensity`

```elixir
@type intensity() :: :normal | :bold | :faint
```

# `get_style`

```elixir
@spec get_style(Raxol.Terminal.Emulator.Struct.t()) ::
  Raxol.Terminal.ANSI.TextFormatting.text_style()
```

Gets the current text style.
Returns the current style.

# `reset_attributes`

```elixir
@spec reset_attributes(Raxol.Terminal.Emulator.Struct.t()) ::
  {:ok, Raxol.Terminal.Emulator.Struct.t()}
```

Resets all text attributes to default.
Returns {:ok, updated_emulator}.

# `set_attributes`

```elixir
@spec set_attributes(Raxol.Terminal.Emulator.Struct.t(), list()) ::
  {:ok, Raxol.Terminal.Emulator.Struct.t()} | {:error, String.t()}
```

Sets multiple style attributes at once.

# `set_background`

```elixir
@spec set_background(Raxol.Terminal.Emulator.Struct.t(), atom() | tuple()) ::
  {:ok, Raxol.Terminal.Emulator.Struct.t()} | {:error, String.t()}
```

Sets the background color.
Returns {:ok, updated_emulator} or {:error, reason}.

# `set_blink`

```elixir
@spec set_blink(Raxol.Terminal.Emulator.Struct.t(), :none | :slow | :rapid) ::
  {:ok, Raxol.Terminal.Emulator.Struct.t()} | {:error, String.t()}
```

Sets the text blink mode.
Returns {:ok, updated_emulator} or {:error, reason}.

# `set_decoration`

```elixir
@spec set_decoration(Raxol.Terminal.Emulator.Struct.t(), atom()) ::
  {:ok, Raxol.Terminal.Emulator.Struct.t()} | {:error, String.t()}
```

Sets the text decoration (underline, strikethrough, etc.).
Returns {:ok, updated_emulator} or {:error, reason}.

# `set_foreground`

```elixir
@spec set_foreground(Raxol.Terminal.Emulator.Struct.t(), atom() | tuple()) ::
  {:ok, Raxol.Terminal.Emulator.Struct.t()} | {:error, String.t()}
```

Sets the foreground color.
Returns {:ok, updated_emulator} or {:error, reason}.

# `set_intensity`

```elixir
@spec set_intensity(Raxol.Terminal.Emulator.Struct.t(), :normal | :bold | :faint) ::
  {:ok, Raxol.Terminal.Emulator.Struct.t()} | {:error, String.t()}
```

Sets the text intensity (bold, faint).
Returns {:ok, updated_emulator} or {:error, reason}.

# `set_inverse`

```elixir
@spec set_inverse(Raxol.Terminal.Emulator.Struct.t(), boolean()) ::
  {:ok, Raxol.Terminal.Emulator.Struct.t()} | {:error, String.t()}
```

Sets the text inverse mode.
Returns {:ok, updated_emulator} or {:error, reason}.

# `set_visibility`

```elixir
@spec set_visibility(Raxol.Terminal.Emulator.Struct.t(), :visible | :hidden) ::
  {:ok, Raxol.Terminal.Emulator.Struct.t()} | {:error, String.t()}
```

Sets the text visibility.
Returns {:ok, updated_emulator} or {:error, reason}.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
