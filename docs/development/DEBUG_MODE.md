# Debug Mode

`Raxol.Debug` provides runtime debugging with four verbosity levels, performance monitoring, and structured logging. It integrates with BaseManager and supports timer management.

## Debug Levels

| Level | What it does | When to use |
|-------|-------------|-------------|
| `:off` | Nothing | Production |
| `:basic` | Essential logs | General dev work |
| `:detailed` | Verbose logs with metadata | Troubleshooting |
| `:verbose` | Everything, including perf metrics | Performance analysis |

## Quick Start

```elixir
Raxol.Debug.enable(:basic)
Raxol.Debug.enable(:detailed)
Raxol.Debug.enable(:verbose)
Raxol.Debug.disable()
```

### Component-Specific

```elixir
if Raxol.Debug.debug_enabled?(:terminal) do
  IO.inspect(state, label: "Terminal State")
end

# Components by level:
# :basic    -> [:terminal, :web]
# :detailed -> [:terminal, :web, :benchmark, :parser]
# :verbose  -> all
```

## Logging

### Basic

```elixir
Raxol.Debug.debug_log(:terminal, "Processing input",
  context: %{key: key, modifiers: modifiers})

Raxol.Debug.debug_log(:parser, "ANSI sequence detected",
  context: %{sequence: sequence},
  metadata: [session_id: session_id])
```

### Structured

```elixir
Raxol.Debug.log_terminal_state(emulator, "State after input")
Raxol.Debug.log_ansi_sequence(sequence, "Processing ESC sequence",
  metadata: [line: 42])
Raxol.Debug.log_event_flow(:key_press, event_data, handler_result,
  metadata: [component: :input_handler])

Raxol.Debug.log_render_metrics(%{
  frame_time_us: 16_000,
  dirty_regions: 3,
  buffer_size: 1024,
  operations_count: 42
})
```

## Profiling

### Timing

```elixir
result = Raxol.Debug.time_debug(:terminal, "render", fn ->
  render_terminal(buffer)
end)
# Output: [DEBUG] terminal - render completed in 15.3ms
```

### Inspect

```elixir
result = Raxol.Debug.inspect_debug(:parser, "parse", input, fn ->
  parse_ansi(input)
end)
# Logs both input and output of the function
```

## Advanced

### Process State Dump

```elixir
Raxol.Debug.dump_process_state(:terminal)
# Shows: memory, reductions, message queue, stacktrace, linked processes
```

### Breakpoints

```elixir
Raxol.Debug.debug_breakpoint(:terminal, "Before state mutation")
# In IEx, pauses and waits for Enter
```

### Performance Monitoring

At `:detailed` or `:verbose` levels, metrics are collected every 100ms automatically:
```
[DEBUG] Performance: memory=%{total: 104857600, processes: 52428800, ...}
[DEBUG] Performance: run_queue=0
```

### Stats and Export

```elixir
stats = Raxol.Debug.stats()
# => %{log_count: 1523, trace_count: 342, profile_count: 89, ...}

Raxol.Debug.clear_stats()
Raxol.Debug.export("debug_session.json")
```

## Configuration

### TOML

```toml
[debug]
level = "detailed"          # off, basic, detailed, verbose
max_logs = 10000
max_traces = 5000
performance_sampling = 100  # ms
export_on_error = true
```

### Runtime

```elixir
level = Raxol.Config.get([:debug, :level], default: "off")
|> String.to_atom()
Raxol.Debug.enable(level)
```

### Environment Variable

```bash
DEBUG_LEVEL=verbose iex -S mix
```

```elixir
debug_level = System.get_env("DEBUG_LEVEL", "off") |> String.to_atom()
Raxol.Debug.enable(debug_level)
```

## Usage Examples

### Development Workflow

```elixir
defmodule MyModule do
  def process_input(input) do
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

### Terminal Troubleshooting

```elixir
Raxol.Debug.enable(:verbose)

emulator
|> process_input("\e[31mRed\e[0m")
|> tap(fn state ->
  Raxol.Debug.log_terminal_state(state, "After color change")
  Raxol.Debug.log_ansi_sequence("\e[31m", "Color sequence")
end)

Raxol.Debug.export("terminal_debug.json")
```

### Performance Analysis

```elixir
Raxol.Debug.enable(:verbose)

for _ <- 1..100 do
  Raxol.Debug.time_debug(:benchmark, "render", fn ->
    render_frame(buffer)
  end)
end

stats = Raxol.Debug.stats()
IO.puts("Total profile count: #{stats.profile_count}")
Raxol.Debug.export("performance_analysis.json")
```

## Removing Debug Code in Production

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

Or with a module attribute:

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

## Logger Integration

| Debug Level | Logger Level | Metadata |
|-------------|-------------|----------|
| `:off` | `:info` | Standard |
| `:basic` | `:debug` | Standard |
| `:detailed` | `:debug` | `[:module, :function, :line, :pid]` |
| `:verbose` | `:debug` | All metadata |

## Performance Impact

| Level | CPU | Memory |
|-------|-----|--------|
| `:off` | None | None |
| `:basic` | ~1-2% | Minimal |
| `:detailed` | ~5-10% | ~1MB for logs |
| `:verbose` | ~15-20% | ~5MB for logs and traces |

## Best Practices

Guard expensive debug operations behind level checks:
```elixir
if Raxol.Debug.debug_enabled?(:my_component) do
  expensive_debug_operation()
end
```

Use structured context, not string interpolation:
```elixir
# good
Raxol.Debug.debug_log(:handler, "Event processed",
  context: %{event_type: :key_press, key: "a", modifiers: [:ctrl]})

# bad
Raxol.Debug.debug_log(:handler,
  "Event processed: key_press a with ctrl at #{DateTime.utc_now()}")
```

Clean up after debugging:
```elixir
Raxol.Debug.export("debug_#{Date.utc_today()}.json")
Raxol.Debug.clear_stats()
Raxol.Debug.disable()
```

For hot paths, sample instead of logging everything:
```elixir
if :rand.uniform() < 0.1 do
  Raxol.Debug.debug_log(:hot_path, "Sampled execution")
end
```

## Troubleshooting

**Debug server not started:** Add `{Raxol.Debug, []}` to your supervision tree.

**Too many logs:** Limit storage with `{Raxol.Debug, [max_logs: 1000, max_traces: 500]}` or clear periodically.

**Performance impact too high:** Use sampling (see above) or drop to a lower debug level.

## Export Format

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
      "context": {},
      "timestamp": "2024-01-15T10:00:01Z"
    }
  ],
  "traces": [],
  "profiles": {},
  "exported_at": "2024-01-15T11:00:00Z"
}
```
