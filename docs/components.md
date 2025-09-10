# Components

Build terminal UI with React-style components that also work on the web.

## Quick Start

```elixir
defmodule MyButton do
  use Raxol.Component
  
  def init(props) do
    %{label: props[:label], pressed: false}
  end
  
  def render(state, _props) do
    style = if state.pressed, do: [:bold, :reverse], else: [:bold]
    text(state.label, style: style)
  end
  
  def handle_event(:click, state) do
    {:update, %{state | pressed: !state.pressed}}
  end
end

# Use it
{:ok, button} = Raxol.Component.create(MyButton, label: "Click me")
```

## Component Lifecycle

1. **init** - Initialize state from props
2. **mount** - Component added to tree
3. **render** - Generate UI elements
4. **handle_event** - Process interactions
5. **update** - State changes trigger re-render
6. **unmount** - Cleanup on removal

## Built-in Components

### Input Components

```elixir
# Text input
use Raxol.Components.TextInput
TextInput.new(
  placeholder: "Enter name...",
  on_change: &handle_input/1
)

# Select list
use Raxol.Components.SelectList
SelectList.new(
  options: ["Red", "Green", "Blue"],
  on_select: &handle_select/1
)

# Checkbox
use Raxol.Components.Checkbox
Checkbox.new(
  label: "Enable feature",
  checked: true
)
```

### Layout Components

```elixir
# Flexbox layout
use Raxol.UI.Layout.Flex
Flex.row([
  Flex.item(child1, flex: 1),
  Flex.item(child2, flex: 2)
])

# Grid layout
use Raxol.UI.Layout.Grid
Grid.new(
  columns: 3,
  gap: 1,
  children: items
)

# Scrollable container
use Raxol.Components.ScrollView
ScrollView.new(
  height: 20,
  children: long_content
)
```

### Display Components

```elixir
# Table
use Raxol.Components.Table
Table.new(
  headers: ["Name", "Age", "City"],
  rows: data,
  sortable: true
)

# Progress bar
use Raxol.Components.ProgressBar
ProgressBar.new(
  value: 0.75,
  label: "Loading..."
)

# Modal dialog
use Raxol.Components.Modal
Modal.new(
  title: "Confirm",
  content: "Are you sure?",
  buttons: [:ok, :cancel]
)
```

## State Management

### Local State

```elixir
defmodule Counter do
  use Raxol.Component
  
  def init(_), do: %{count: 0}
  
  def handle_event(:increment, state) do
    {:update, %{state | count: state.count + 1}}
  end
end
```

### Shared State (Context)

```elixir
# Define context
defmodule ThemeContext do
  use Raxol.Context
  def initial_value, do: :dark
end

# Provide context
ThemeContext.provide(:light, children)

# Consume context
def render(state, _props, context) do
  theme = ThemeContext.get(context)
  # Use theme...
end
```

## Styling

### Inline Styles

```elixir
text("Hello", style: [:bold, :blue, :underline])

box(
  children,
  border: :rounded,
  padding: 1,
  bg: :gray
)
```

### Theme System

```elixir
# Define theme
theme = %{
  colors: %{
    primary: {0, 123, 255},
    text: {255, 255, 255}
  },
  spacing: %{
    small: 1,
    medium: 2
  }
}

# Apply theme
Raxol.UI.with_theme(theme, fn ->
  # Components use theme
end)
```

## Event Handling

### Keyboard Events

```elixir
def handle_event({:key, :enter}, state) do
  {:update, submit(state)}
end

def handle_event({:key, :escape}, _state) do
  :close
end

def handle_event({:key, "j", [:ctrl]}, state) do
  {:update, move_down(state)}
end
```

### Mouse Events

```elixir
def handle_event({:mouse, :click, row, col}, state) do
  {:update, handle_click(state, row, col)}
end

def handle_event({:mouse, :scroll, :up}, state) do
  {:update, scroll_up(state)}
end
```

## Hooks

### Use Hooks

```elixir
defmodule Timer do
  use Raxol.Component
  use Raxol.Hooks
  
  def mount(state) do
    # Start timer
    use_interval(1000, fn ->
      send(self(), :tick)
    end)
    state
  end
  
  def handle_event(:tick, state) do
    {:update, %{state | time: state.time + 1}}
  end
end
```

### Custom Hooks

```elixir
defmodule UseApi do
  def fetch(url) do
    use_effect(fn ->
      Task.async(fn -> HTTPoison.get!(url) end)
    end, [url])
  end
end
```

## Web Rendering

Components automatically work in Phoenix LiveView:

```elixir
defmodule MyAppWeb.PageLive do
  use Phoenix.LiveView
  use Raxol.LiveView
  
  def render(assigns) do
    ~H"""
    <.raxol_component module={MyButton} label="Click" />
    """
  end
end
```

## Testing

```elixir
# Component testing
defmodule ButtonTest do
  use Raxol.ComponentCase
  
  test "renders label" do
    {:ok, button} = render_component(MyButton, label: "Test")
    assert button |> find_text() == "Test"
  end
  
  test "handles click" do
    {:ok, button} = render_component(MyButton, label: "Click")
    button |> simulate_event(:click)
    assert button |> has_style?(:reverse)
  end
end
```

## Performance

- Virtual DOM diffing for minimal updates
- Lazy rendering for off-screen components
- Memoization with `React.memo` equivalent
- Batch state updates

## See Also

- [API Reference](api-reference.md#components) - Complete component API
- [Terminal](terminal.md) - Terminal rendering details
- [Examples](examples/) - Component examples