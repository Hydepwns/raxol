# Raxol API Reference

Complete API documentation for the Raxol terminal framework.

## Core APIs

### Raxol
Main entry point for creating terminal applications.

```elixir
# Start terminal
{:ok, terminal} = Raxol.start_terminal(
  width: 120, height: 40, mode: :interactive,
  scrollback_limit: 10000, color_mode: :true_color
)

# Execute commands
{:ok, output} = Raxol.execute(terminal, "ls -la", timeout: 5000)
Raxol.stream_execute(terminal, "tail -f log.txt", &IO.write/1)

# Terminal control
info = Raxol.get_info(terminal)
Raxol.resize(terminal, 100, 30)
Raxol.clear(terminal)
Raxol.stop_terminal(terminal)
```

### Raxol.Minimal
Ultra-fast minimal terminal (8.8KB memory, sub-10ms startup).

```elixir
# Quick execution pattern
with {:ok, term} <- Raxol.Minimal.start_terminal(),
     :ok <- Raxol.Minimal.send_input(term, "date"),
     output <- Raxol.Minimal.read_output(term),
     :ok <- Raxol.Minimal.stop(term) do
  output
end
```

### Raxol.Component
Base for reusable terminal UI components.

```elixir
defmodule MyButton do
  use Raxol.Component
  
  @impl true
  def init(props) do
    %{label: props[:label] || "Button", pressed: false}
  end
  
  @impl true
  def render(state, _props) do
    style = if state.pressed, do: "[pressed]", else: "[normal]"
    "#{style} #{state.label}"
  end
  
  @impl true
  def handle_event(:key_press, " ", state) when state.enabled do
    {:ok, %{state | pressed: true}}
  end
end
```

## Terminal Emulation

### Raxol.Terminal.Emulator
Core terminal emulator with VT100/ANSI support (3.3μs/op parsing).

```elixir
# Create emulator
emulator = Raxol.Terminal.Emulator.new(80, 24,
  scrollback_limit: 10000, color_mode: :true_color,
  mouse_tracking: true, bracketed_paste: true
)

# Process ANSI sequences
{emulator, _} = Raxol.Terminal.Emulator.process_input(
  emulator, "\e[1;31mRed Bold\e[0m"
)

# Cursor operations
{x, y} = Raxol.Terminal.Emulator.get_cursor_position(emulator)
emulator = Raxol.Terminal.Emulator.set_cursor_position(emulator, 10, 5)
emulator = Raxol.Terminal.Emulator.move_cursor(emulator, :up, 3)

# Screen operations
emulator = Raxol.Terminal.Emulator.clear_screen(emulator)
emulator = Raxol.Terminal.Emulator.switch_to_alternate_screen(emulator)
```

### Raxol.Terminal.Buffer
Efficient screen buffer with cell-based storage.

```elixir
# Create and manage buffer
buffer = Raxol.Terminal.Buffer.new(80, 24, default_style: %{fg: :white})
buffer = Raxol.Terminal.Buffer.resize(buffer, 100, 30)

# Write content
buffer = Raxol.Terminal.Buffer.write(buffer, 10, 5, "Styled Text", %{
  fg: :bright_green, bg: :dark_blue, bold: true
})

# Read content
content = Raxol.Terminal.Buffer.get_content(buffer)
cell = Raxol.Terminal.Buffer.get_cell(buffer, 10, 5)
```

### Raxol.Terminal.Parser
High-performance ANSI parser (30x faster than standard implementations).

```elixir
# Parse sequences
{:ok, tokens} = Raxol.Terminal.Parser.parse("Normal \e[1;31mRed\e[0m")
# => [{:text, "Normal "}, {:csi, [1, 31], "", "m"}, ...]

# Stream parsing with callback
Raxol.Terminal.Parser.parse(input, fn
  {:text, text} -> IO.write(text)
  {:csi, params, _, "m"} -> apply_sgr(params)
  {:osc, 0, title} -> set_window_title(title)
end)
```

## UI Components

### Layout Components

#### Box
```elixir
<Box padding={2} margin={1} border="rounded" borderColor="blue" width="50%">
  Content
</Box>
```

#### Grid
```elixir
<Grid columns={3} gap={2}>
  <GridItem colSpan={2}>Wide column</GridItem>
  <GridItem>Narrow column</GridItem>
</Grid>
```

#### Stack
```elixir
<Stack direction="horizontal" spacing={2} align="center">
  <Button>First</Button>
  <Button>Second</Button>
</Stack>
```

### Input Components

#### TextInput
```elixir
<TextInput
  value={@username}
  onChange="update_username"
  placeholder="Enter username..."
  maxLength={20}
  validation={~r/^[a-zA-Z0-9_]+$/}
/>
```

#### Select
```elixir
<Select
  value={@country}
  onChange="select_country"
  options={[
    %{value: "us", label: "United States"},
    %{value: "uk", label: "United Kingdom"}
  ]}
/>
```

#### Checkbox
```elixir
<Checkbox checked={@agreed} onChange="toggle_terms">
  I accept the terms
</Checkbox>
```

### Display Components

#### Table
```elixir
<Table
  data={@users}
  columns={[
    %{key: "name", label: "Name", width: 30},
    %{key: "email", label: "Email", width: 40}
  ]}
  onRowClick="select_user"
  selectable
  sortable
/>
```

#### ProgressBar
```elixir
<ProgressBar
  value={@progress}
  max={100}
  showLabel
  color={if @progress < 50, do: "yellow", else: "green"}
/>
```

## Error Handling

### Raxol.Core.ErrorHandling
Functional error handling with Result types.

```elixir
# Safe execution
case ErrorHandling.safe_call(fn -> risky_operation() end) do
  {:ok, result} -> handle_success(result)
  {:error, reason} -> handle_error(reason)
end

# Pipeline with error propagation
with {:ok, validated} <- ErrorHandling.safe_call(fn -> validate(input) end),
     {:ok, transformed} <- ErrorHandling.safe_call(fn -> transform(validated) end) do
  {:ok, transformed}
end

# Result transformations
ErrorHandling.map({:ok, 5}, &(&1 * 2))  # {:ok, 10}
ErrorHandling.unwrap_or({:error, :fail}, 0)  # 0
```

## State Management

### Raxol.UI.State.Store
Redux-style state management.

```elixir
# Create store with reducer
{:ok, store} = Raxol.UI.State.Store.create(
  initial_state: %{count: 0},
  reducer: fn 
    :increment, state -> %{state | count: state.count + 1}
    :decrement, state -> %{state | count: state.count - 1}
  end
)

# Dispatch actions
Raxol.UI.State.Store.dispatch(store, :increment)

# Subscribe to changes
Raxol.UI.State.Store.subscribe(store, fn state ->
  IO.puts("Count: #{state.count}")
end)
```

### Raxol.UI.State.Context
Context API for prop drilling avoidance.

```elixir
{:ok, context} = Raxol.UI.State.Context.create(:theme, %{bg: :black})
Raxol.UI.State.Context.provide(context, :theme, %{bg: :dark_blue})
theme = Raxol.UI.State.Context.consume(context, :theme)
```

## Plugin System

```elixir
defmodule MyPlugin do
  use Raxol.Plugin
  
  @impl true
  def init(config), do: {:ok, %{config: config}}
  
  @impl true
  def handle_command("hello", _args, state) do
    {:reply, "Hello from plugin!", state}
  end
end

# Register and execute
Raxol.Plugin.register(MyPlugin, %{name: "my_plugin"})
{:ok, result} = Raxol.Plugin.execute("my_plugin", "hello", [])
```

## Event System

```elixir
# Subscribe and publish
Raxol.Events.subscribe(UserLoggedIn)
Raxol.Events.publish(%UserLoggedIn{user_id: "123"})

# Event bus
Raxol.Events.Bus.register_handler(:user_action, &Logger.info/1)
Raxol.Events.Bus.emit(:user_action, %{type: :click, pos: {10, 20}})
```

## Performance

### Benchmarks
```elixir
results = Raxol.Benchmarks.Performance.run_all()
memory_stats = Raxol.Benchmarks.Performance.MemoryUsage.benchmark()
```

### Metrics
```elixir
Raxol.Metrics.record(:response_time, 125, :milliseconds)
metrics = Raxol.Metrics.get_metrics(:response_time)
```

## Security

### Encryption
```elixir
{:ok, encrypted} = Raxol.Security.Encryption.encrypt("data", key_id: "master")
{:ok, plaintext} = Raxol.Security.Encryption.decrypt(encrypted, key_id: "master")
```

### Audit
```elixir
Raxol.Audit.log_event(%{
  type: :user_action, user_id: "123",
  action: "delete", resource: "/file"
})
```

## Advanced Features

### Session Management
```elixir
{:ok, session} = Raxol.Session.create(%{user_id: "123", persist: true})
{:ok, session} = Raxol.Session.restore(session_id)
```

### Animation
```elixir
animation = Raxol.Animation.create(
  duration: 1000, easing: :ease_in_out,
  from: %{x: 0}, to: %{x: 100}
)
```

### Themes
```elixir
theme = Raxol.Theme.load("dark_mode")
Raxol.Theme.apply(terminal, theme)
```

## Configuration

```elixir
# config/config.exs
config :raxol,
  terminal: [default_width: 80, default_height: 24],
  performance: [render_fps: 60, max_memory: 10_000_000],
  security: [encryption: :aes_256_gcm, audit_retention: 90]
```

## Error Patterns

All Raxol APIs use consistent error handling:

```elixir
{:ok, result} = Raxol.some_function()
{:error, :not_found} = Raxol.find_something("missing")
{:error, %{reason: :invalid_input, details: "..."}}

case Raxol.risky_operation() do
  {:ok, result} -> process(result)
  {:error, :timeout} -> retry_with_backoff()
  {:error, reason} -> Logger.error("Failed: #{inspect(reason)}")
end
```