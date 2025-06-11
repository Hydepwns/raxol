# Raxol Unified Metrics System

## Overview

The Raxol Unified Metrics System provides a centralized way to collect, track, and analyze metrics across the Raxol terminal emulator. This system consolidates various metrics collection points into a single, consistent interface.

## Features

- Centralized metrics collection
- Multiple metric types support
- Automatic system metrics collection
- Configurable metric retention
- Tag-based metric categorization
- Comprehensive test coverage

## Metric Types

### 1. Performance Metrics

Track performance-related measurements:

```elixir
# Record frame timing
UnifiedCollector.record_performance(:frame_time, 16)

# Record render time
UnifiedCollector.record_performance(:render_time, 8)

# Record with tags
UnifiedCollector.record_performance(:frame_time, 16, tags: [:ui, :render])
```

Common performance metrics:

- `:frame_time` - Time taken to render a frame
- `:render_time` - Time taken for specific render operations
- `:fps` - Frames per second
- `:jank` - Frame jank detection

### 2. Resource Metrics

Monitor system resource usage:

```elixir
# Record memory usage
UnifiedCollector.record_resource(:memory_usage, 1024)

# Record CPU usage
UnifiedCollector.record_resource(:cpu_usage, 50)

# Record with tags
UnifiedCollector.record_resource(:memory_usage, 1024, tags: [:system])
```

Common resource metrics:

- `:memory_usage` - Memory consumption
- `:cpu_usage` - CPU utilization
- `:gc_stats` - Garbage collection statistics
- `:process_count` - Number of processes

### 3. Operation Metrics

Track operation counts and timing:

```elixir
# Record buffer operation
UnifiedCollector.record_operation(:buffer_write, 5)

# Record render operation
UnifiedCollector.record_operation(:render_call, 1)

# Record with tags
UnifiedCollector.record_operation(:buffer_write, 5, tags: [:buffer, :write])
```

Common operation metrics:

- `:buffer_write` - Buffer write operations
- `:buffer_read` - Buffer read operations
- `:render_call` - Render function calls
- `:event_processed` - Event processing operations

### 4. Custom Metrics

Record application-specific metrics:

```elixir
# Record custom metric
UnifiedCollector.record_custom("user.login_time", 150)

# Record with tags
UnifiedCollector.record_custom("api.request_time", 200, tags: [:api, :request])
```

## Usage

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

# Record with tags
UnifiedCollector.record_performance(:frame_time, 16, tags: [:ui, :render])
```

### Retrieving Metrics

```elixir
# Get all metrics
metrics = UnifiedCollector.get_metrics()

# Get specific metric type
performance_metrics = UnifiedCollector.get_metrics_by_type(:performance)
resource_metrics = UnifiedCollector.get_metrics_by_type(:resource)
```

## Integration

### Buffer Manager Integration

The buffer manager uses the metrics system to track:

- Buffer operations (read/write)
- Memory usage
- Performance metrics

Example:

```elixir
# In buffer manager
def handle_call({:resize, width, height}, _from, state) do
  start_time = System.monotonic_time()
  # ... resize operations ...
  duration = System.monotonic_time() - start_time

  UnifiedCollector.record_performance(:buffer_resize, duration)
  UnifiedCollector.record_operation(:buffer_resize, 1, tags: [:buffer, :resize])

  {:reply, {:ok, state}, state}
end
```

### Performance Monitor Integration

The performance monitor uses the metrics system to track:

- Frame timing
- FPS
- Jank detection
- Memory usage
- GC statistics

Example:

```elixir
# In performance monitor
def handle_cast({:record_frame, frame_time}, state) do
  UnifiedCollector.record_performance(:frame_time, frame_time, tags: [:performance, :frame])
  UnifiedCollector.record_performance(:fps, 1000 / frame_time, tags: [:performance, :frame])

  {:noreply, state}
end
```

## Configuration

### Options

The metrics collector can be configured with the following options:

- `retention_period` - How long to keep metrics (in seconds)
- `max_samples` - Maximum number of samples to keep per metric
- `flush_interval` - How often to flush metrics (in milliseconds)

### Default Values

```elixir
%{
  retention_period: 3600,  # 1 hour
  max_samples: 1000,      # 1000 samples
  flush_interval: 5000    # 5 seconds
}
```

## Best Practices

1. **Use Tags Consistently**

   - Use consistent tag names across related metrics
   - Group related metrics with common tags
   - Use hierarchical tags for better organization

2. **Metric Naming**

   - Use descriptive names
   - Follow consistent naming patterns
   - Use appropriate metric types

3. **Performance Considerations**

   - Don't record metrics too frequently
   - Use appropriate sample sizes
   - Monitor the metrics system itself

4. **Error Handling**
   - Handle metric recording failures gracefully
   - Log metric collection errors
   - Provide fallback behavior

## Migration Guide

### From Old Metrics System

1. Replace direct metrics collection:

   ```elixir
   # Old
   MetricsCollector.record_frame(collector, frame_time)

   # New
   UnifiedCollector.record_performance(:frame_time, frame_time)
   ```

2. Update metric retrieval:

   ```elixir
   # Old
   fps = MetricsCollector.get_fps(collector)

   # New
   metrics = UnifiedCollector.get_metrics_by_type(:performance)
   fps = case metrics.frame_time do
     [%{value: frame_time} | _] -> 1000 / frame_time
     _ -> 0.0
   end
   ```

3. Add tags to existing metrics:

   ```elixir
   # Old
   MetricsCollector.record_memory_usage(collector)

   # New
   UnifiedCollector.record_resource(:memory_usage, memory, tags: [:system, :memory])
   ```

## Troubleshooting

### Common Issues

1. **High Memory Usage**

   - Check metric retention period
   - Reduce max samples
   - Monitor metric collection frequency

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

## Future Enhancements

1. **Visualization**

   - Add metric visualization tools
   - Create performance dashboards
   - Implement real-time monitoring

2. **Aggregation**

   - Add metric aggregation functions
   - Implement statistical analysis
   - Create trend analysis

3. **Export**

   - Add metric export functionality
   - Support multiple export formats
   - Implement metric archiving

4. **Integration**
   - Add support for external monitoring systems
   - Implement metric forwarding
   - Create API endpoints
