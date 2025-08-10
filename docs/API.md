# Raxol API Documentation

> **Version**: 1.0.0  
> **Last Updated**: 2025-08-10  
> **API Stability**: Production-ready

## Table of Contents

1. [Core APIs](#core-apis)
   - [Raxol](#raxol)
   - [Raxol.Minimal](#raxolminimal)
   - [Raxol.Component](#raxolcomponent)
2. [Terminal Emulation](#terminal-emulation)
   - [Emulator](#raxolterminalemulator)
   - [Buffer](#raxolterminalbuffer)
   - [Parser](#raxolterminalparser)
3. [UI Components](#ui-components)
   - [Component System](#raxolcomponent-1)
   - [Layout Engines](#raxoluilayout)
   - [Built-in Components](#raxoluicomponents)
4. [State Management](#state-management)
   - [Store](#raxoluistatestore)
   - [Context API](#raxoluistatecontext)
5. [Plugin System](#plugin-system)
   - [Plugin Development](#raxolplugin)
   - [Plugin Manager](#raxolpluginmanager)
6. [Event System](#event-system)
   - [Event Bus](#raxoleventsbus)
   - [Event Sourcing](#event-patterns)
7. [Performance APIs](#performance-apis)
   - [Benchmarks](#raxolbenchmarksperformance)
   - [Metrics](#raxolmetrics)
8. [Security APIs](#security-apis)
   - [Encryption](#raxolsecurityencryption)
   - [Audit Logging](#raxolaudit)
9. [Advanced Topics](#advanced-topics)
   - [Session Management](#session-management)
   - [Terminal Multiplexing](#terminal-multiplexing)
   - [Animation System](#animation-system)
   - [Theme System](#theme-system)
10. [Migration Guide](#migration-guide)
11. [Best Practices](#best-practices)

---

## Core APIs

### Raxol

The main entry point for the Raxol terminal framework. This module provides high-level functions for creating and managing terminal applications.

#### Starting a Terminal

```elixir
# Basic terminal with default settings
{:ok, terminal} = Raxol.start_terminal()

# Customized terminal with specific dimensions and options
{:ok, terminal} = Raxol.start_terminal(
  width: 120,
  height: 40,
  mode: :interactive,
  scrollback_limit: 10000,
  color_mode: :true_color,
  session_id: "main-terminal"
)

# Terminal with event handlers
{:ok, terminal} = Raxol.start_terminal(
  on_resize: fn width, height ->
    IO.puts("Terminal resized to #{width}x#{height}")
  end,
  on_key: fn key ->
    IO.puts("Key pressed: #{inspect(key)}")
  end
)
```

#### Executing Commands

```elixir
# Execute a simple command
{:ok, output} = Raxol.execute(terminal, "ls -la")

# Execute with timeout
{:ok, output} = Raxol.execute(terminal, "long-running-command", timeout: 5000)

# Execute with environment variables
{:ok, output} = Raxol.execute(terminal, "echo $MY_VAR", 
  env: %{"MY_VAR" => "Hello World"}
)

# Stream command output
Raxol.stream_execute(terminal, "tail -f /var/log/system.log", fn chunk ->
  IO.write(chunk)
end)
```

#### Terminal Control

```elixir
# Get terminal information
info = Raxol.get_info(terminal)
IO.inspect(info)
# => %{
#   width: 80,
#   height: 24,
#   cursor_position: {10, 5},
#   mode: :interactive,
#   color_support: :true_color
# }

# Resize terminal
Raxol.resize(terminal, 100, 30)

# Clear terminal
Raxol.clear(terminal)

# Reset terminal to initial state
Raxol.reset(terminal)

# Stop terminal gracefully
Raxol.stop_terminal(terminal)
```

### Raxol.Minimal

Ultra-fast minimal terminal for lightweight use cases. Optimized for sub-10ms startup time and minimal memory footprint (8.8KB).

#### When to Use Minimal Mode

- Quick command execution
- Resource-constrained environments
- Embedded systems
- High-frequency terminal operations
- Testing and CI/CD pipelines

#### Basic Usage

```elixir
# Start minimal terminal with instant startup
{:ok, terminal} = Raxol.Minimal.start_terminal()

# Start with custom configuration
{:ok, terminal} = Raxol.Minimal.start_terminal(
  width: 80,
  height: 24,
  buffer_size: 100  # Minimal scrollback
)

# Send input and get immediate response
Raxol.Minimal.send_input(terminal, "echo 'Hello'")
response = Raxol.Minimal.read_output(terminal)

# Get current state (lightweight)
state = Raxol.Minimal.get_state(terminal)
# => %{
#   cursor: {0, 0},
#   buffer: [...],
#   dimensions: {80, 24}
# }

# Quick command execution pattern
with {:ok, term} <- Raxol.Minimal.start_terminal(),
     :ok <- Raxol.Minimal.send_input(term, "date"),
     output <- Raxol.Minimal.read_output(term),
     :ok <- Raxol.Minimal.stop(term) do
  output
end
```

#### Performance Characteristics

```elixir
# Benchmark minimal vs full terminal
{time_minimal, _} = :timer.tc(fn ->
  {:ok, t} = Raxol.Minimal.start_terminal()
  Raxol.Minimal.stop(t)
end)

{time_full, _} = :timer.tc(fn ->
  {:ok, t} = Raxol.start_terminal()
  Raxol.stop_terminal(t)
end)

IO.puts("Minimal: #{time_minimal}μs, Full: #{time_full}μs")
# => Minimal: 8000μs, Full: 95000μs
```

### Raxol.Component

Simplified component API for building reusable terminal UI components. This is the recommended way to create custom components.

#### Creating a Component

```elixir
defmodule MyButton do
  use Raxol.Component
  
  @impl true
  def init(props) do
    %{
      label: props[:label] || "Button",
      pressed: false,
      enabled: props[:enabled] != false,
      on_click: props[:on_click]
    }
  end
  
  @impl true
  def render(state, _props) do
    style = if state.pressed, do: "[pressed]", else: "[normal]"
    enabled = if state.enabled, do: "", else: " (disabled)"
    
    "#{style} #{state.label}#{enabled}"
  end
  
  @impl true
  def handle_event(:key_press, " ", state) when state.enabled do
    if state.on_click, do: state.on_click.()
    {:ok, %{state | pressed: true}}
  end
  
  @impl true
  def handle_event(:key_release, " ", state) do
    {:ok, %{state | pressed: false}}
  end
  
  @impl true
  def handle_event(_, _, state), do: {:ok, state}
end

# Using the component
{:ok, button} = Raxol.Component.start(MyButton, 
  label: "Click Me!",
  on_click: fn -> IO.puts("Button clicked!") end
)
```

#### Component Lifecycle

```elixir
defmodule LifecycleExample do
  use Raxol.Component
  
  @impl true
  def init(props) do
    # Called once when component is created
    IO.puts("Component initializing")
    %{mounted: false}
  end
  
  @impl true
  def mount(state) do
    # Called when component is added to the UI tree
    IO.puts("Component mounted")
    {:ok, %{state | mounted: true}}
  end
  
  @impl true
  def update(state, new_props) do
    # Called when parent provides new props
    IO.puts("Props updated: #{inspect(new_props)}")
    {:ok, state}
  end
  
  @impl true
  def unmount(state) do
    # Called when component is removed
    IO.puts("Component unmounting")
    :ok
  end
  
  @impl true
  def cleanup(state) do
    # Called when component process terminates
    IO.puts("Cleaning up resources")
    :ok
  end
end
```

---

## Terminal Emulation

### Raxol.Terminal.Emulator

Core terminal emulator with full VT100/ANSI support and modern extensions. Achieves 3.3μs/op parsing performance.

#### Creating and Configuring Emulators

```elixir
# Basic emulator
emulator = Raxol.Terminal.Emulator.new(80, 24)

# Emulator with options
emulator = Raxol.Terminal.Emulator.new(80, 24,
  scrollback_limit: 10000,
  color_mode: :true_color,
  mouse_tracking: true,
  bracketed_paste: true
)

# Lightweight emulator for performance-critical paths
emulator = Raxol.Terminal.Emulator.new_lite(80, 24)

# Minimal emulator (fastest, no history/scrollback)
emulator = Raxol.Terminal.Emulator.new_minimal(80, 24)
```

#### Processing Input and Output

```elixir
# Process ANSI text with color codes
{emulator, output} = Raxol.Terminal.Emulator.process_input(
  emulator, 
  "\e[1;31mRed Bold\e[0m Normal \e[4;36mCyan Underline\e[0m"
)

# Process control sequences
{emulator, _} = Raxol.Terminal.Emulator.process_input(
  emulator,
  "\e[2J"     # Clear screen
)

{emulator, _} = Raxol.Terminal.Emulator.process_input(
  emulator,
  "\e[H"      # Move cursor home
)

{emulator, _} = Raxol.Terminal.Emulator.process_input(
  emulator,
  "\e[10;20H" # Move cursor to row 10, column 20
)
```

#### Cursor Operations

```elixir
# Get cursor position
{x, y} = Raxol.Terminal.Emulator.get_cursor_position(emulator)

# Set cursor position
emulator = Raxol.Terminal.Emulator.set_cursor_position(emulator, 10, 5)

# Move cursor relatively
emulator = Raxol.Terminal.Emulator.move_cursor(emulator, :up, 3)
emulator = Raxol.Terminal.Emulator.move_cursor(emulator, :right, 5)

# Cursor styling
emulator = Raxol.Terminal.Emulator.set_cursor_style(emulator, :block)
emulator = Raxol.Terminal.Emulator.set_cursor_style(emulator, :underscore)
emulator = Raxol.Terminal.Emulator.set_cursor_blink(emulator, true)

# Cursor visibility
emulator = Raxol.Terminal.Emulator.set_cursor_visibility(emulator, false)
visible? = Raxol.Terminal.Emulator.cursor_visible?(emulator)
```

#### Screen Operations

```elixir
# Clear operations
emulator = Raxol.Terminal.Emulator.clear_screen(emulator)
emulator = Raxol.Terminal.Emulator.clear_line(emulator, 5)
emulator = Raxol.Terminal.Emulator.erase_from_cursor_to_end(emulator)

# Scrolling
emulator = Raxol.Terminal.Emulator.scroll_up(emulator, 3)
emulator = Raxol.Terminal.Emulator.scroll_down(emulator, 1)

# Alternate screen buffer (for full-screen apps)
emulator = Raxol.Terminal.Emulator.switch_to_alternate_screen(emulator)
# ... do full-screen work ...
emulator = Raxol.Terminal.Emulator.switch_to_normal_screen(emulator)
```

### Raxol.Terminal.Buffer

Screen buffer management for terminal rendering with efficient cell-based storage.

#### Buffer Creation and Management

```elixir
# Create a new buffer
buffer = Raxol.Terminal.Buffer.new(80, 24)

# Create with options
buffer = Raxol.Terminal.Buffer.new(80, 24,
  default_style: %{fg: :white, bg: :black},
  tab_width: 4
)

# Resize buffer (preserves content)
buffer = Raxol.Terminal.Buffer.resize(buffer, 100, 30)

# Clear entire buffer
buffer = Raxol.Terminal.Buffer.clear(buffer)

# Clear specific region
buffer = Raxol.Terminal.Buffer.clear_region(buffer, 
  x: 10, y: 5, width: 20, height: 10
)
```

#### Writing Content

```elixir
# Write simple text
buffer = Raxol.Terminal.Buffer.write(buffer, 0, 0, "Hello World")

# Write with style
buffer = Raxol.Terminal.Buffer.write(buffer, 10, 5, "Styled Text", %{
  fg: :bright_green,
  bg: :dark_blue,
  bold: true,
  underline: true
})

# Write multi-line content
buffer = Raxol.Terminal.Buffer.write_lines(buffer, 0, 0, [
  "Line 1",
  "Line 2",
  "Line 3"
])

# Write at cursor position
buffer = Raxol.Terminal.Buffer.write_at_cursor(buffer, "Text at cursor")
```

#### Reading Content

```elixir
# Get entire buffer content
content = Raxol.Terminal.Buffer.get_content(buffer)

# Get specific line
line = Raxol.Terminal.Buffer.get_line(buffer, 5)

# Get region
region = Raxol.Terminal.Buffer.get_region(buffer,
  x: 10, y: 5, width: 20, height: 10
)

# Get cell at position
cell = Raxol.Terminal.Buffer.get_cell(buffer, 10, 5)
# => %{char: "A", style: %{fg: :white, bg: :black}}

# Get text without styles
plain_text = Raxol.Terminal.Buffer.get_plain_text(buffer)
```

#### Advanced Operations

```elixir
# Scrollback management
buffer = Raxol.Terminal.Buffer.add_to_scrollback(buffer, "Old line")
scrollback = Raxol.Terminal.Buffer.get_scrollback(buffer, limit: 100)

# Damage tracking (for efficient rendering)
buffer = Raxol.Terminal.Buffer.mark_dirty(buffer, x: 10, y: 5)
dirty_regions = Raxol.Terminal.Buffer.get_dirty_regions(buffer)
buffer = Raxol.Terminal.Buffer.clear_dirty(buffer)

# Selection handling
buffer = Raxol.Terminal.Buffer.start_selection(buffer, 5, 2)
buffer = Raxol.Terminal.Buffer.extend_selection(buffer, 20, 7)
selected_text = Raxol.Terminal.Buffer.get_selected_text(buffer)
```

### Raxol.Terminal.Parser

High-performance ANSI/VT100 sequence parser achieving 3.3μs/op (30x faster than standard implementations).

#### Basic Parsing

```elixir
# Parse mixed content (text and escape sequences)
{:ok, tokens} = Raxol.Terminal.Parser.parse("Normal \e[1;31mRed Bold\e[0m Normal")
# => [
#   {:text, "Normal "},
#   {:csi, [1, 31], "", "m"},
#   {:text, "Red Bold"},
#   {:csi, [0], "", "m"},
#   {:text, " Normal"}
# ]

# Parse with callback (streaming)
Raxol.Terminal.Parser.parse(input, fn
  {:text, text} -> IO.write(text)
  {:csi, params, _, "m"} -> apply_sgr(params)
  {:osc, 0, title} -> set_window_title(title)
  _ -> :ok
end)
```

#### Control Sequence Parsing

```elixir
# CSI (Control Sequence Introducer) sequences
{:csi, params, intermediate, final} = Raxol.Terminal.Parser.parse_csi("\e[1;2H")
# => {:csi, [1, 2], "", "H"}  # Cursor position

{:csi, params, _, "m"} = Raxol.Terminal.Parser.parse_csi("\e[38;5;196m")
# => {:csi, [38, 5, 196], "", "m"}  # 256-color foreground

# OSC (Operating System Command) sequences
{:osc, number, data} = Raxol.Terminal.Parser.parse_osc("\e]0;Window Title\a")
# => {:osc, 0, "Window Title"}  # Set window title

{:osc, 52, data} = Raxol.Terminal.Parser.parse_osc("\e]52;c;SGVsbG8=")
# => {:osc, 52, "c;SGVsbG8="}  # Clipboard operation

# DCS (Device Control String) sequences
{:dcs, params, data} = Raxol.Terminal.Parser.parse_dcs("\eP1$r0 q\e\\")
# => {:dcs, "1$r", "0 q"}  # DECSCL response
```

#### Advanced Parsing Features

```elixir
# Parse with state machine (for partial sequences)
parser = Raxol.Terminal.Parser.new()
{parser, tokens} = Raxol.Terminal.Parser.feed(parser, "\e[")
{parser, tokens} = Raxol.Terminal.Parser.feed(parser, "1;31")
{parser, tokens} = Raxol.Terminal.Parser.feed(parser, "m")
# => Complete sequence parsed

# Parse Sixel graphics
{:sixel, data} = Raxol.Terminal.Parser.parse_sixel("\ePq#0;2;0;0;0#1;2;100;100;0...\e\\")

# Parse mouse events
{:mouse, button, x, y} = Raxol.Terminal.Parser.parse_mouse("\e[M !!")
# => {:mouse, :left, 0, 0}

# Performance testing
time = Raxol.Terminal.Parser.benchmark("\e[1;31mTest\e[0m", iterations: 100_000)
IO.puts("Average parse time: #{time}μs")
# => Average parse time: 3.3μs
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

Layout engines for terminal UI composition with support for Flexbox, Grid, and responsive design.

#### Flexbox Layout

```elixir
# Horizontal flexbox (row)
layout = Raxol.UI.Layout.flexbox([
  {:box, %{flex: 1}, "Sidebar"},
  {:box, %{flex: 3}, "Main Content"},
  {:box, %{flex: 1}, "Right Panel"}
])

# Vertical flexbox (column)
layout = Raxol.UI.Layout.flexbox([
  {:box, %{height: 3}, "Header"},
  {:box, %{flex: 1}, "Body"},
  {:box, %{height: 1}, "Footer"}
], direction: :column)

# Nested flexbox with alignment
layout = Raxol.UI.Layout.flexbox([
  {:box, %{flex: 1, align: :center}, "Centered"},
  {:box, %{flex: 1, justify: :space_between}, 
    Raxol.UI.Layout.flexbox([
      {:box, %{}, "Item 1"},
      {:box, %{}, "Item 2"},
      {:box, %{}, "Item 3"}
    ])
  }
], gap: 2, padding: 1)
```

#### Grid Layout

```elixir
# Basic grid
grid = Raxol.UI.Layout.grid([
  ["A1", "B1", "C1"],
  ["A2", "B2", "C2"],
  ["A3", "B3", "C3"]
], columns: 3, rows: 3)

# Grid with custom sizing
grid = Raxol.UI.Layout.grid([
  [{:cell, %{colspan: 2}, "Wide Cell"}, "Normal"],
  ["Normal", {:cell, %{rowspan: 2}, "Tall Cell"}],
  ["Normal", nil]  # nil creates empty cell
], 
  columns: [20, 30, 20],  # Column widths
  rows: [5, 10, 10],      # Row heights
  gap: 1
)

# Responsive grid
grid = Raxol.UI.Layout.responsive_grid([
  "Item 1", "Item 2", "Item 3", "Item 4", "Item 5"
],
  min_column_width: 20,
  max_columns: 4
)
```

#### Absolute Positioning

```elixir
# Overlay layout with absolute positioning
layout = Raxol.UI.Layout.absolute([
  {:element, %{x: 0, y: 0, width: :full, height: :full}, "Background"},
  {:element, %{x: 10, y: 5, width: 40, height: 10}, "Dialog"},
  {:element, %{x: :center, y: :center, width: 20, height: 5}, "Centered"}
])
```

#### Responsive Layouts

```elixir
# Breakpoint-based responsive layout
layout = Raxol.UI.Layout.responsive(
  breakpoints: [
    {0, :mobile},
    {80, :tablet},
    {120, :desktop}
  ],
  layouts: %{
    mobile: Raxol.UI.Layout.flexbox([...], direction: :column),
    tablet: Raxol.UI.Layout.grid([...], columns: 2),
    desktop: Raxol.UI.Layout.grid([...], columns: 3)
  }
)

# Render layout to terminal
Raxol.UI.Layout.render(layout, terminal)
```

### Raxol.UI.Components

Pre-built UI components library with 20+ production-ready components.

#### Input Components

```elixir
# Text Input
text_input = Raxol.UI.Components.TextInput.new(
  placeholder: "Enter your name...",
  value: "",
  width: 30,
  on_change: fn value -> IO.puts("Input: #{value}") end,
  on_submit: fn value -> IO.puts("Submitted: #{value}") end
)

# Password Input
password = Raxol.UI.Components.PasswordInput.new(
  placeholder: "Password",
  min_length: 8,
  show_strength: true,
  on_change: fn value -> validate_password(value) end
)

# Select List
select = Raxol.UI.Components.Select.new(
  options: ["Option 1", "Option 2", "Option 3"],
  selected: 0,
  multiple: false,
  on_change: fn selected -> IO.puts("Selected: #{selected}") end
)

# Checkbox
checkbox = Raxol.UI.Components.Checkbox.new(
  label: "I agree to the terms",
  checked: false,
  on_toggle: fn checked -> IO.puts("Checked: #{checked}") end
)
```

#### Display Components

```elixir
# Progress Bar with different styles
progress = Raxol.UI.Components.ProgressBar.new(
  value: 75,
  max: 100,
  width: 50,
  style: :gradient,  # :simple, :gradient, :segments
  color: {:gradient, [:red, :yellow, :green]},
  show_percentage: true,
  label: "Processing..."
)

# Table with sorting and filtering
table = Raxol.UI.Components.Table.new(
  headers: ["Name", "Age", "City", "Status"],
  rows: [
    ["Alice", "30", "NYC", {:badge, "Active", :green}],
    ["Bob", "25", "LA", {:badge, "Pending", :yellow}],
    ["Charlie", "35", "Chicago", {:badge, "Inactive", :red}]
  ],
  sortable: true,
  filterable: true,
  selectable: true,
  on_select: fn row -> IO.inspect(row) end
)

# Tree View
tree = Raxol.UI.Components.TreeView.new(
  data: %{
    "Root" => %{
      "Folder 1" => ["File 1.txt", "File 2.txt"],
      "Folder 2" => %{
        "Subfolder" => ["File 3.txt"]
      }
    }
  },
  expanded: ["Root", "Root/Folder 1"],
  on_select: fn path -> IO.puts("Selected: #{path}") end
)

# Chart/Sparkline
chart = Raxol.UI.Components.Sparkline.new(
  data: [1, 4, 2, 8, 5, 9, 3, 7, 6],
  width: 40,
  height: 10,
  style: :line,  # :line, :bar, :area
  color: :cyan
)
```

#### Container Components

```elixir
# Modal Dialog
modal = Raxol.UI.Components.Modal.new(
  title: "Confirm Action",
  content: "This action cannot be undone. Are you sure?",
  buttons: [
    {:button, "Cancel", :cancel, style: :secondary},
    {:button, "Delete", :delete, style: :danger}
  ],
  width: 60,
  on_close: fn result -> handle_modal_result(result) end
)

# Tab Container
tabs = Raxol.UI.Components.Tabs.new(
  tabs: [
    {:tab, "General", general_content()},
    {:tab, "Settings", settings_content()},
    {:tab, "Advanced", advanced_content()}
  ],
  active: 0,
  style: :underline,  # :underline, :box, :rounded
  on_change: fn index -> IO.puts("Tab #{index} selected") end
)

# Accordion
accordion = Raxol.UI.Components.Accordion.new(
  sections: [
    {:section, "Section 1", "Content 1", expanded: true},
    {:section, "Section 2", "Content 2", expanded: false},
    {:section, "Section 3", "Content 3", expanded: false}
  ],
  multiple: false,  # Only one section open at a time
  on_toggle: fn index -> IO.puts("Toggled section #{index}") end
)

# Split Pane
split = Raxol.UI.Components.SplitPane.new(
  orientation: :horizontal,  # :horizontal, :vertical
  first: left_panel(),
  second: right_panel(),
  position: 40,  # Percentage or fixed pixels
  resizable: true,
  min_size: 20
)
```

#### Navigation Components

```elixir
# Menu Bar
menu_bar = Raxol.UI.Components.MenuBar.new(
  items: [
    {:menu, "File", [
      {:item, "New", :new, shortcut: "Ctrl+N"},
      {:item, "Open", :open, shortcut: "Ctrl+O"},
      :separator,
      {:item, "Exit", :exit, shortcut: "Ctrl+Q"}
    ]},
    {:menu, "Edit", [...]},
    {:menu, "Help", [...]}
  ],
  on_select: fn item -> handle_menu(item) end
)

# Breadcrumb
breadcrumb = Raxol.UI.Components.Breadcrumb.new(
  path: ["Home", "Documents", "Projects", "Raxol"],
  separator: " > ",
  on_click: fn index -> navigate_to(index) end
)

# Pagination
pagination = Raxol.UI.Components.Pagination.new(
  current_page: 3,
  total_pages: 10,
  items_per_page: 20,
  total_items: 193,
  on_change: fn page -> load_page(page) end
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

Svelte-style context API for prop drilling avoidance.

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