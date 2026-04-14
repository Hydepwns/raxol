# `Raxol.Terminal.Scroll.Sync`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/scroll/sync.ex#L1)

Handles scroll synchronization across terminal splits.
Tracks recent sync events for analytics and smarter sync strategies.

# `sync_event`

```elixir
@type sync_event() :: %{
  direction: :up | :down,
  lines: non_neg_integer(),
  timestamp: integer()
}
```

# `t`

```elixir
@type t() :: %Raxol.Terminal.Scroll.Sync{
  history: [sync_event()],
  last_sync: non_neg_integer(),
  sync_enabled: boolean()
}
```

# `analyze_patterns`

```elixir
@spec analyze_patterns(t()) :: %{avg_lines: float(), alternation_ratio: float()}
```

Analyzes recent sync patterns: returns average lines per sync and alternation ratio.

# `new`

```elixir
@spec new() :: t()
```

Creates a new sync instance.

# `sync`

```elixir
@spec sync(t(), :up | :down, non_neg_integer()) :: t()
```

Synchronizes scroll operations across splits and records the event.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
