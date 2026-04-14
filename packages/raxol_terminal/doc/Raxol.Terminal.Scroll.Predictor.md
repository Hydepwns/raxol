# `Raxol.Terminal.Scroll.Predictor`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/scroll/predictor.ex#L1)

Handles predictive scrolling operations for the terminal.
Tracks recent scrolls and provides pattern analysis for smarter prediction.

# `scroll_event`

```elixir
@type scroll_event() :: %{
  direction: :up | :down,
  lines: non_neg_integer(),
  timestamp: integer()
}
```

# `t`

```elixir
@type t() :: %Raxol.Terminal.Scroll.Predictor{
  history: [scroll_event()],
  window_size: non_neg_integer()
}
```

# `analyze_patterns`

Analyzes recent scroll patterns: returns average scroll size and alternation ratio.

# `new`

Creates a new predictor instance.

# `predict`

Adds a scroll event to the history and keeps only the window size worth of history.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
