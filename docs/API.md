# Raxol API Documentation

## Table of Contents

1. [Core APIs](#core-apis)
2. [Terminal Emulation](#terminal-emulation)
3. [UI Components](#ui-components)
4. [State Management](#state-management)
5. [Plugin System](#plugin-system)
6. [Event System](#event-system)
7. [Performance APIs](#performance-apis)
8. [Security APIs](#security-apis)

---

## Core APIs

### Raxol

The main entry point for the Raxol terminal framework.

```elixir
# Start a terminal session
{:ok, terminal} = Raxol.start_terminal(
  width: 80,
  height: 24,
  mode: :interactive
)

# Run a command
Raxol.execute(terminal, "ls -la")

# Stop terminal
Raxol.stop_terminal(terminal)
```

### Raxol.Minimal

Ultra-fast minimal terminal for lightweight use cases.

```elixir
# Start minimal terminal (<10ms startup)
{:ok, terminal} = Raxol.Minimal.start_terminal()

# Send input
Raxol.Minimal.send_input(terminal, "Hello World")

# Get state
state = Raxol.Minimal.get_state(terminal)
```

---

## Terminal Emulation

### Raxol.Terminal.Emulator

Core terminal emulator with full VT100/ANSI support.

```elixir
# Create emulator
emulator = Raxol.Terminal.Emulator.new(80, 24)

# Process input
{emulator, output} = Raxol.Terminal.Emulator.process_input(emulator, "\e[1;31mRed Text\e[0m")

# Handle ANSI sequences
emulator = Raxol.Terminal.Emulator.handle_ansi(emulator, "\e[2J") # Clear screen
```

### Raxol.Terminal.Buffer

Screen buffer management for terminal rendering.

```elixir
# Create buffer
buffer = Raxol.Terminal.Buffer.new(80, 24)

# Write to buffer
buffer = Raxol.Terminal.Buffer.write(buffer, 0, 0, "Hello", %{color: :green})

# Get content
content = Raxol.Terminal.Buffer.get_content(buffer)

# Clear buffer
buffer = Raxol.Terminal.Buffer.clear(buffer)
```

### Raxol.Terminal.Parser

High-performance ANSI/VT100 sequence parser (3.3μs/op).

```elixir
# Parse ANSI sequences
{:ok, tokens} = Raxol.Terminal.Parser.parse("\e[1;31mHello\e[0m")

# Parse CSI sequence
{:csi, params, intermediate, final} = Raxol.Terminal.Parser.parse_csi("\e[1;2H")

# Parse OSC sequence
{:osc, number, data} = Raxol.Terminal.Parser.parse_osc("\e]0;Title\a")
```

---

## UI Components

### Raxol.Component

Base component system for building terminal UIs.

```elixir
defmodule MyComponent do
  use Raxol.Component
  
  @impl true
  def init(props) do
    %{count: 0}
  end
  
  @impl true
  def render(state, props) do
    """
    Count: #{state.count}
    Press + to increment
    """
  end
  
  @impl true
  def handle_event(:key_press, "+", state) do
    {:ok, %{state | count: state.count + 1}}
  end
end

# Use component
{:ok, component} = Raxol.Component.start(MyComponent, %{})
```

### Raxol.UI.Layout

Layout engines for terminal UI composition.

```elixir
# Flexbox layout
layout = Raxol.UI.Layout.flexbox([
  {:box, %{flex: 1}, "Left"},
  {:box, %{flex: 2}, "Center"},
  {:box, %{flex: 1}, "Right"}
])

# Grid layout
grid = Raxol.UI.Layout.grid([
  ["A", "B", "C"],
  ["D", "E", "F"]
], columns: 3, rows: 2)

# Render layout
Raxol.UI.Layout.render(layout, terminal)
```

### Raxol.UI.Components

Pre-built UI components library.

```elixir
# Progress bar
progress = Raxol.UI.Components.ProgressBar.new(
  value: 75,
  max: 100,
  width: 50,
  color: :green
)

# Table
table = Raxol.UI.Components.Table.new(
  headers: ["Name", "Age", "City"],
  rows: [
    ["Alice", "30", "NYC"],
    ["Bob", "25", "LA"]
  ]
)

# Modal
modal = Raxol.UI.Components.Modal.new(
  title: "Confirm",
  content: "Are you sure?",
  buttons: ["Yes", "No"]
)
```

---

## State Management

### Raxol.UI.State.Store

Redux-style state management for complex applications.

```elixir
# Define reducer
defmodule AppReducer do
  def reduce(:increment, state), do: %{state | count: state.count + 1}
  def reduce(:decrement, state), do: %{state | count: state.count - 1}
  def reduce(_, state), do: state
end

# Create store
{:ok, store} = Raxol.UI.State.Store.create(
  initial_state: %{count: 0},
  reducer: AppReducer
)

# Dispatch actions
Raxol.UI.State.Store.dispatch(store, :increment)

# Subscribe to changes
Raxol.UI.State.Store.subscribe(store, fn state ->
  IO.puts("Count: #{state.count}")
end)

# Get current state
state = Raxol.UI.State.Store.get_state(store)
```

### Raxol.UI.State.Context

React-style context API for prop drilling avoidance.

```elixir
# Create context
{:ok, context} = Raxol.UI.State.Context.create(:theme, %{
  background: :black,
  foreground: :white
})

# Provide context
Raxol.UI.State.Context.provide(context, :theme, %{
  background: :dark_blue,
  foreground: :cyan
})

# Consume context
theme = Raxol.UI.State.Context.consume(context, :theme)
```

---

## Plugin System

### Raxol.Plugin

Extensible plugin system for adding functionality.

```elixir
defmodule MyPlugin do
  use Raxol.Plugin
  
  @impl true
  def init(config) do
    {:ok, %{config: config}}
  end
  
  @impl true
  def handle_command("hello", _args, state) do
    {:reply, "Hello from plugin!", state}
  end
end

# Register plugin
Raxol.Plugin.register(MyPlugin, %{name: "my_plugin"})

# Execute plugin command
{:ok, result} = Raxol.Plugin.execute("my_plugin", "hello", [])
```

### Raxol.Plugin.Manager

Plugin lifecycle management and coordination.

```elixir
# Load plugin
{:ok, plugin} = Raxol.Plugin.Manager.load_plugin("path/to/plugin.ex")

# Enable plugin
Raxol.Plugin.Manager.enable_plugin(plugin)

# List active plugins
plugins = Raxol.Plugin.Manager.list_plugins()

# Hot-reload plugin
{:ok, _} = Raxol.Plugin.Manager.reload_plugin(plugin)
```

---

## Event System

### Raxol.Events

Event-driven architecture for decoupled communication.

```elixir
# Define event
defmodule UserLoggedIn do
  use Raxol.Events.Event
  
  defstruct [:user_id, :timestamp]
end

# Subscribe to events
Raxol.Events.subscribe(UserLoggedIn)

# Publish event
Raxol.Events.publish(%UserLoggedIn{
  user_id: "123",
  timestamp: DateTime.utc_now()
})

# Handle events
receive do
  %UserLoggedIn{user_id: id} ->
    IO.puts("User #{id} logged in")
end
```

### Raxol.Events.Bus

Central event bus for system-wide communication.

```elixir
# Register handler
Raxol.Events.Bus.register_handler(:user_action, fn event ->
  Logger.info("User action: #{inspect(event)}")
end)

# Emit event
Raxol.Events.Bus.emit(:user_action, %{
  type: :click,
  position: {10, 20}
})

# Batch events
Raxol.Events.Bus.batch([
  {:event1, data1},
  {:event2, data2}
])
```

---

## Performance APIs

### Raxol.Benchmarks.Performance

Performance measurement and optimization tools.

```elixir
# Run all benchmarks
results = Raxol.Benchmarks.Performance.run_all()

# Run specific benchmark
render_perf = Raxol.Benchmarks.Performance.benchmark_rendering()

# Memory profiling
memory_stats = Raxol.Benchmarks.Performance.MemoryUsage.benchmark_memory_usage()

# Check for memory leaks
leak_detected = Raxol.Benchmarks.Performance.check_memory_leaks()
```

### Raxol.Metrics

Real-time metrics collection and monitoring.

```elixir
# Start metrics collection
Raxol.Metrics.start_collection()

# Record metric
Raxol.Metrics.record(:response_time, 125, :milliseconds)

# Get metrics
metrics = Raxol.Metrics.get_metrics(:response_time)

# Export metrics
Raxol.Metrics.export(:prometheus, "metrics.txt")
```

---

## Security APIs

### Raxol.Security.Encryption

Enterprise-grade encryption for sensitive data.

```elixir
# Encrypt data
{:ok, encrypted} = Raxol.Security.Encryption.encrypt(
  "sensitive data",
  key_id: "master_key"
)

# Decrypt data
{:ok, plaintext} = Raxol.Security.Encryption.decrypt(
  encrypted,
  key_id: "master_key"
)

# Key rotation
{:ok, new_key} = Raxol.Security.Encryption.rotate_key("master_key")
```

### Raxol.Audit

Comprehensive audit logging for compliance.

```elixir
# Log audit event
Raxol.Audit.log_event(%{
  type: :user_action,
  user_id: "123",
  action: "delete_file",
  resource: "/etc/config",
  timestamp: DateTime.utc_now()
})

# Query audit logs
events = Raxol.Audit.query(
  user_id: "123",
  from: ~D[2025-01-01],
  to: ~D[2025-01-31]
)

# Export for compliance
Raxol.Audit.export(:soc2, "audit_report.json")
```

---

## Advanced Usage

### Session Management

```elixir
# Create session with persistence
{:ok, session} = Raxol.Session.create(%{
  user_id: "123",
  persist: true,
  timeout: 3600
})

# Save session state
Raxol.Session.save_state(session)

# Restore session
{:ok, session} = Raxol.Session.restore(session_id)

# Share session (collaborative editing)
{:ok, share_url} = Raxol.Session.share(session)
```

### Terminal Multiplexing

```elixir
# Create multiplexer (tmux-like)
{:ok, mux} = Raxol.Multiplexer.create()

# Add panes
{:ok, pane1} = Raxol.Multiplexer.add_pane(mux, :vertical)
{:ok, pane2} = Raxol.Multiplexer.add_pane(mux, :horizontal)

# Switch panes
Raxol.Multiplexer.focus_pane(mux, pane1)

# Resize panes
Raxol.Multiplexer.resize_pane(pane1, width: 60)
```

### Animation System

```elixir
# Create animation
animation = Raxol.Animation.create(
  duration: 1000,
  easing: :ease_in_out,
  from: %{x: 0, opacity: 0},
  to: %{x: 100, opacity: 1}
)

# Start animation
Raxol.Animation.start(animation)

# Spring physics
spring = Raxol.Animation.spring(
  stiffness: 100,
  damping: 10,
  mass: 1
)
```

### Theme System

```elixir
# Load theme
theme = Raxol.Theme.load("dark_mode")

# Apply theme
Raxol.Theme.apply(terminal, theme)

# Create custom theme
custom_theme = Raxol.Theme.create(%{
  colors: %{
    background: "#1e1e1e",
    foreground: "#d4d4d4",
    accent: "#007acc"
  },
  fonts: %{
    family: "Cascadia Code",
    size: 14
  }
})

# Hot-reload theme
Raxol.Theme.hot_reload(terminal, custom_theme)
```

---

## Error Handling

All Raxol APIs follow consistent error handling patterns:

```elixir
# Success tuple
{:ok, result} = Raxol.some_function()

# Error tuple with reason
{:error, :not_found} = Raxol.find_something("missing")

# Error with details
{:error, %{reason: :invalid_input, details: "Width must be positive"}}

# Using with pattern matching
case Raxol.risky_operation() do
  {:ok, result} -> 
    # Handle success
    process(result)
    
  {:error, :timeout} ->
    # Retry logic
    retry_with_backoff()
    
  {:error, reason} ->
    # Generic error handling
    Logger.error("Operation failed: #{inspect(reason)}")
end
```

---

## Configuration

Raxol can be configured through application environment:

```elixir
# config/config.exs
config :raxol,
  terminal: [
    default_width: 80,
    default_height: 24,
    scrollback_size: 10000
  ],
  performance: [
    render_fps: 60,
    max_memory_per_session: 10_000_000  # 10MB
  ],
  security: [
    encryption_algorithm: :aes_256_gcm,
    audit_retention_days: 90
  ]
```

---

## Best Practices

1. **Resource Management**: Always clean up resources
   ```elixir
   {:ok, terminal} = Raxol.start_terminal()
   try do
     # Use terminal
   after
     Raxol.stop_terminal(terminal)
   end
   ```

2. **Error Handling**: Use pattern matching for robust error handling
   ```elixir
   with {:ok, terminal} <- Raxol.start_terminal(),
        {:ok, result} <- Raxol.execute(terminal, command),
        :ok <- Raxol.stop_terminal(terminal) do
     {:ok, result}
   else
     {:error, reason} -> handle_error(reason)
   end
   ```

3. **Performance**: Use minimal mode for lightweight operations
   ```elixir
   # For simple terminal operations
   {:ok, terminal} = Raxol.Minimal.start_terminal()
   
   # For full features
   {:ok, terminal} = Raxol.start_terminal(mode: :full)
   ```

4. **Testing**: Use mock implementations in tests
   ```elixir
   # In test environment
   config :raxol,
     use_mock_terminal: true,
     use_mock_graphics: true
   ```

---

## Migration Guide

### From v0.x to v1.0

1. **Module Renames**:
   - `Raxol.Terminal` → `Raxol.Terminal.Emulator`
   - `Raxol.UI` → `Raxol.UI.Components`

2. **API Changes**:
   - `start/1` → `start_terminal/1`
   - `stop/1` → `stop_terminal/1`

3. **New Features**:
   - Minimal mode for ultra-fast startup
   - WASH-style session continuity
   - Enterprise security features

See the Migration Guide section for detailed migration instructions.

---

## Support

- **Documentation**: https://hexdocs.pm/raxol
- **GitHub**: https://github.com/hydepwns/raxol
- **Issues**: https://github.com/hydepwns/raxol/issues
- **Discord**: Join our community for support

---

## License

Raxol is released under the MIT License.