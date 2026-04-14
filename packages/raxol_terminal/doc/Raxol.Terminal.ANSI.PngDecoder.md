# `Raxol.Terminal.ANSI.PngDecoder`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/ansi/png_decoder.ex#L1)

Pure Elixir PNG decoder using `:zlib`.

Supports 8-bit RGB (color type 2) and RGBA (color type 6) PNGs.
Returns pixel data as a flat list of `{r, g, b}` tuples in row-major order.

# `decoded`

```elixir
@type decoded() :: %{width: pos_integer(), height: pos_integer(), pixels: [pixel()]}
```

# `pixel`

```elixir
@type pixel() :: {byte(), byte(), byte()}
```

# `decode`

```elixir
@spec decode(binary()) :: {:ok, decoded()} | {:error, term()}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
