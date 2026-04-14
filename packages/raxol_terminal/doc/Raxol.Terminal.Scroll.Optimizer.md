# `Raxol.Terminal.Scroll.Optimizer`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/scroll/optimizer.ex#L1)

Handles scroll optimization for better performance.
Dynamically adjusts batch size based on recent scroll patterns and (optionally) performance metrics.

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
@type t() :: %Raxol.Terminal.Scroll.Optimizer{
  batch_size: non_neg_integer(),
  history: [scroll_event()],
  last_optimization: non_neg_integer()
}
```

# `new`

```elixir
@spec new() :: t()
```

Creates a new optimizer instance.

# `optimize`

```elixir
@spec optimize(t(), :up | :down, non_neg_integer()) :: t()
```

Optimizes scroll operations for better performance.

- Increases batch size for large/rapid scrolls.
- Decreases batch size for small/precise or alternating scrolls.
- Uses recent scroll history to adapt.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
