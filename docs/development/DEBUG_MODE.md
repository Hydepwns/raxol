# Enhanced Debug Mode

## Overview

Raxol v1.4.1 introduces a comprehensive debug mode system with four levels of verbosity, performance monitoring, and detailed logging capabilities. Enhanced in v1.5.4 with BaseManager integration and improved timer management. The `Raxol.Debug` module provides runtime debugging tools for development and troubleshooting.

## Debug Levels

| Level | Description | Use Case |
|-------|-------------|----------|
| `:off` | No debug output | Production |
| `:basic` | Essential debug logs | General development |
| `:detailed` | Verbose logs with metadata | Troubleshooting |
| `:verbose` | Everything including performance metrics | Performance analysis |

## Quick Start

### Enabling Debug Mode

```elixir
# Enable basic debugging
Raxol.Debug.enable(:basic)

# Enable detailed debugging with metadata
Raxol.Debug.enable(:detailed)

# Enable verbose debugging with performance monitoring
Raxol.Debug.enable(:verbose)

# Disable debugging
Raxol.Debug.disable()
```

### Component-Specific Debugging

```elixir
# Check if debugging is enabled for a component
if Raxol.Debug.debug_enabled?(:terminal) do
  IO.inspect(state, label: "Terminal State")
end

# Components checked based on level:
# :basic    -> [:terminal, :web]
# :detailed -> [:terminal, :web, :benchmark, :parser]
# :verbose  -> all components
```

## Logging Functions

### Basic Debug Logging

```elixir
# Simple debug log
Raxol.Debug.debug_log(:terminal, "Processing input",
  context: %{key: key, modifiers: modifiers})

# With metadata for filtering
Raxol.Debug.debug_log(:parser, "ANSI sequence detected",
  context: %{sequence: sequence},
  metadata: [session_id: session_id])
```

### Structured Logging

```elixir
# Log terminal state
Raxol.Debug.log_terminal_state(emulator, "State after input")

# Log ANSI sequences
Raxol.Debug.log_ansi_sequence(sequence, "Processing ESC sequence",
  metadata: [line: 42])

# Log event flow
Raxol.Debug.log_event_flow(:key_press, event_data, handler_result,
  metadata: [component: :input_handler])

# Log render metrics
Raxol.Debug.log_render_metrics(%{
  frame_time_us: 16_000,
  dirty_regions: 3,
  buffer_size: 1024,
  operations_count: 42
})
```

## Performance Profiling

### Time Execution

```elixir
# Time a function and log results in debug mode
result = Raxol.Debug.time_debug(:terminal, "render", fn ->
  render_terminal(buffer)
end)

# Output in debug mode:
# [DEBUG] terminal - render completed in 15.3ms
```

### Inspect Execution

```elixir
# Inspect input and output of a function
result = Raxol.Debug.inspect_debug(:parser, "parse", input, fn ->
  parse_ansi(input)
end)

# Output in debug mode:
# [DEBUG] parser - parse input: "\e[31mHello\e[0m"
# [DEBUG] parser - parse output: [{:sgr, [31]}, {:text, "Hello"}, {:sgr, [0]}]
```

## Advanced Features

### Process State Dumping

```elixir
# Dump current process state
Raxol.Debug.dump_process_state(:terminal)

# Output includes:
# - Process info (memory, reductions, message queue)
# - Current stacktrace
# - Process dictionary
# - Linked processes
```

### Debug Breakpoints

```elixir
# Conditional breakpoint (only in interactive mode)
Raxol.Debug.debug_breakpoint(:terminal, "Before state mutation")

# In IEx:
# [DEBUG] Debug breakpoint hit: Before state mutation
# Component: terminal
# Process: #PID<0.123.0>
# Press Enter to continue...
```

### Performance Monitoring

When debug level is `:detailed` or `:verbose`, performance metrics are automatically collected every 100ms:

```elixir
# Automatic output in logs:
# [DEBUG] Performance: memory=%{total: 104857600, processes: 52428800, ...}
# [DEBUG] Performance: run_queue=0
```

## Integration with GenServer

### Debug Server Statistics

```elixir
# Get debug statistics
stats = Raxol.Debug.stats()
# => %{
#   log_count: 1523,
#   trace_count: 342,
#   profile_count: 89,
#   start_time: ~U[2024-01-15 10:00:00Z],
#   current_level: :detailed
# }

# Clear statistics
Raxol.Debug.clear_stats()

# Export debug data
Raxol.Debug.export("debug_session.json")
```

## Configuration Integration

### Via TOML Configuration

```toml
# config/raxol.toml
[debug]
level = "detailed"        # off, basic, detailed, verbose
max_logs = 10000
max_traces = 5000
performance_sampling = 100  # milliseconds
export_on_error = true
```

### Via Runtime Configuration

```elixir
# Set debug level from config
level = Raxol.Config.get([:debug, :level], default: "off")
|> String.to_atom()
Raxol.Debug.enable(level)
```

## Use Cases

### Development Workflow

```elixir
defmodule MyModule do
  def process_input(input) do
    # Only runs in debug mode
    Raxol.Debug.debug_log(:input, "Received input",
      context: %{input: input})

    result = Raxol.Debug.time_debug(:input, "processing", fn ->
      do_process(input)
    end)

    Raxol.Debug.debug_log(:input, "Processed successfully",
      context: %{result: result})

    result
  end
end
```

### Troubleshooting Terminal Issues

```elixir
# Enable verbose debugging
Raxol.Debug.enable(:verbose)

# Process some input
emulator
|> process_input("\e[31mRed\e[0m")
|> tap(fn state ->
  Raxol.Debug.log_terminal_state(state, "After color change")
  Raxol.Debug.log_ansi_sequence("\e[31m", "Color sequence")
end)

# Check what happened
stats = Raxol.Debug.stats()
IO.inspect(stats, label: "Debug Stats")

# Export for analysis
Raxol.Debug.export("terminal_debug.json")
```

### Performance Analysis

```elixir
# Enable performance tracking
Raxol.Debug.enable(:verbose)

# Run operations
for _ <- 1..100 do
  Raxol.Debug.time_debug(:benchmark, "render", fn ->
    render_frame(buffer)
  end)
end

# Analyze
stats = Raxol.Debug.stats()
IO.puts("Total profile count: #{stats.profile_count}")

# Export detailed data
Raxol.Debug.export("performance_analysis.json")
```

## Conditional Compilation

To completely remove debug code in production:

```elixir
defmodule MyModule do
  if Mix.env() != :prod do
    defp debug_log(message) do
      Raxol.Debug.debug_log(:my_module, message)
    end
  else
    defp debug_log(_message), do: :ok
  end
end
```

## Logger Integration

Debug mode automatically configures Elixir's Logger:

| Debug Level | Logger Level | Metadata |
|-------------|-------------|----------|
| `:off` | `:info` | Standard |
| `:basic` | `:debug` | Standard |
| `:detailed` | `:debug` | `[:module, :function, :line, :pid]` |
| `:verbose` | `:debug` | All metadata |

## Performance Impact

| Level | Performance Impact | Memory Impact |
|-------|-------------------|---------------|
| `:off` | None | None |
| `:basic` | ~1-2% | Minimal |
| `:detailed` | ~5-10% | ~1MB for logs |
| `:verbose` | ~15-20% | ~5MB for logs and traces |

## Best Practices

### 1. Use Appropriate Levels

```elixir
# Development
Raxol.Debug.enable(:basic)

# Troubleshooting specific issue
Raxol.Debug.enable(:detailed)

# Performance investigation
Raxol.Debug.enable(:verbose)

# Production
Raxol.Debug.disable()
```

### 2. Component-Specific Debugging

```elixir
# Only log if actually debugging this component
if Raxol.Debug.debug_enabled?(:my_component) do
  expensive_debug_operation()
end
```

### 3. Structured Context

```elixir
# Good - structured data
Raxol.Debug.debug_log(:handler, "Event processed",
  context: %{
    event_type: :key_press,
    key: "a",
    modifiers: [:ctrl],
    timestamp: DateTime.utc_now()
  })

# Bad - unstructured string
Raxol.Debug.debug_log(:handler,
  "Event processed: key_press a with ctrl at #{DateTime.utc_now()}")
```

### 4. Clean Up After Debugging

```elixir
# After debugging session
Raxol.Debug.clear_stats()
Raxol.Debug.disable()

# Or export for later analysis
Raxol.Debug.export("debug_#{Date.utc_today()}.json")
Raxol.Debug.clear_stats()
```

### 5. Use Guards for Production

```elixir
defmodule MyModule do
  @debug_enabled Mix.env() != :prod

  if @debug_enabled do
    defp debug_trace(data) do
      Raxol.Debug.debug_log(:my_module, "Trace", context: data)
    end
  else
    defp debug_trace(_data), do: :ok
  end
end
```

## Troubleshooting

### Debug Server Not Started

```elixir
# Ensure it's in your application supervision tree
children = [
  {Raxol.Debug, []},
  # other children...
]
```

### Too Many Logs

```elixir
# Limit log storage
{Raxol.Debug, [max_logs: 1000, max_traces: 500]}

# Or clear periodically
Process.send_after(self(), :clear_debug, 60_000)
```

### Performance Impact Too High

```elixir
# Use sampling for hot paths
if :rand.uniform() < 0.1 do  # 10% sampling
  Raxol.Debug.debug_log(:hot_path, "Sampled execution")
end
```

## CLI Integration

```bash
# Enable debug mode via environment variable
DEBUG_LEVEL=verbose iex -S mix

# Or in your app
debug_level = System.get_env("DEBUG_LEVEL", "off") |> String.to_atom()
Raxol.Debug.enable(debug_level)
```

## Export Format

Debug exports are JSON files containing:

```json
{
  "level": "detailed",
  "stats": {
    "log_count": 1523,
    "trace_count": 342,
    "profile_count": 89,
    "start_time": "2024-01-15T10:00:00Z"
  },
  "logs": [
    {
      "level": "detailed",
      "message": "Processing input",
      "context": {...},
      "timestamp": "2024-01-15T10:00:01Z"
    }
  ],
  "traces": [...],
  "profiles": {...},
  "exported_at": "2024-01-15T11:00:00Z"
}
```