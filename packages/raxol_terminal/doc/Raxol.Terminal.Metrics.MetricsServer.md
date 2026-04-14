# `Raxol.Terminal.Metrics.MetricsServer`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/metrics/metrics_server.ex#L1)

ETS-backed metrics collection and export module.

Provides centralized metrics storage using ETS for high-performance
concurrent writes and reads. Supports multiple metric types and
Prometheus-compatible export.

## Design

Uses ETS for write-heavy workloads (per Rich Hickey's feedback).
No GenServer serialization for metric recording - direct ETS writes.

## Metric Types

- **Counters**: Monotonically increasing values (e.g., operations count)
- **Gauges**: Point-in-time values (e.g., memory usage)
- **Histograms**: Distribution of values (e.g., latency percentiles)

## Usage

    # Initialize (call once at app startup)
    MetricsServer.init()

    # Record metrics
    MetricsServer.increment(:requests_total, %{path: "/api"})
    MetricsServer.gauge(:memory_bytes, 1024000, %{type: :heap})
    MetricsServer.histogram(:latency_ms, 42.5, %{endpoint: :render})

    # Query metrics
    MetricsServer.get(:requests_total, %{path: "/api"})
    MetricsServer.get_all()

    # Export for monitoring
    MetricsServer.export(:prometheus)
    MetricsServer.export(:json)

# `labels`

```elixir
@type labels() :: map()
```

# `metric_name`

```elixir
@type metric_name() :: atom()
```

# `metric_value`

```elixir
@type metric_value() :: number()
```

# `cleanup_metrics`

```elixir
@spec cleanup_metrics(
  keyword(),
  atom()
) :: :ok
```

Cleans up old metrics.

## Options

  * `:older_than` - Remove entries older than this many milliseconds
  * `:type` - Only clean this type (:histogram, :error)

# `export`

```elixir
@spec export(atom()) :: String.t() | {:error, :unsupported_format}
```

Exports metrics in the specified format.

# `export_metrics`

```elixir
@spec export_metrics(
  keyword(),
  atom()
) :: String.t() | {:error, :unsupported_format}
```

Exports metrics in the specified format.

## Formats

  * `:prometheus` - Prometheus text format
  * `:json` - JSON format

## Examples

    MetricsServer.export(:prometheus)
    MetricsServer.export(:json)

# `gauge`

```elixir
@spec gauge(metric_name(), metric_value(), labels()) :: :ok
```

Sets a gauge metric to a specific value.

## Examples

    MetricsServer.gauge(:memory_bytes, 1024000)
    MetricsServer.gauge(:cpu_percent, 45.5, %{core: 0})

# `get_all`

```elixir
@spec get_all() :: map()
```

Gets all metrics as a map.

# `get_counter`

```elixir
@spec get_counter(metric_name(), labels()) :: non_neg_integer()
```

Gets the current value of a counter.

# `get_error_stats`

```elixir
@spec get_error_stats(labels(), atom()) :: {:ok, map()}
```

Gets error statistics.

# `get_gauge`

```elixir
@spec get_gauge(metric_name(), labels()) :: metric_value() | nil
```

Gets the current value of a gauge.

# `get_histogram`

```elixir
@spec get_histogram(metric_name(), labels()) :: map()
```

Gets histogram statistics.

Returns count, sum, min, max, and percentiles.

# `get_metric`

```elixir
@spec get_metric(metric_name(), labels(), atom()) ::
  {:ok, metric_value()} | {:error, :not_found}
```

Gets a metric value (generic interface).

# `histogram`

```elixir
@spec histogram(metric_name(), metric_value(), labels()) :: :ok
```

Records a value in a histogram.

## Examples

    MetricsServer.histogram(:latency_ms, 42.5)
    MetricsServer.histogram(:latency_ms, 15.2, %{endpoint: :render})

# `increment`

```elixir
@spec increment(metric_name(), labels(), pos_integer()) :: :ok
```

Increments a counter metric.

## Examples

    MetricsServer.increment(:requests_total)
    MetricsServer.increment(:requests_total, %{path: "/api"})
    MetricsServer.increment(:requests_total, %{path: "/api"}, 5)

# `init`

```elixir
@spec init() :: :ok
```

Initializes the metrics storage tables.

Call once during application startup.

# `initialized?`

```elixir
@spec initialized?() :: boolean()
```

Checks if metrics storage is initialized.

# `record_error`

```elixir
@spec record_error(String.t(), labels(), atom()) :: :ok
```

Records an error occurrence.

# `record_metric`

```elixir
@spec record_metric(metric_name(), metric_value(), labels(), atom()) :: :ok
```

Records a metric value (generic interface).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
