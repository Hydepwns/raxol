# Raxol Metrics System

## Overview

The Raxol Metrics System provides a unified approach to collecting, aggregating, visualizing, and alerting on metrics across the terminal emulator. It supports multiple metric types, real-time visualization, advanced aggregation, and configurable alerts.

## Core Components

### 1. Unified Metrics Collector

The `Raxol.Core.Metrics.UnifiedCollector` is the central component for collecting and managing metrics.

```elixir
# Start the collector
{:ok, _pid} = Raxol.Core.Metrics.UnifiedCollector.start_link(
  retention_period: :timer.hours(24),
  max_samples: 1000,
  flush_interval: :timer.seconds(5)
)

# Record a metric
Raxol.Core.Metrics.UnifiedCollector.record_metric(
  "buffer_operations",
  :performance,
  42,
  tags: %{operation: "write", buffer: "main"}
)
```

### 2. Metric Aggregator

The `Raxol.Core.Metrics.Aggregator` provides advanced metric aggregation capabilities.

```elixir
# Start the aggregator
{:ok, _pid} = Raxol.Core.Metrics.Aggregator.start_link()

# Add an aggregation rule
Raxol.Core.Metrics.Aggregator.add_rule(%{
  name: "hourly_buffer_ops",
  metric_name: "buffer_operations",
  type: :mean,
  time_window: :timer.hours(1),
  group_by: [:operation, :buffer]
})

# Get aggregated metrics
{:ok, metrics} = Raxol.Core.Metrics.Aggregator.get_metrics("hourly_buffer_ops")
```

### 3. Metric Visualizer

The `Raxol.Core.Metrics.Visualizer` enables real-time metric visualization.

```elixir
# Start the visualizer
{:ok, _pid} = Raxol.Core.Metrics.Visualizer.start_link()

# Create a chart
{:ok, chart_id} = Raxol.Core.Metrics.Visualizer.create_chart(
  "buffer_operations",
  :line,
  %{
    title: "Buffer Operations",
    time_range: :timer.hours(1),
    group_by: [:operation]
  }
)

# Export chart data
{:ok, data} = Raxol.Core.Metrics.Visualizer.export_chart(chart_id, :json)
```

### 4. Alert Manager

The `Raxol.Core.Metrics.AlertManager` handles metric-based alerting.

```elixir
# Start the alert manager
{:ok, _pid} = Raxol.Core.Metrics.AlertManager.start_link()

# Add an alert rule
Raxol.Core.Metrics.AlertManager.add_rule(%{
  name: "high_buffer_usage",
  metric_name: "buffer_usage",
  condition: {:above, 90},
  severity: :warning,
  cooldown: :timer.minutes(5),
  notification: %{
    type: :slack,
    channel: "#alerts"
  }
})

# Get alert states
{:ok, states} = Raxol.Core.Metrics.AlertManager.get_states()
```

## Best Practices

1. **Metric Naming**

   - Use consistent naming conventions
   - Include units in metric names
   - Use descriptive names that indicate the metric's purpose

2. **Tag Usage**

   - Use tags for categorization and filtering
   - Keep tag values consistent
   - Avoid high-cardinality tags
   - Use meaningful tag names

3. **Aggregation Rules**

   - Define appropriate time windows
   - Choose suitable aggregation types
   - Group metrics logically
   - Consider retention periods

4. **Alert Configuration**

   - Set appropriate thresholds
   - Configure reasonable cooldown periods
   - Use appropriate severity levels
   - Set up proper notification channels

5. **Visualization**
   - Choose appropriate chart types
   - Set meaningful time ranges
   - Group related metrics
   - Use consistent formatting

## Integration Guide

### 1. Basic Setup

```elixir
# Start all components
{:ok, collector} = Raxol.Core.Metrics.UnifiedCollector.start_link()
{:ok, aggregator} = Raxol.Core.Metrics.Aggregator.start_link()
{:ok, visualizer} = Raxol.Core.Metrics.Visualizer.start_link()
{:ok, alert_manager} = Raxol.Core.Metrics.AlertManager.start_link()
```

### 2. Recording Metrics

```elixir
# Performance metrics
Raxol.Core.Metrics.UnifiedCollector.record_metric(
  "operation_duration",
  :performance,
  150,
  tags: %{operation: "render", component: "buffer"}
)

# Resource metrics
Raxol.Core.Metrics.UnifiedCollector.record_metric(
  "memory_usage",
  :resource,
  1024,
  tags: %{type: "heap", process: "buffer_manager"}
)

# Operation metrics
Raxol.Core.Metrics.UnifiedCollector.record_metric(
  "buffer_operations",
  :operation,
  1,
  tags: %{type: "write", buffer: "main"}
)
```

### 3. Setting Up Aggregation

```elixir
# Add aggregation rules
Raxol.Core.Metrics.Aggregator.add_rule(%{
  name: "hourly_performance",
  metric_name: "operation_duration",
  type: :percentile,
  percentile: 95,
  time_window: :timer.hours(1),
  group_by: [:operation, :component]
})

Raxol.Core.Metrics.Aggregator.add_rule(%{
  name: "daily_resource_usage",
  metric_name: "memory_usage",
  type: :max,
  time_window: :timer.hours(24),
  group_by: [:type, :process]
})
```

### 4. Creating Visualizations

```elixir
# Create performance chart
{:ok, perf_chart} = Raxol.Core.Metrics.Visualizer.create_chart(
  "operation_duration",
  :line,
  %{
    title: "Operation Duration",
    time_range: :timer.hours(1),
    group_by: [:operation]
  }
)

# Create resource usage chart
{:ok, resource_chart} = Raxol.Core.Metrics.Visualizer.create_chart(
  "memory_usage",
  :gauge,
  %{
    title: "Memory Usage",
    time_range: :timer.minutes(5),
    group_by: [:process]
  }
)
```

### 5. Configuring Alerts

```elixir
# Add performance alert
Raxol.Core.Metrics.AlertManager.add_rule(%{
  name: "slow_operations",
  metric_name: "operation_duration",
  condition: {:above, 1000},
  severity: :warning,
  cooldown: :timer.minutes(5),
  notification: %{
    type: :slack,
    channel: "#performance-alerts"
  }
})

# Add resource alert
Raxol.Core.Metrics.AlertManager.add_rule(%{
  name: "high_memory_usage",
  metric_name: "memory_usage",
  condition: {:above, 1024 * 1024 * 1024},
  severity: :critical,
  cooldown: :timer.minutes(1),
  notification: %{
    type: :email,
    recipients: ["ops@example.com"]
  }
})
```

## Migration Guide

### From Legacy Metrics

1. Replace direct metric recording:

   ```elixir
   # Old
   Raxol.Terminal.Metrics.record("operation", value)

   # New
   Raxol.Core.Metrics.UnifiedCollector.record_metric(
     "operation",
     :performance,
     value,
     tags: %{component: "terminal"}
   )
   ```

2. Update metric queries:

   ```elixir
   # Old
   Raxol.Terminal.Metrics.get_metric("operation")

   # New
   Raxol.Core.Metrics.UnifiedCollector.get_metric(
     "operation",
     tags: %{component: "terminal"}
   )
   ```

3. Migrate alerts:

   ```elixir
   # Old
   Raxol.Terminal.Metrics.set_alert("operation", threshold)

   # New
   Raxol.Core.Metrics.AlertManager.add_rule(%{
     name: "operation_alert",
     metric_name: "operation",
     condition: {:above, threshold},
     severity: :warning
   })
   ```

## Configuration

### Collector Configuration

```elixir
config :raxol, :metrics_collector,
  retention_period: :timer.hours(24),
  max_samples: 1000,
  flush_interval: :timer.seconds(5),
  cloud_enabled: true
```

### Aggregator Configuration

```elixir
config :raxol, :metrics_aggregator,
  update_interval: :timer.seconds(60),
  max_rules: 100
```

### Visualizer Configuration

```elixir
config :raxol, :metrics_visualizer,
  max_charts: 50,
  default_time_range: :timer.hours(1)
```

### Alert Manager Configuration

```elixir
config :raxol, :metrics_alert_manager,
  check_interval: :timer.seconds(30),
  max_rules: 100,
  default_cooldown: :timer.minutes(5)
```

## Troubleshooting

### Common Issues

1. **High Memory Usage**

   - Check retention periods
   - Review max_samples settings
   - Monitor aggregation rules
   - Verify chart configurations

2. **Missing Metrics**

   - Verify metric names
   - Check tag values
   - Confirm collector is running
   - Review flush intervals

3. **Alert Issues**

   - Verify alert rules
   - Check notification channels
   - Review cooldown periods
   - Confirm metric collection

4. **Visualization Problems**
   - Check chart configurations
   - Verify time ranges
   - Review grouping settings
   - Confirm data availability

## Support

For issues and feature requests, please contact the development team or create an issue in the project repository.
