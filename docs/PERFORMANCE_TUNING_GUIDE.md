# Raxol Performance Tuning Guide

## Overview

Raxol includes advanced performance monitoring and optimization systems that automatically adapt to your usage patterns. This guide explains how to configure, monitor, and optimize Raxol for maximum performance in production environments.

## Quick Start

### Enabling Performance Monitoring

```elixir
# In your application.ex
def start(_type, _args) do
  children = [
    # ... your other supervisors
    Raxol.Performance.TelemetryInstrumentation,
    Raxol.Performance.PredictiveOptimizer,
    Raxol.Performance.AdaptiveOptimizer
  ]
  
  # Setup default telemetry handlers
  Raxol.Performance.TelemetryInstrumentation.setup_default_handlers()
  
  opts = [strategy: :one_for_one, name: MyApp.Supervisor]
  Supervisor.start_link(children, opts)
end
```

### Basic Performance Configuration

```elixir
# config/prod.exs
config :raxol, :performance,
  # Enable adaptive optimization
  adaptive_optimization: true,
  
  # Cache configuration
  cache_sizes: %{
    component_render: 2000,    # Increase for UI-heavy apps
    font_metrics: 1000,        # Increase for text-heavy apps
    cell_cache: 5000,         # Increase for terminal-heavy apps
    csi_parser: 500           # Increase for ANSI-heavy apps
  },
  
  # Performance thresholds (in microseconds)
  slow_operation_threshold: 1000,
  high_memory_threshold: 0.8,
  cache_hit_rate_target: 0.85
```

## Performance Monitoring

### Real-time Performance Status

```elixir
# Check current performance status
{:ok, status} = Raxol.Performance.AdaptiveOptimizer.get_optimization_status()

# Sample output:
%{
  optimization_cycles_completed: 45,
  successful_optimizations: 38,
  active_optimizations: [:cache_optimization, :memory_management],
  current_adaptive_thresholds: %{
    slow_operation_threshold: 1200,
    cache_hit_rate_target: 0.82
  },
  performance_trend: :improving,
  next_optimization_in: 8500  # milliseconds
}
```

### Telemetry Events

Raxol emits comprehensive telemetry events you can monitor:

```elixir
# Terminal parsing performance
[:raxol, :terminal, :parse] 
# Measurements: %{duration: microseconds, success: boolean}
# Metadata: %{sequence_type: :csi | :osc | :dcs, sequence_length: integer}

# UI rendering performance  
[:raxol, :ui, :component, :render]
# Measurements: %{duration: microseconds, rendered_nodes: integer}
# Metadata: %{component: atom, props_hash: binary}

# Cache performance
[:raxol, :cache, :hit | :miss | :eviction]
# Measurements: %{count: integer, evicted_count: integer}
# Metadata: %{cache_name: atom, key: binary}
```

### Custom Telemetry Handlers

```elixir
# Monitor slow operations
:telemetry.attach(
  "my-app-slow-ops",
  [:raxol, :terminal, :parse],
  fn _event, %{duration: duration}, metadata, _config ->
    if duration > 5000 do  # 5ms threshold
      Logger.warning("Slow terminal parsing: #{duration}μs for #{metadata.sequence_type}")
      # Send to monitoring system
      MyApp.Monitoring.record_slow_operation(:terminal_parse, duration, metadata)
    end
  end,
  nil
)
```

## Optimization Strategies

### 1. Cache Optimization

#### Automatic Cache Tuning

The adaptive optimizer automatically adjusts cache sizes based on hit rates:

```elixir
# Manual cache optimization
{:ok, recommendations} = Raxol.Performance.PredictiveOptimizer.get_recommendations()

# Sample output:
%{
  cache_recommendations: [
    {:component_render, :increase_size, 0.65},  # Low hit rate
    {:font_metrics, :optimal, 0.92},           # Good hit rate
    {:csi_parser, :review_eviction_policy, 0.75}
  ]
}
```

#### Manual Cache Configuration

```elixir
# config/runtime.exs
cache_config = case System.get_env("APP_WORKLOAD_TYPE") do
  "ui_heavy" ->
    %{component_render: 5000, font_metrics: 2000, cell_cache: 2000, csi_parser: 300}
  "terminal_heavy" ->
    %{component_render: 1000, font_metrics: 500, cell_cache: 8000, csi_parser: 1000}
  "balanced" ->
    %{component_render: 2000, font_metrics: 1000, cell_cache: 3000, csi_parser: 500}
  _ ->
    %{component_render: 1000, font_metrics: 500, cell_cache: 2000, csi_parser: 300}
end

config :raxol, :performance, cache_sizes: cache_config
```

### 2. Memory Management

#### Memory Pressure Monitoring

```elixir
# The adaptive optimizer monitors memory pressure automatically
# Configure thresholds based on your environment

Raxol.Performance.AdaptiveOptimizer.configure_thresholds(%{
  high_memory_threshold: 0.85,  # Trigger optimization at 85% memory usage
  memory_pressure_threshold: 0.90  # Critical threshold
})
```

#### Manual Memory Optimization

```elixir
# Force garbage collection under memory pressure
:erlang.garbage_collect()

# Reduce cache sizes temporarily
Raxol.Performance.ETSCacheManager.reduce_cache_sizes(
  [:component_render, :font_metrics], 
  0.7  # Reduce to 70% of current size
)
```

### 3. Workload-Specific Optimizations

#### High-Throughput Applications

```elixir
# config/prod.exs for high-throughput scenarios
config :raxol, :performance,
  # Larger caches for better hit rates
  cache_sizes: %{
    component_render: 10000,
    font_metrics: 5000, 
    cell_cache: 15000,
    csi_parser: 2000
  },
  
  # More aggressive optimization
  optimization_interval: 5000,  # 5 seconds
  predictive_optimization: true,
  
  # Higher thresholds
  slow_operation_threshold: 500,  # 0.5ms
  cache_hit_rate_target: 0.90
```

#### Memory-Constrained Environments

```elixir
# config/prod.exs for limited memory
config :raxol, :performance,
  # Smaller caches
  cache_sizes: %{
    component_render: 500,
    font_metrics: 250,
    cell_cache: 1000, 
    csi_parser: 150
  },
  
  # More frequent cleanup
  optimization_interval: 30000,  # 30 seconds
  memory_pressure_threshold: 0.75,
  
  # Stricter eviction policies
  cache_eviction_policy: :lru_strict
```

## Troubleshooting Performance Issues

### 1. High Response Times

**Symptoms**: Operations taking longer than expected

**Diagnosis**:
```elixir
# Check current performance metrics
{:ok, status} = Raxol.Performance.AdaptiveOptimizer.get_optimization_status()

# Look for:
# - Low cache hit rates (< 0.7)
# - High memory pressure (> 0.8)
# - Increasing performance trend

# Check slow operations
{:ok, recommendations} = Raxol.Performance.PredictiveOptimizer.get_recommendations()
case recommendations.performance_tips do
  [{:optimize_slow_operations, slow_ops}] -> 
    IO.inspect(slow_ops, label: "Slow operations")
  _ -> 
    :ok
end
```

**Solutions**:
1. Increase cache sizes for frequently accessed operations
2. Enable predictive cache warming
3. Review and optimize slow operations identified by telemetry

### 2. Memory Issues

**Symptoms**: High memory usage, frequent garbage collection

**Diagnosis**:
```elixir
# Monitor memory telemetry
:telemetry.attach(
  "memory-monitor",
  [:vm, :memory],
  fn _event, measurements, _metadata, _config ->
    total_mb = div(measurements.total, 1024 * 1024)
    process_mb = div(measurements.processes, 1024 * 1024)
    
    Logger.info("Memory usage: #{process_mb}MB processes, #{total_mb}MB total")
    
    if measurements.processes / measurements.total > 0.8 do
      Logger.warning("High process memory usage detected")
    end
  end,
  nil
)
```

**Solutions**:
1. Reduce cache sizes
2. Enable more aggressive garbage collection
3. Configure stricter eviction policies

### 3. Cache Performance Issues

**Symptoms**: Low cache hit rates, frequent cache misses

**Diagnosis**:
```elixir
# Monitor cache performance
:telemetry.attach_many(
  "cache-performance-monitor", 
  [[:raxol, :cache, :hit], [:raxol, :cache, :miss]],
  fn event, measurements, metadata, _config ->
    cache_name = metadata.cache_name
    event_type = List.last(event)
    
    # Log cache performance
    Logger.debug("Cache #{event_type} for #{cache_name}")
    
    # Track hit rates
    GenServer.cast(MyCacheMonitor, {:cache_event, cache_name, event_type})
  end,
  nil
)
```

**Solutions**:
1. Analyze access patterns and adjust cache sizes
2. Implement predictive cache warming
3. Review cache eviction policies

## Production Deployment Checklist

### Pre-deployment

- [ ] Configure performance monitoring in production config
- [ ] Set appropriate cache sizes based on expected workload
- [ ] Configure telemetry handlers for monitoring system integration
- [ ] Set up alerting for performance degradation
- [ ] Test optimization system with production-like load

### Post-deployment

- [ ] Monitor initial performance metrics
- [ ] Verify adaptive optimization is working
- [ ] Check cache hit rates and adjust if necessary
- [ ] Monitor memory usage patterns
- [ ] Review and tune performance thresholds

### Ongoing Monitoring

- [ ] Regular review of optimization status
- [ ] Monitor performance trends and patterns
- [ ] Adjust configuration based on actual usage
- [ ] Performance regression testing after updates

## Performance Metrics Reference

### Key Performance Indicators

| Metric | Good | Acceptable | Needs Attention |
|--------|------|------------|-----------------|
| Average Response Time | < 1ms | < 5ms | > 5ms |
| P95 Response Time | < 5ms | < 20ms | > 20ms |
| Cache Hit Rate | > 85% | > 70% | < 70% |
| Memory Usage | < 70% | < 85% | > 85% |
| Error Rate | < 0.1% | < 1% | > 1% |

### Telemetry Event Reference

```elixir
# Performance events emitted by Raxol
[:raxol, :terminal, :parse, :start | :stop | :exception]
[:raxol, :terminal, :render, :start | :stop | :exception] 
[:raxol, :ui, :component, :render, :start | :stop | :exception]
[:raxol, :ui, :layout, :calculate, :start | :stop | :exception]
[:raxol, :cache, :hit | :miss | :eviction]
[:raxol, :emulator, :input | :sequence | :resize, :start | :stop | :exception]
```

## Advanced Configuration

### Custom Optimization Policies

```elixir
# Define custom optimization policy
defmodule MyApp.PerformancePolicy do
  @behaviour Raxol.Performance.OptimizationPolicy
  
  def should_optimize?(analysis, state) do
    # Custom logic for when to trigger optimization
    analysis.cache_hit_rate < 0.6 or analysis.avg_response_time > 2000
  end
  
  def determine_optimizations(analysis, state) do
    # Custom optimization strategies
    case analysis.workload_type do
      :custom_heavy_load -> 
        [{:enable_turbo_mode, true}, {:increase_worker_pool, 2.0}]
      _ -> 
        Raxol.Performance.AdaptiveOptimizer.default_optimizations(analysis, state)
    end
  end
end

# Configure custom policy
config :raxol, :performance,
  optimization_policy: MyApp.PerformancePolicy
```

### Integration with External Monitoring

```elixir
# Send performance metrics to external systems
:telemetry.attach_many(
  "external-monitoring-integration",
  [
    [:raxol, :terminal, :parse],
    [:raxol, :ui, :component, :render],
    [:raxol, :cache, :hit],
    [:raxol, :cache, :miss]
  ],
  fn event, measurements, metadata, _config ->
    # Send to Prometheus, DataDog, etc.
    :prometheus.observe(:raxol_operation_duration_microseconds, 
                       measurements[:duration] || 0,
                       %{operation: Enum.join(event, "_")})
                       
    # Send to StatsD
    :statsd.timing("raxol.#{Enum.join(event, ".")}.duration", 
                   measurements[:duration] || 0)
  end,
  nil
)
```

## Support and Troubleshooting

For performance-related issues:

1. Enable debug logging: `config :logger, level: :debug`
2. Check optimization status regularly
3. Monitor telemetry events for patterns
4. Review system resource usage (CPU, memory, disk I/O)
5. Consider workload-specific optimizations

For additional support, see the main Raxol documentation or file issues at the project repository.