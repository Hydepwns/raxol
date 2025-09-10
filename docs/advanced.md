# Advanced Topics

Deep-dive into plugins, functional patterns, and error handling.

## Plugin System

### Creating Plugins

```elixir
defmodule MyPlugin do
  use Raxol.Plugin
  
  def init(config) do
    {:ok, %{config: config}}
  end
  
  def handle_event(:terminal_ready, state, terminal) do
    Raxol.Terminal.write(terminal, "Plugin loaded!")
    {:ok, state}
  end
end

# Register plugin
Raxol.PluginManager.register(MyPlugin, name: "my_plugin")
```

### Plugin Lifecycle

```elixir
# Hooks available
def on_load(state), do: {:ok, state}
def on_start(state, runtime), do: {:ok, state}
def on_stop(state), do: :ok
def on_unload(state), do: :ok

# Hot reload
Raxol.PluginManager.reload("my_plugin")
```

### Plugin Communication

```elixir
# Subscribe to events
def init(_) do
  Raxol.Events.subscribe(:input_received)
  {:ok, %{}}
end

# Publish events
Raxol.Events.publish(:custom_event, data)

# Call other plugins
Raxol.PluginManager.call("other_plugin", :method, args)
```

## Functional Error Handling

### Core Patterns

```elixir
# Safe execution
case Raxol.Core.ErrorHandling.safe_call(fn ->
  risky_operation()
end) do
  {:ok, result} -> handle_success(result)
  {:error, error} -> handle_error(error)
end

# With default
result = safe_call_with_default(fn ->
  might_fail()
end, default_value)

# GenServer calls
{:ok, result} = safe_genserver_call(pid, :request, timeout)
```

### Result Types

```elixir
defmodule MyModule do
  @type result(t) :: {:ok, t} | {:error, term()}
  
  @spec process(binary()) :: result(map())
  def process(data) do
    with {:ok, parsed} <- parse(data),
         {:ok, validated} <- validate(parsed),
         {:ok, transformed} <- transform(validated) do
      {:ok, transformed}
    end
  end
end
```

### Error Recovery

```elixir
# Circuit breaker
defmodule ServiceClient do
  use Raxol.Core.ErrorRecovery.CircuitBreaker,
    threshold: 5,
    timeout: 30_000
    
  def call_service(args) do
    with_circuit_breaker(:service_name, fn ->
      external_call(args)
    end)
  end
end

# Retry with backoff
retry_with_backoff(fn ->
  network_request()
end, max_attempts: 3, initial_delay: 100)
```

## Web Interface (Phoenix LiveView)

### Terminal in LiveView

```elixir
defmodule MyAppWeb.TerminalLive do
  use Phoenix.LiveView
  use Raxol.LiveView
  
  def mount(_params, _session, socket) do
    {:ok, term} = Raxol.Terminal.start(width: 80, height: 24)
    
    socket = socket
    |> assign(:terminal, term)
    |> attach_terminal(term)
    
    {:ok, socket}
  end
  
  def handle_event("input", %{"key" => key}, socket) do
    Raxol.Terminal.send_input(socket.assigns.terminal, key)
    {:noreply, socket}
  end
end
```

### Component Bridge

```elixir
# Terminal component renders in browser
def render(assigns) do
  ~H"""
  <div class="terminal-container">
    <.live_terminal 
      id="main-terminal"
      terminal={@terminal}
      theme={@theme}
    />
  </div>
  """
end

# Real-time updates
def handle_info({:terminal_update, changes}, socket) do
  {:noreply, push_event(socket, "terminal:update", changes)}
end
```

### WASH-Style Continuity

```elixir
# Save terminal state
state = Raxol.Terminal.serialize(terminal)
{:ok, session_id} = Raxol.Sessions.save(state)

# Restore on reconnect
{:ok, state} = Raxol.Sessions.load(session_id)
terminal = Raxol.Terminal.deserialize(state)

# Migrate terminal to web
Raxol.WebBridge.migrate(terminal, to: :web)
```

## Performance Optimization

### Memory Management

```elixir
# ETS-backed caching
defmodule Cache do
  use Raxol.Core.Performance.Cache,
    table: :my_cache,
    ttl: :timer.minutes(5),
    max_size: 1000
    
  def expensive_operation(key) do
    cached(key, fn ->
      compute_expensive_value(key)
    end)
  end
end
```

### Batch Processing

```elixir
# Batch updates
Raxol.batch(fn ->
  Enum.each(items, &update_item/1)
end)

# Debounce rapid events
use Raxol.Debounce, delay: 100
def handle_input(text) do
  # Auto-debounced
  search(text)
end
```

### Profiling

```elixir
# Profile critical paths
defmodule Critical do
  use Raxol.Core.Performance.Profiler
  
  @profile
  def important_function(args) do
    # Automatically profiled
    process(args)
  end
end

# View metrics
Raxol.Metrics.Dashboard.open()
```

## Advanced Terminal Features

### Custom Escape Sequences

```elixir
# Register custom handler
Raxol.Terminal.ANSI.register_handler("?99", fn params, term ->
  handle_custom_sequence(params, term)
end)

# Define DCS handler
Raxol.Terminal.DCS.register("$", fn data, term ->
  process_custom_data(data, term)
end)
```

### Graphics Protocols

```elixir
# Sixel support
image = File.read!("image.six")
Raxol.Terminal.write(term, image)

# Kitty graphics
Raxol.Terminal.Graphics.display(term, "image.png",
  protocol: :kitty,
  placement: {10, 5}
)

# iTerm2 inline images
Raxol.Terminal.Graphics.inline(term, image_data,
  width: "100%",
  height: "auto"
)
```

## Migration Guide

### From v1.0 to v1.1 (Functional)

```elixir
# Old (imperative)
try do
  result = process(data)
  if result do
    handle_success(result)
  else
    handle_failure()
  end
rescue
  e -> handle_error(e)
end

# New (functional)
case safe_call(fn -> process(data) end) do
  {:ok, result} -> handle_success(result)
  {:error, _} -> handle_failure()
end
```

### Process Dictionary Migration

```elixir
# Old (deprecated)
Process.put(:key, value)
Process.get(:key)

# New (recommended)
ProcessStore.put(:key, value)
ProcessStore.get(:key)

# Or with explicit agent
{:ok, agent} = Agent.start_link(fn -> %{} end)
Agent.update(agent, &Map.put(&1, :key, value))
Agent.get(agent, &Map.get(&1, :key))
```

## See Also

- [Development](development.md) - Setup and workflow
- [API Reference](api-reference.md) - Complete API
- [Components](components.md) - UI components