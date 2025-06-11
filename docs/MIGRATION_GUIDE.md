# Raxol Terminal Emulator Migration Guide

## Overview

This guide provides instructions for migrating to the latest version of the Raxol Terminal Emulator. The latest version includes significant improvements in metrics collection, visualization, and alerting capabilities.

For API reference, see [API Documentation](../examples/guides/02_core_concepts/api/README.md).

## Major Changes

### 1. Metrics System

The metrics system has been completely redesigned with the following changes:

#### Old System

```elixir
# Old metrics recording
Raxol.Terminal.Metrics.record("operation", value)
Raxol.Terminal.Metrics.set_alert("operation", threshold)
```

#### New System

```elixir
# New metrics recording
Raxol.Core.Metrics.UnifiedCollector.record_metric(
  "operation",
  :performance,
  value,
  tags: %{component: "terminal"}
)

# New alert configuration
Raxol.Core.Metrics.AlertManager.add_rule(%{
  name: "operation_alert",
  metric_name: "operation",
  condition: {:above, threshold},
  severity: :warning
})
```

### 2. Buffer Management

The buffer management system has been consolidated:

#### Old System

```elixir
# Old buffer management
Raxol.Terminal.Buffer.Manager.create_buffer()
Raxol.Terminal.Buffer.EnhancedManager.create_buffer()
```

#### New System

```elixir
# New unified buffer management
Raxol.Terminal.Buffer.Manager.create_buffer(
  type: :standard,
  options: %{
    size: {80, 24},
    scrollback: 1000
  }
)
```

### 3. Input/Output System

The input/output system has been streamlined:

#### Old System

```elixir
# Old input processing
Raxol.Terminal.Input.Processor.process_input(input)
Raxol.Terminal.Input.Manager.handle_input(input)

# Old output handling
Raxol.Terminal.Output.Manager.write_output(output)
```

#### New System

```elixir
# New unified input/output handling
Raxol.Terminal.IO.Manager.process_input(input)
Raxol.Terminal.IO.Manager.write_output(output)
```

### 4. Rendering System

The rendering system has been unified:

#### Old System

```elixir
# Old rendering
Raxol.Terminal.Renderer.render(buffer)
Raxol.Terminal.Renderer.GPURenderer.render(buffer)
```

#### New System

```elixir
# New unified rendering
Raxol.Terminal.Renderer.render(buffer, %{
  mode: :gpu,  # or :cpu
  options: %{
    double_buffering: true,
    vsync: true
  }
})
```

## Configuration Changes

### 1. Metrics Configuration

#### Old Configuration

```elixir
config :raxol, :metrics,
  enabled: true,
  interval: 1000
```

#### New Configuration

```elixir
config :raxol, :metrics_collector,
  retention_period: :timer.hours(24),
  max_samples: 1000,
  flush_interval: :timer.seconds(5),
  cloud_enabled: true

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

### 2. Buffer Configuration

#### Old Configuration

```elixir
config :raxol, :buffer,
  size: {80, 24},
  scrollback: 1000
```

#### New Configuration

```elixir
config :raxol, :buffer,
  default_options: %{
    size: {80, 24},
    scrollback: 1000,
    type: :standard,
    performance: %{
      double_buffering: true,
      compression: true
    }
  }
```

### 3. Rendering Configuration

#### Old Configuration

```elixir
config :raxol, :renderer,
  mode: :gpu,
  vsync: true
```

#### New Configuration

```elixir
config :raxol, :renderer,
  default_options: %{
    mode: :gpu,
    vsync: true,
    double_buffering: true,
    performance: %{
      batch_size: 1000,
      cache_size: 100
    }
  }
```

## Migration Steps

1. **Update Dependencies**

   ```elixir
   # mix.exs
   defp deps do
     [
       {:raxol, "~> 2.0"}
     ]
   end
   ```

2. **Update Configuration**

   - Replace old configuration with new configuration format
   - Update metrics configuration
   - Update buffer configuration
   - Update rendering configuration

3. **Update Code**

   - Replace old metrics calls with new unified collector
   - Update buffer management code
   - Update input/output handling
   - Update rendering code

4. **Update Tests**
   - Update test helpers
   - Update test cases
   - Add new test cases for new features

## Common Issues

### 1. Metrics Migration

**Issue**: Missing metrics after migration
**Solution**: Ensure all metrics are recorded with proper types and tags

```elixir
# Incorrect
Raxol.Core.Metrics.UnifiedCollector.record_metric("operation", value)

# Correct
Raxol.Core.Metrics.UnifiedCollector.record_metric(
  "operation",
  :performance,
  value,
  tags: %{component: "terminal"}
)
```

### 2. Buffer Management

**Issue**: Buffer operations failing
**Solution**: Update buffer creation and management code

```elixir
# Incorrect
Raxol.Terminal.Buffer.Manager.create_buffer()

# Correct
Raxol.Terminal.Buffer.Manager.create_buffer(
  type: :standard,
  options: %{
    size: {80, 24},
    scrollback: 1000
  }
)
```

### 3. Rendering

**Issue**: Rendering performance issues
**Solution**: Update rendering configuration and code

```elixir
# Incorrect
Raxol.Terminal.Renderer.render(buffer)

# Correct
Raxol.Terminal.Renderer.render(buffer, %{
  mode: :gpu,
  options: %{
    double_buffering: true,
    vsync: true
  }
})
```

## Testing Migration

1. **Update Test Helpers**

   ```elixir
   # test/support/test_helper.ex
   defmodule Raxol.TestHelper do
     def setup_metrics_test(opts \\ []) do
       # New metrics test setup
     end

     def setup_buffer_test(opts \\ []) do
       # New buffer test setup
     end
   end
   ```

2. **Update Test Cases**

   ```elixir
   # test/raxol/terminal/buffer_test.exs
   defmodule Raxol.Terminal.BufferTest do
     use ExUnit.Case
     alias Raxol.TestHelper

     setup do
       {:ok, _} = TestHelper.setup_buffer_test()
       :ok
     end

     test "buffer operations" do
       # New buffer tests
     end
   end
   ```

## Performance Considerations

1. **Metrics Collection**

   - Use appropriate retention periods
   - Configure reasonable sample limits
   - Enable cloud integration when needed

2. **Buffer Management**

   - Use appropriate buffer sizes
   - Configure scrollback limits
   - Enable performance optimizations

3. **Rendering**
   - Use GPU rendering when available
   - Enable double buffering
   - Configure appropriate batch sizes

## Support

For additional help with migration:

- Check the [documentation](docs/README.md)
- Review the [API reference](../examples/guides/02_core_concepts/api/README.md)
- Contact the development team
- Create an issue in the project repository
