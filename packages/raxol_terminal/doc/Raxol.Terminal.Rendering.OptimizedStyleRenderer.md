# `Raxol.Terminal.Rendering.OptimizedStyleRenderer`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/rendering/optimized_style_renderer.ex#L1)

Phase 3 optimized terminal renderer with efficient style handling.

Key optimizations:
1. Pre-compiled style patterns at compile time
2. Direct pattern matching instead of cache lookups
3. Minimal memory allocations
4. No process dictionary usage
5. Efficient string building with iodata

Target: <500μs render time (from current 1200-2600μs)

# `render`

Renders the screen buffer to HTML with optimized style handling.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
