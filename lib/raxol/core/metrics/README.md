# Raxol Metrics System

Collects, aggregates, visualizes, and alerts on metrics across the terminal emulator.

## Components

### UnifiedCollector

Central metric collection:

```elixir
{:ok, _pid} = Raxol.Core.Metrics.UnifiedCollector.start_link(
  retention_period: :timer.hours(24),
  max_samples: 1000,
  flush_interval: :timer.seconds(5)
)

Raxol.Core.Metrics.UnifiedCollector.record_metric(
  "buffer_operations",
  :performance,
  42,
  tags: %{operation: "write", buffer: "main"}
)
```

### Aggregator

Time-windowed aggregation with grouping:

```elixir
Raxol.Core.Metrics.Aggregator.add_rule(%{
  name: "hourly_buffer_ops",
  metric_name: "buffer_operations",
  type: :mean,
  time_window: :timer.hours(1),
  group_by: [:operation, :buffer]
})
```

### Visualizer

Real-time charts:

```elixir
{:ok, chart_id} = Raxol.Core.Metrics.Visualizer.create_chart(
  "buffer_operations",
  :line,
  %{title: "Buffer Operations", time_range: :timer.hours(1), group_by: [:operation]}
)
```

### AlertManager

Threshold-based alerts with cooldown:

```elixir
Raxol.Core.Metrics.AlertManager.add_rule(%{
  name: "high_buffer_usage",
  metric_name: "buffer_usage",
  condition: {:above, 90},
  severity: :warning,
  cooldown: :timer.minutes(5),
  notification: %{type: :slack, channel: "#alerts"}
})
```

## Configuration

```elixir
config :raxol, :metrics_collector,
  retention_period: :timer.hours(24),
  max_samples: 1000,
  flush_interval: :timer.seconds(5)

config :raxol, :metrics_aggregator,
  update_interval: :timer.seconds(60),
  max_rules: 100

config :raxol, :metrics_visualizer,
  max_charts: 50,
  default_time_range: :timer.hours(1)

config :raxol, :metrics_alert_manager,
  check_interval: :timer.seconds(30),
  max_rules: 100,
  default_cooldown: :timer.minutes(5)
```

## Migration from Legacy Metrics

```elixir
# Old
Raxol.Terminal.Metrics.record("operation", value)

# New
Raxol.Core.Metrics.UnifiedCollector.record_metric(
  "operation", :performance, value, tags: %{component: "terminal"}
)
```
