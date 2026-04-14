# `Raxol.Terminal.Rendering.CachedStyleRenderer`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/rendering/cached_style_renderer.ex#L1)

High-performance terminal renderer with style string caching.

Phase 2 optimization targeting the critical bottleneck:
- Style string building: 44.9% of render time
- Target: Reduce from 1461μs to <500μs (65% improvement)

Key optimizations:
1. LRU cache for compiled CSS style strings
2. Pre-compiled templates for common styles
3. Batch processing for consecutive identical styles
4. Memory-efficient string building

# `t`

```elixir
@type t() :: %Raxol.Terminal.Rendering.CachedStyleRenderer{
  cache_hits: non_neg_integer(),
  cache_misses: non_neg_integer(),
  cursor: {non_neg_integer(), non_neg_integer()} | nil,
  font_settings: map(),
  screen_buffer: Raxol.Terminal.ScreenBuffer.t(),
  style_cache: map(),
  theme: map()
}
```

# `get_cache_stats`

Get cache performance statistics.

# `new`

Creates a new cached style renderer.

# `render`

Renders the terminal content with cached style optimization.

# `render_with_state`

Renders the terminal content and returns both content and updated renderer with cache.
Use this for stateful rendering where you want to preserve cache between renders.

# `reset_cache_stats`

Reset cache statistics.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
