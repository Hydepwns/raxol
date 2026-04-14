# `Raxol.Terminal.Color.TrueColor.Detection`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/color/true_color/detection.ex#L1)

Terminal color capability detection via environment variables.

# `terminal_capability`

```elixir
@type terminal_capability() :: :true_color | :color_256 | :color_16 | :monochrome
```

# `detect`

```elixir
@spec detect() :: terminal_capability()
```

Detects the terminal's color capability by inspecting COLORTERM and TERM env vars.

# `supports_16_color?`

```elixir
@spec supports_16_color?() :: boolean()
```

Returns true if the terminal supports 16 colors.

# `supports_256_color?`

```elixir
@spec supports_256_color?() :: boolean()
```

Returns true if the terminal supports 256 colors.

# `supports_true_color?`

```elixir
@spec supports_true_color?() :: boolean()
```

Returns true if the terminal supports 24-bit true color.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
