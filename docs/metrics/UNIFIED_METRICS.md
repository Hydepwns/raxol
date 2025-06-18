# Raxol Unified Metrics System

## Overview

The Raxol Unified Metrics System provides a centralized way to collect, track, and analyze metrics across the Raxol terminal emulator. This system consolidates various metrics collection points into a single, consistent interface.

## Features

- 📊 Centralized metrics collection
- 🔄 Multiple metric types support
- 🤖 Automatic system metrics collection
- ⏱️ Configurable metric retention
- 🏷️ Tag-based metric categorization
- ✅ Comprehensive test coverage

## Metric Types

### 1. Performance Metrics

Track performance-related measurements:

```elixir
# Record frame timing
UnifiedCollector.record_performance(:frame_time, 16)

# Record with tags
UnifiedCollector.record_performance(:frame_time, 16, tags: [:ui, :render])
```

Common metrics:

- `:frame_time` - Frame render time
- `:render_time` - Render operations time
- `:fps` - Frames per second
- `:jank` - Frame jank detection

### 2. Resource Metrics

Monitor system resource usage:

```elixir
# Record memory usage
UnifiedCollector.record_resource(:memory_usage, 1024)

# Record with tags
UnifiedCollector.record_resource(:memory_usage, 1024, tags: [:system])
```

Common metrics:

- `:memory_usage` - Memory consumption
- `:cpu_usage` - CPU utilization
- `:gc_stats` - Garbage collection stats
- `:process_count` - Process count

### 3. Operation Metrics

Track operation counts and timing:

```elixir
# Record buffer operation
UnifiedCollector.record_operation(:buffer_write, 5)

# Record with tags
UnifiedCollector.record_operation(:buffer_write, 5, tags: [:buffer, :write])
```

Common metrics:

- `:buffer_write` - Buffer write operations
- `:buffer_read` - Buffer read operations
- `:render_call` - Render function calls
- `:event_processed` - Event processing

### 4. Custom Metrics

Record application-specific metrics:

```elixir
# Record custom metric
UnifiedCollector.record_custom("user.login_time", 150)

# Record with tags
UnifiedCollector.record_custom("api.request_time", 200, tags: [:api, :request])
```

## Quick Start

### Starting the Collector

```elixir
# Start with default options
{:ok, _pid} = UnifiedCollector.start_link()

# Start with custom options
{:ok, _pid} = UnifiedCollector.start_link(
  retention_period: 7200,  # 2 hours
  max_samples: 2000,      # Keep 2000 samples
  flush_interval: 10000   # Flush every 10 seconds
)
```

### Recording Metrics

```elixir
# Record different types of metrics
UnifiedCollector.record_performance(:frame_time, 16)
UnifiedCollector.record_resource(:memory_usage, 1024)
UnifiedCollector.record_operation(:buffer_write, 5)
UnifiedCollector.record_custom("user.login_time", 150)
```

### Retrieving Metrics

```elixir
# Get all metrics
metrics = UnifiedCollector.get_metrics()

# Get specific metric type
performance_metrics = UnifiedCollector.get_metrics_by_type(:performance)
```

## Integration Examples

### Buffer Manager

```elixir
def handle_call({:resize, width, height}, _from, state) do
  start_time = System.monotonic_time()
  # ... resize operations ...
  duration = System.monotonic_time() - start_time

  UnifiedCollector.record_performance(:buffer_resize, duration)
  UnifiedCollector.record_operation(:buffer_resize, 1, tags: [:buffer, :resize])

  {:reply, {:ok, state}, state}
end
```

### Performance Monitor

```elixir
def handle_cast({:record_frame, frame_time}, state) do
  UnifiedCollector.record_performance(:frame_time, frame_time, tags: [:performance, :frame])
  UnifiedCollector.record_performance(:fps, 1000 / frame_time, tags: [:performance, :frame])

  {:noreply, state}
end
```

## Configuration

### Default Options

```elixir
%{
  retention_period: 3600,  # 1 hour
  max_samples: 1000,      # 1000 samples
  flush_interval: 5000    # 5 seconds
}
```

## Best Practices

1. **Use Tags Consistently**

   - Use consistent tag names
   - Group related metrics
   - Use hierarchical tags

2. **Metric Naming**

   - Use descriptive names
   - Follow consistent patterns
   - Choose appropriate types

3. **Performance**

   - Don't record too frequently
   - Use appropriate sample sizes
   - Monitor the system itself

4. **Error Handling**
   - Handle failures gracefully
   - Log collection errors
   - Provide fallbacks

## Troubleshooting

### Common Issues

1. **High Memory Usage**

   - Check retention period
   - Reduce max samples
   - Monitor collection frequency

2. **Missing Metrics**

   - Verify metric names
   - Check tag consistency
   - Ensure collector is running

3. **Performance Impact**
   - Reduce collection frequency
   - Use appropriate sample sizes
   - Monitor system metrics

### Debugging

```elixir
# Get all current metrics
metrics = UnifiedCollector.get_metrics()

# Get specific metric type
performance_metrics = UnifiedCollector.get_metrics_by_type(:performance)

# Check metric history
frame_times = performance_metrics.frame_time
```

## Future Roadmap

1. **Visualization**

   - Metric visualization tools
   - Performance dashboards
   - Real-time monitoring

2. **Aggregation**

   - Metric aggregation functions
   - Statistical analysis
   - Trend analysis

3. **Export**

   - Metric export functionality
   - Multiple export formats
   - Metric archiving

4. **Integration**
   - External monitoring support
   - Metric forwarding
   - API endpoints
