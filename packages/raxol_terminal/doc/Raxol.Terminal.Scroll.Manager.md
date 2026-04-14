# `Raxol.Terminal.Scroll.Manager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/scroll/scroll_manager.ex#L1)

Manages terminal scrolling operations with advanced features.

Features:
- Predictive scrolling for smooth performance
- Scroll caching for efficient memory usage
- Scroll optimization for better performance
- Scroll synchronization across splits

# `t`

```elixir
@type t() :: %Raxol.Terminal.Scroll.Manager{
  metrics: %{
    scrolls: non_neg_integer(),
    predictions: non_neg_integer(),
    cache_hits: non_neg_integer(),
    cache_misses: non_neg_integer(),
    optimizations: non_neg_integer()
  },
  optimizer: Raxol.Terminal.Scroll.Optimizer.t(),
  predictor: Raxol.Terminal.Scroll.Predictor.t(),
  sync: Raxol.Terminal.Scroll.Sync.t()
}
```

# `clear_history`

```elixir
@spec clear_history(t()) :: {:ok, t()}
```

Clears the scroll history.

# `get_history`

```elixir
@spec get_history(
  t(),
  keyword()
) :: {:ok, [map()], t()}
```

Gets the scroll history.

## Parameters
  * `manager` - The scroll manager
  * `opts` - History options
    * `:limit` - Maximum number of entries to return (default: all)
    * `:direction` - Filter by direction (:up or :down)

# `get_metrics`

```elixir
@spec get_metrics(t()) :: map()
```

Gets the current scroll metrics.

# `new`

```elixir
@spec new(keyword()) :: t()
```

Creates a new scroll manager.

## Options
  * `:prediction_enabled` - Whether to enable predictive scrolling (default: true)
  * `:optimization_enabled` - Whether to enable scroll optimization (default: true)
  * `:sync_enabled` - Whether to enable scroll synchronization (default: true)

# `optimize`

```elixir
@spec optimize(t()) :: t()
```

Optimizes the scroll manager based on current metrics.

# `scroll`

```elixir
@spec scroll(t(), :up | :down, non_neg_integer(), keyword()) ::
  {:ok, t()} | {:error, term()}
```

Scrolls the terminal content.

## Parameters
  * `manager` - The scroll manager
  * `direction` - Scroll direction (:up or :down)
  * `lines` - Number of lines to scroll
  * `opts` - Scroll options
    * `:predict` - Whether to use prediction (default: true)
    * `:optimize` - Whether to optimize the scroll (default: true)
    * `:sync` - Whether to sync across splits (default: true)

---

*Consult [api-reference.md](api-reference.md) for complete listing*
