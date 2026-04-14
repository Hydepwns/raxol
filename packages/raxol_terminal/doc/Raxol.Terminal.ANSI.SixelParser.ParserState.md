# `Raxol.Terminal.ANSI.SixelParser.ParserState`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/ansi/sixel_parser.ex#L9)

Represents the state during the parsing of a Sixel graphics data stream.
Tracks position, color, palette, and pixel buffer information.

# `t`

```elixir
@type t() :: %Raxol.Terminal.ANSI.SixelParser.ParserState{
  color_index: integer(),
  max_x: integer(),
  max_y: integer(),
  palette: map(),
  pixel_buffer: map(),
  raster_attrs: map(),
  repeat_count: integer(),
  x: integer(),
  y: integer()
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
