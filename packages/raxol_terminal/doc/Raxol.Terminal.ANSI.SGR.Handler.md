# `Raxol.Terminal.ANSI.SGR.Handler`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/ansi/sgr.ex#L183)

Handles parsing of SGR (Select Graphic Rendition) ANSI escape sequences.
Translates SGR codes into updates on a TextFormatting style map.

# `apply_sgr_code`

```elixir
@spec apply_sgr_code(integer(), Raxol.Terminal.ANSI.TextFormatting.t()) ::
  Raxol.Terminal.ANSI.TextFormatting.t()
```

Applies a single SGR code to the style.

# `handle_extended_color`

```elixir
@spec handle_extended_color(
  [integer()],
  Raxol.Terminal.ANSI.TextFormatting.t(),
  :foreground | :background
) :: Raxol.Terminal.ANSI.TextFormatting.t()
```

Processes extended color sequences (256 color or RGB).

# `handle_sgr`

```elixir
@spec handle_sgr(binary(), Raxol.Terminal.ANSI.TextFormatting.t()) ::
  Raxol.Terminal.ANSI.TextFormatting.t()
```

Handles an SGR sequence by parsing parameters and applying style changes.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
