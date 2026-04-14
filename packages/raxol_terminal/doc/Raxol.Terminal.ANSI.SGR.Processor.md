# `Raxol.Terminal.ANSI.SGR.Processor`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/ansi/sgr.ex#L380)

Optimized SGR (Select Graphic Rendition) processor for ANSI escape sequences.
Uses compile-time optimizations and pattern matching for maximum performance.

# `handle_sgr`

```elixir
@spec handle_sgr(binary(), Raxol.Terminal.ANSI.TextFormatting.t()) ::
  Raxol.Terminal.ANSI.TextFormatting.t()
```

Processes SGR parameters and applies them to the current style.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
