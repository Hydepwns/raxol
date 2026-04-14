# `Raxol.Terminal.Emulator.Style.Behaviour`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/emulator/style_behaviour.ex#L1)

Defines the behaviour for terminal emulator style management.
This includes handling text attributes, colors, and text formatting.

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

# `reset_attributes`

```elixir
@callback reset_attributes(Raxol.Terminal.Emulator.Struct.t()) ::
  {:ok, Raxol.Terminal.Emulator.Struct.t()}
```

# `set_attributes`

```elixir
@callback set_attributes(Raxol.Terminal.Emulator.Struct.t(), list()) ::
  {:ok, Raxol.Terminal.Emulator.Struct.t()} | {:error, String.t()}
```

# `set_background`

```elixir
@callback set_background(Raxol.Terminal.Emulator.Struct.t(), atom() | tuple()) ::
  {:ok, Raxol.Terminal.Emulator.Struct.t()} | {:error, String.t()}
```

# `set_blink`

```elixir
@callback set_blink(Raxol.Terminal.Emulator.Struct.t(), blink()) ::
  {:ok, Raxol.Terminal.Emulator.Struct.t()} | {:error, String.t()}
```

# `set_decoration`

```elixir
@callback set_decoration(Raxol.Terminal.Emulator.Struct.t(), decoration()) ::
  {:ok, Raxol.Terminal.Emulator.Struct.t()} | {:error, String.t()}
```

# `set_foreground`

```elixir
@callback set_foreground(Raxol.Terminal.Emulator.Struct.t(), atom() | tuple()) ::
  {:ok, Raxol.Terminal.Emulator.Struct.t()} | {:error, String.t()}
```

# `set_intensity`

```elixir
@callback set_intensity(Raxol.Terminal.Emulator.Struct.t(), intensity()) ::
  {:ok, Raxol.Terminal.Emulator.Struct.t()} | {:error, String.t()}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
