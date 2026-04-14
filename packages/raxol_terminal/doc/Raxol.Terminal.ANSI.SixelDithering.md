# `Raxol.Terminal.ANSI.SixelDithering`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/ansi/sixel_dithering.ex#L1)

Dithering algorithms for Sixel image color quantization.

Operates on a `SixelGraphics` struct that has a populated `pixel_buffer`
(palette indices) and `palette` (index -> {r,g,b} map). Reconstructs the
RGB color grid, applies the chosen dithering algorithm, and re-maps pixels
to palette indices.

Supported algorithms:
- `:floyd_steinberg` -- error diffusion (best quality, serial scan)
- `:ordered` -- Bayer 4x4 threshold matrix (fast, deterministic pattern)
- `:random` -- random noise perturbation (fast, non-deterministic)

# `apply`

```elixir
@spec apply(
  Raxol.Terminal.ANSI.SixelGraphics.t(),
  Raxol.Terminal.ANSI.SixelGraphics.dithering_algorithm()
) :: Raxol.Terminal.ANSI.SixelGraphics.t()
```

Applies the specified dithering algorithm to the image.

Returns the image with an updated `pixel_buffer` and `dithering_algorithm` flag.
Images with empty pixel_buffer or palette are returned with only the flag set.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
