# `Raxol.Core.Behaviours.Metrics`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/behaviours/metrics.ex#L1)

Common behavior for metrics collection and reporting.

This behavior defines a consistent interface for components that
collect, track, and report metrics about their operation.

# `metric_name`

```elixir
@type metric_name() :: atom() | String.t()
```

# `metric_tags`

```elixir
@type metric_tags() :: keyword()
```

# `metric_value`

```elixir
@type metric_value() :: number()
```

# `metrics`

```elixir
@type metrics() :: map()
```

# `decrement`

```elixir
@callback decrement(metric_name(), metric_value(), metric_tags()) :: :ok
```

Decrements a counter metric.

# `gauge`

```elixir
@callback gauge(metric_name(), metric_value(), metric_tags()) :: :ok
```

Records a gauge metric value.

# `get_metric`

```elixir
@callback get_metric(metric_name()) :: metric_value() | nil
```

Gets a specific metric value.

# `get_metrics`

```elixir
@callback get_metrics() :: metrics()
```

Gets all current metric values.

# `histogram`

```elixir
@callback histogram(metric_name(), metric_value(), metric_tags()) :: :ok
```

Records a histogram/timing metric.

# `increment`

```elixir
@callback increment(metric_name(), metric_value(), metric_tags()) :: :ok
```

Increments a counter metric.

# `reset_metric`
*optional* 

```elixir
@callback reset_metric(metric_name()) :: :ok
```

Resets a specific metric to its initial value.

# `reset_metrics`
*optional* 

```elixir
@callback reset_metrics() :: :ok
```

Resets all metrics to initial values.

# `__using__`
*macro* 

Convenience functions with default implementations.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
