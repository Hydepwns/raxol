# Performance

Optimization guide for terminal applications.

## Quick Wins

```elixir
# 1. Use damage tracking (automatic)
Raxol.render(component)  # Only updates changed regions

# 2. Enable caching
config :raxol, :cache,
  components: true,
  render_cache: true,
  ttl: :timer.minutes(5)

# 3. Batch operations
Raxol.batch do
  update_multiple_components()
end
```

## Benchmarks

Current performance targets:
- Parser: 3.3μs/operation
- Render: <1ms for full screen
- Memory: 2.8MB baseline
- Throughput: 10,000 ops/sec

## Profiling

### Built-in Profiler

```elixir
# Profile code block
{result, stats} = Raxol.Profiler.profile do
  expensive_operation()
end

IO.inspect(stats)
# %{
#   duration_us: 1523,
#   memory_kb: 245,
#   reductions: 3421
# }

# Profile component
Raxol.Profiler.profile_component(MyComponent)
```

### Performance Monitoring

```elixir
# Enable metrics collection
config :raxol, :metrics,
  enabled: true,
  reporters: [Raxol.Metrics.Logger]

# Access metrics
metrics = Raxol.Metrics.get()
%{
  render_time_p99: 0.8,  # ms
  fps: 144,
  memory_usage: 12.5,     # MB
  cpu_usage: 2.3          # %
}
```

## Optimization Strategies

### Rendering

```elixir
# 1. Virtual DOM diffing (automatic)
# 2. Memoization
defmodule ExpensiveComponent do
  use Raxol.Component
  use Raxol.Memo
  
  def should_update?(old_props, new_props) do
    old_props.data != new_props.data
  end
end

# 3. Lazy rendering
ScrollView.new(
  lazy: true,  # Render only visible items
  overscan: 2  # Render 2 items outside viewport
)
```

### State Updates

```elixir
# Batch updates
Raxol.batch_update([
  {:component1, new_state1},
  {:component2, new_state2}
])

# Debounce rapid updates
use Raxol.Debounce, delay: 100
handle_event(:input, value)  # Debounced automatically
```

### Memory Management

```elixir
# Configure buffer limits
config :raxol, :terminal,
  scrollback_limit: 1000,  # Lines
  max_buffer_size: 10_000,  # Cells
  gc_interval: :timer.seconds(30)

# Manual cleanup
Raxol.Terminal.trim_scrollback(term, 500)
Raxol.Terminal.gc(term)
```

## Caching

### Component Cache

```elixir
defmodule CachedList do
  use Raxol.Component
  use Raxol.Cache
  
  @cache_key :items
  @cache_ttl :timer.minutes(5)
  
  def render(state, props) do
    items = cache_fetch(@cache_key) || begin
      result = expensive_fetch()
      cache_put(@cache_key, result)
      result
    end
    # Render items...
  end
end
```

### Render Cache

```elixir
# Cache rendered output
Raxol.RenderCache.enable()

# Clear specific cache
Raxol.RenderCache.invalidate(component_id)

# Clear all
Raxol.RenderCache.clear()
```

## Concurrency

### Async Operations

```elixir
defmodule AsyncComponent do
  use Raxol.Component
  
  def mount(state) do
    # Non-blocking data fetch
    Task.async(fn ->
      fetch_data()
    end)
    %{state | loading: true}
  end
  
  def handle_info({ref, data}, state) do
    {:update, %{state | data: data, loading: false}}
  end
end
```

### Parallel Rendering

```elixir
# Render components in parallel
results = Raxol.parallel_render([
  component1,
  component2,
  component3
])
```

## Network Optimization

### WebSocket Compression

```elixir
config :raxol, :websocket,
  compress: true,
  compress_level: 6
```

### Delta Updates

```elixir
# Send only changes over network
Raxol.LiveView.configure(
  delta_updates: true,
  batch_interval: 50  # ms
)
```

## Testing Performance

```elixir
defmodule PerfTest do
  use Raxol.PerformanceCase
  
  @tag :performance
  test "renders under 1ms" do
    assert_performance fn ->
      render_component(MyComponent)
    end, max_duration: 1000  # microseconds
  end
  
  @tag :memory
  test "uses less than 1MB" do
    assert_memory_usage fn ->
      create_large_component()
    end, max_bytes: 1_048_576
  end
end
```

## Benchmarking

```elixir
# Run benchmarks
mix run bench/parser_profiling.exs

# Custom benchmark
Benchee.run(%{
  "render" => fn -> Raxol.render(component) end,
  "update" => fn -> Raxol.update(component, new_state) end
})
```

## Configuration

```elixir
config :raxol, :performance,
  # Rendering
  damage_tracking: true,
  virtual_dom: true,
  lazy_rendering: true,
  
  # Caching
  cache_components: true,
  cache_ttl: 300_000,
  
  # Limits
  max_fps: 144,
  max_buffer: 10_000,
  gc_interval: 30_000
```

## See Also

- [Architecture](ARCHITECTURE.md) - System design
- [Benchmarks](bench/) - Benchmark results
- [Troubleshooting](TROUBLESHOOTING.md) - Performance issues