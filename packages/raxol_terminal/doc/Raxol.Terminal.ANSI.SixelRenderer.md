# `Raxol.Terminal.ANSI.SixelRenderer`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/ansi/sixel_renderer.ex#L1)

Handles rendering Sixel graphics data from a pixel buffer.

# `render_image`

```elixir
@spec render_image(%{pixel_buffer: map(), palette: map(), attributes: map()}) ::
  {:ok, binary()}
```

Renders the image stored in the pixel_buffer as a Sixel data stream.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
