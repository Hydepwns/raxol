---
title: Raxol API Reference
description: Complete API documentation for the Raxol terminal framework with examples
date: 2025-08-10
author: Raxol Team
section: documentation
tags: [api, reference, documentation, framework]
---

# Raxol API Reference

Complete API documentation for the Raxol terminal framework with examples.

## Table of Contents
- [Core Modules](#core-modules)
- [Components](#components)
- [Terminal Emulator](#terminal-emulator)
- [Event System](#event-system)
- [Plugin System](#plugin-system)
- [Utilities](#utilities)

---

## Core Modules

### Raxol.Application

The base module for creating Raxol applications.

```elixir
defmodule MyApp do
  use Raxol.Application
  
  @impl true
  def mount(params, socket) do
    # Initialize application state
    {:ok, 
     socket
     |> assign(title: "My App")
     |> assign(user: params[:user])}
  end
  
  @impl true
  def handle_event(event, params, socket) do
    # Handle global events
    {:noreply, socket}
  end
  
  @impl true
  def handle_info(message, socket) do
    # Handle process messages
    {:noreply, socket}
  end
  
  @impl true
  def terminate(reason, socket) do
    # Cleanup on shutdown
    :ok
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <Screen title={@title}>
      <!-- Your UI here -->
    </Screen>
    """
  end
end
```

#### Starting an Application

```elixir
# From command line
mix raxol.run --app MyApp

# Programmatically
{:ok, pid} = Raxol.start_app(MyApp, %{user: "alice"})

# With options
Raxol.start_app(MyApp, %{}, [
  width: 120,
  height: 40,
  theme: :dark
])
```

### Raxol.Component

Base module for creating reusable components.

```elixir
defmodule MyComponent do
  use Raxol.Component
  
  # Define props with validation
  prop :title, :string, required: true
  prop :items, {:list, :map}, default: []
  prop :onSelect, :function
  
  # Component lifecycle
  @impl true
  def mount(socket) do
    {:ok, assign(socket, selected: nil)}
  end
  
  @impl true
  def update(assigns, socket) do
    # Called when props change
    socket = 
      if assigns.items != socket.assigns.items do
        assign(socket, selected: nil)
      else
        socket
      end
    {:ok, socket}
  end
  
  @impl true
  def handle_event("select", %{"id" => id}, socket) do
    socket = assign(socket, selected: id)
    
    # Call parent callback if provided
    if socket.assigns.onSelect do
      socket.assigns.onSelect.(id)
    end
    
    {:noreply, socket}
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <Box>
      <Heading><%= @title %></Heading>
      <List>
        <%= for item <- @items do %>
          <ListItem 
            key={item.id}
            selected={@selected == item.id}
            onClick="select"
            params={%{id: item.id}}
          >
            <%= item.name %>
          </ListItem>
        <% end %>
      </List>
    </Box>
    """
  end
end
```

---

## Components

### Layout Components

#### Box
Container with padding, margin, and borders.

```elixir
<Box 
  padding={2}
  margin={1}
  border="rounded"
  borderColor="blue"
  backgroundColor="gray.900"
  width="50%"
  height={10}
>
  Content here
</Box>
```

**Props:**
- `padding` - Space inside the box (number or {top, right, bottom, left})
- `margin` - Space outside the box
- `border` - Border style: "none" | "single" | "double" | "rounded" | "heavy"
- `borderColor` - Color of the border
- `backgroundColor` - Background color
- `width` - Width (number, percentage, or "auto")
- `height` - Height

#### Grid
Create grid layouts.

```elixir
<Grid columns={3} gap={2}>
  <GridItem colSpan={2}>
    <Text>Wide column</Text>
  </GridItem>
  <GridItem>
    <Text>Narrow column</Text>
  </GridItem>
  <GridItem colSpan={3}>
    <Text>Full width</Text>
  </GridItem>
</Grid>
```

**Props:**
- `columns` - Number of columns
- `rows` - Number of rows (optional)
- `gap` - Space between items
- `columnGap` - Horizontal gap
- `rowGap` - Vertical gap

#### Stack
Stack elements vertically or horizontally.

```elixir
<Stack direction="horizontal" spacing={2} align="center">
  <Button>First</Button>
  <Button>Second</Button>
  <Button>Third</Button>
</Stack>
```

**Props:**
- `direction` - "vertical" | "horizontal"
- `spacing` - Space between children
- `align` - Alignment: "start" | "center" | "end" | "stretch"
- `justify` - Justification: "start" | "center" | "end" | "between" | "around"

### Input Components

#### TextInput
Single-line text input.

```elixir
<TextInput
  value={@username}
  onChange="update_username"
  placeholder="Enter username..."
  maxLength={20}
  validation={~r/^[a-zA-Z0-9_]+$/}
  error={@username_error}
/>
```

**Props:**
- `value` - Current value
- `onChange` - Change event handler
- `onSubmit` - Submit event handler
- `placeholder` - Placeholder text
- `maxLength` - Maximum length
- `validation` - Regex pattern or function
- `error` - Error message to display
- `disabled` - Disable input
- `password` - Hide input (password field)

#### Select
Dropdown selection.

```elixir
<Select
  value={@country}
  onChange="select_country"
  options={[
    %{value: "us", label: "United States"},
    %{value: "uk", label: "United Kingdom"},
    %{value: "ca", label: "Canada"}
  ]}
  placeholder="Choose a country"
/>
```

**Props:**
- `value` - Selected value
- `options` - List of {value, label} maps
- `onChange` - Selection change handler
- `multiple` - Allow multiple selection
- `searchable` - Enable search/filter

#### Checkbox
Checkbox input.

```elixir
<Checkbox
  checked={@terms_accepted}
  onChange="toggle_terms"
  indeterminate={@partial_selection}
>
  I accept the terms and conditions
</Checkbox>
```

**Props:**
- `checked` - Checked state
- `onChange` - Change handler
- `indeterminate` - Indeterminate state
- `disabled` - Disable checkbox

### Display Components

#### Table
Display tabular data.

```elixir
<Table
  data={@users}
  columns={[
    %{key: "id", label: "ID", width: 10},
    %{key: "name", label: "Name", width: 30},
    %{key: "email", label: "Email", width: 40},
    %{key: "status", label: "Status", width: 20, 
      render: fn user -> 
        if user.active, do: "Active", else: "Inactive"
      end}
  ]}
  onRowClick="select_user"
  selectable
  sortable
  paginate={20}
/>
```

**Props:**
- `data` - List of row data
- `columns` - Column definitions
- `onRowClick` - Row click handler
- `selectable` - Enable row selection
- `sortable` - Enable column sorting
- `paginate` - Items per page

#### ProgressBar
Show progress.

```elixir
<ProgressBar
  value={@progress}
  max={100}
  showLabel
  color={if @progress < 50, do: "yellow", else: "green"}
  format={fn value, max -> 
    "#{value}/#{max} (#{round(value/max * 100)}%)"
  end}
/>
```

**Props:**
- `value` - Current value
- `max` - Maximum value
- `showLabel` - Show percentage label
- `color` - Bar color
- `format` - Custom label formatter

#### Chart
Data visualization.

```elixir
<Chart
  type="bar"
  data={[
    %{label: "Jan", value: 100},
    %{label: "Feb", value: 120},
    %{label: "Mar", value: 90},
    %{label: "Apr", value: 150}
  ]}
  width={60}
  height={20}
  color="cyan"
  showAxes
  showGrid
/>
```

**Props:**
- `type` - "bar" | "line" | "scatter" | "pie"
- `data` - Chart data
- `width` - Chart width
- `height` - Chart height
- `color` - Data color(s)
- `showAxes` - Show X/Y axes
- `showGrid` - Show grid lines
- `showLegend` - Show legend

---

## Terminal Emulator

### Raxol.Terminal.Emulator

Core terminal emulator with ANSI/VT100+ support.

```elixir
# Create an emulator
{:ok, emulator} = Raxol.Terminal.Emulator.new(width: 80, height: 24)

# Process input
emulator = Raxol.Terminal.Emulator.process_input(emulator, "Hello\x1b[31mRed Text\x1b[0m")

# Get display buffer
buffer = Raxol.Terminal.Emulator.get_buffer(emulator)

# Handle resize
emulator = Raxol.Terminal.Emulator.resize(emulator, 120, 40)
```

#### Escape Sequences Support

```elixir
# Cursor movement
"\x1b[H"        # Home
"\x1b[5;10H"    # Move to row 5, column 10
"\x1b[A"        # Up
"\x1b[B"        # Down
"\x1b[C"        # Forward
"\x1b[D"        # Backward

# Text formatting
"\x1b[1m"       # Bold
"\x1b[3m"       # Italic
"\x1b[4m"       # Underline
"\x1b[7m"       # Reverse

# Colors
"\x1b[31m"      # Red foreground
"\x1b[42m"      # Green background
"\x1b[38;5;123m" # 256 color
"\x1b[38;2;255;0;128m" # RGB color

# Screen control
"\x1b[2J"       # Clear screen
"\x1b[K"        # Clear line
"\x1b[?1049h"   # Alternate screen
"\x1b[?1049l"   # Normal screen
```

### Mouse Support

```elixir
# Enable mouse tracking
emulator = Raxol.Terminal.Emulator.enable_mouse(emulator, :all_events)

# Handle mouse events
{:ok, event} = Raxol.Terminal.Mouse.parse_event(input)
# => %{type: :click, button: :left, x: 10, y: 5}

# Mouse modes
:normal          # Button press/release
:button_event    # Button events with modifiers
:any_event       # All mouse events including motion
:highlight       # Highlight tracking
```

### Sixel Graphics

```elixir
# Enable sixel graphics
emulator = Raxol.Terminal.Emulator.enable_sixel(emulator)

# Display an image
sixel_data = Raxol.Terminal.Sixel.encode_image(image_path)
emulator = Raxol.Terminal.Emulator.process_input(emulator, sixel_data)

# Configure sixel
Raxol.Terminal.Sixel.configure(%{
  palette: :adaptive,
  max_colors: 256,
  compression: true
})
```

---

## Event System

### Event Handling

```elixir
defmodule MyHandler do
  use Raxol.EventHandler
  
  @impl true
  def handle_key(key, modifiers, state) do
    case {key, modifiers} do
      {"s", [:ctrl]} -> save_file(state)
      {"q", [:ctrl]} -> {:stop, :normal, state}
      {"c", [:ctrl, :shift]} -> copy_selection(state)
      _ -> {:ok, state}
    end
  end
  
  @impl true
  def handle_mouse(event, state) do
    case event.type do
      :click -> handle_click(event, state)
      :drag -> handle_drag(event, state)
      :scroll -> handle_scroll(event, state)
      _ -> {:ok, state}
    end
  end
  
  @impl true
  def handle_resize(width, height, state) do
    state = %{state | width: width, height: height}
    redraw(state)
    {:ok, state}
  end
end
```

### Custom Events

```elixir
# Subscribe to events
Raxol.EventBus.subscribe("user:*")
Raxol.EventBus.subscribe("data:updated")

# Publish events
Raxol.EventBus.publish("user:login", %{user_id: 123})
Raxol.EventBus.publish("data:updated", %{table: "users", id: 456})

# Handle in component
@impl true
def handle_info({:event, "user:login", data}, socket) do
  {:noreply, assign(socket, current_user: data)}
end
```

---

## Plugin System

### Creating a Plugin

```elixir
defmodule MyPlugin do
  use Raxol.Plugin
  
  @impl true
  def init(config) do
    {:ok, %{config: config, state: :ready}}
  end
  
  @impl true
  def handle_command("my-command", args, state) do
    result = process_command(args)
    {:reply, result, state}
  end
  
  @impl true
  def handle_event(:before_render, data, state) do
    # Modify render data
    modified_data = transform(data)
    {:ok, modified_data, state}
  end
  
  @impl true
  def exports do
    %{
      commands: ["my-command", "another-command"],
      shortcuts: [{"ctrl+m", "my-command"}],
      menu_items: [
        %{label: "My Plugin", command: "my-command"}
      ]
    }
  end
end

# Register plugin
Raxol.Plugins.register(MyPlugin, %{option: "value"})
```

### Plugin Hooks

```elixir
# Available hooks
:before_render    # Before rendering
:after_render     # After rendering
:before_input     # Before processing input
:after_input      # After processing input
:on_error         # On error
:on_startup       # On application startup
:on_shutdown      # On application shutdown
```

---

## Utilities

### Themes

```elixir
# Define a theme
theme = %Raxol.Theme{
  name: "My Theme",
  colors: %{
    primary: "#007acc",
    secondary: "#68217a",
    background: "#1e1e1e",
    foreground: "#cccccc",
    error: "#f44747",
    warning: "#ffcc00",
    success: "#89d185"
  },
  typography: %{
    fontFamily: "Cascadia Code",
    fontSize: 14,
    lineHeight: 1.5
  },
  spacing: %{
    unit: 4,
    small: 8,
    medium: 16,
    large: 32
  }
}

# Apply theme
Raxol.Theme.apply(theme)

# Get current theme
current = Raxol.Theme.current()
```

### Performance Profiling

```elixir
# Start profiling
Raxol.Profile.start()

# Profile specific operation
Raxol.Profile.measure("database_query") do
  fetch_data()
end

# Get profile report
report = Raxol.Profile.report()
# => %{
#   database_query: %{count: 10, total: 123.45, avg: 12.34, max: 20.1, min: 8.2}
# }

# Stop profiling
Raxol.Profile.stop()
```

### Debugging

```elixir
# Enable debug mode
Raxol.Debug.enable()

# Log debug information
Raxol.Debug.log("Component rendered", %{id: "my-component", props: props})

# Inspect terminal state
Raxol.Debug.inspect_terminal()

# Trace events
Raxol.Debug.trace_events([:key, :mouse, :resize])

# Disable debug mode
Raxol.Debug.disable()
```

### Testing

```elixir
defmodule MyComponentTest do
  use Raxol.ComponentCase
  
  test "renders correctly" do
    {:ok, view} = render_component(MyComponent, %{title: "Test"})
    
    assert view |> has_text?("Test")
    assert view |> find(".button") |> length() == 2
  end
  
  test "handles events" do
    {:ok, view} = render_component(Counter, %{})
    
    view |> click_button("Increment")
    assert view |> has_text?("Count: 1")
    
    view |> click_button("Decrement")
    assert view |> has_text?("Count: 0")
  end
  
  test "keyboard interaction" do
    {:ok, view} = render_component(Editor, %{})
    
    view |> send_keys("Hello")
    assert view |> get_input_value() == "Hello"
    
    view |> send_key(:enter)
    assert view |> has_text?("Submitted: Hello")
  end
end
```

---

## Advanced Topics

### Custom Renderers

```elixir
defmodule CustomRenderer do
  @behaviour Raxol.Renderer
  
  @impl true
  def render(element, context) do
    case element.type do
      :custom_chart -> render_chart(element, context)
      _ -> Raxol.Renderer.Default.render(element, context)
    end
  end
  
  defp render_chart(element, context) do
    # Custom rendering logic
    data = element.props.data
    # ... generate terminal output
  end
end

# Use custom renderer
Raxol.configure(renderer: CustomRenderer)
```

### Middleware

```elixir
defmodule LoggingMiddleware do
  @behaviour Raxol.Middleware
  
  @impl true
  def process(event, next) do
    Logger.info("Event: #{inspect(event)}")
    result = next.(event)
    Logger.info("Result: #{inspect(result)}")
    result
  end
end

# Add middleware
Raxol.Middleware.add(LoggingMiddleware)
```

### Custom Components with Native Rendering

```elixir
defmodule NativeComponent do
  use Raxol.Component, native: true
  
  @impl true
  def render_native(assigns, terminal) do
    # Direct terminal manipulation
    terminal
    |> Raxol.Terminal.move_cursor(10, 5)
    |> Raxol.Terminal.write_text("Native rendering", color: :red)
    |> Raxol.Terminal.draw_box(0, 0, 20, 10, style: :double)
  end
end
```

---

## Configuration

### Application Configuration

```elixir
# config/config.exs
config :raxol,
  default_theme: :dark,
  hot_reload: true,
  reload_paths: ["lib"],
  plugins_dir: "priv/plugins",
  max_fps: 60,
  buffer_size: 10_000,
  
  # Terminal settings
  terminal: [
    default_width: 80,
    default_height: 24,
    scrollback_limit: 10_000,
    enable_mouse: true,
    enable_sixel: true
  ],
  
  # Web interface settings
  web: [
    port: 4000,
    host: "localhost",
    enable_ssl: false,
    max_connections: 100
  ],
  
  # Performance settings
  performance: [
    render_debounce: 16,  # ~60 FPS
    event_batch_size: 10,
    cache_components: true
  ]
```

---

## Error Handling

### Component Error Boundaries

```elixir
defmodule ErrorBoundary do
  use Raxol.Component
  
  @impl true
  def mount(socket) do
    {:ok, assign(socket, error: nil)}
  end
  
  @impl true
  def handle_error(error, _stacktrace, socket) do
    Logger.error("Component error: #{inspect(error)}")
    {:noreply, assign(socket, error: error)}
  end
  
  @impl true
  def render(assigns) do
    ~H"""
    <%= if @error do %>
      <Box border="single" borderColor="red">
        <Text color="red">Error: <%= @error %></Text>
        <Button onClick="retry">Retry</Button>
      </Box>
    <% else %>
      <%= render_slot(@inner_content) %>
    <% end %>
    """
  end
end
```

---

This API reference covers the core functionality of Raxol. For more examples and advanced usage, check out the [examples directory](./examples/) and the [component showcase](./examples/showcase.ex).