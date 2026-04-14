# `Raxol.Terminal.ANSI.CachedParser`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/ansi/cached_parser.ex#L1)

Optimized ANSI parser with caching for common sequences.

Phase 1 optimization to reduce memory overhead and improve
performance for frequently used escape sequences.

# `parsed_token`

```elixir
@type parsed_token() ::
  {:text, binary()}
  | {:csi, binary(), binary()}
  | {:osc, binary()}
  | {:dcs, binary()}
  | {:escape, binary()}
```

# `benchmark_comparison`

Benchmark comparison between cached and original parser.

# `cache_stats`

Get statistics about cache coverage.

# `parse`

```elixir
@spec parse(binary()) :: [parsed_token()]
```

Parses ANSI escape sequences with caching optimization.

First checks if the input exactly matches a common cached sequence,
then falls back to full parsing for complex inputs.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
