# `Raxol.Terminal.Color.TrueColor.AnsiCodes`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/color/true_color/ansi_codes.ex#L1)

Low-level ANSI color code helpers: 256-color and 16-color mapping,
hex string parsing, and hex formatting.

# `format_hex`

Formats an RGB(A) tuple as a hex string (e.g. "#FF0000" or "#FF0000AA").

# `pad`

Pads an integer to a 2-char uppercase hex string.

# `parse_hex_3`

Parses a 3-char hex string to `{:ok, r, g, b, 255}` or `{:error, :invalid_hex}`.

# `parse_hex_4`

Parses a 4-char hex string to `{:ok, r, g, b, a}` or `{:error, :invalid_hex}`.

# `parse_hex_6`

Parses a 6-char hex string to `{:ok, {r, g, b}}` or `{:error, :invalid_hex}`.

# `parse_hex_8`

Parses an 8-char hex string to `{:ok, r, g, b, a}` or `{:error, :invalid_hex}`.

# `to_16`

```elixir
@spec to_16(0..255, 0..255, 0..255) :: 30..97
```

Maps an 8-bit RGB color to the nearest 16-color ANSI code (foreground).

# `to_256`

```elixir
@spec to_256(0..255, 0..255, 0..255) :: 0..255
```

Maps an 8-bit RGB color to a 256-color palette index.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
