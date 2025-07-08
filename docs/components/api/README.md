# Component API Reference

Complete API documentation for Raxol components, including base behaviors, component types, and usage patterns.

## Quick Reference

- [Base Component Behavior](#base-component-behavior) - Core component lifecycle
- [Component Types](#component-types) - Available component categories
- [Event System](#event-system) - Event handling patterns
- [Rendering](#rendering) - View composition and styling
- [State Management](#state-management) - Component state patterns

## Base Component Behavior

All components implement the `Raxol.UI.Components.Base.Component` behaviour:

```elixir
defmodule Raxol.UI.Components.Base.Component do
  @callback init(props :: map()) :: state :: map()
  @callback mount(state :: map()) :: {state :: map(), commands :: [term()]}
  @callback update(msg :: term(), state :: map()) :: {state :: map(), commands :: [term()]}
  @callback render(state :: map()) :: element :: map()
  @callback handle_event(event :: map(), state :: map()) :: {state :: map(), commands :: [term()]}
  @callback unmount(state :: map()) :: state :: map()
end
```

### Lifecycle Hooks

| Hook             | Purpose                              | Required | Returns             |
| ---------------- | ------------------------------------ | -------- | ------------------- |
| `init/1`         | Initialize state from props          | Yes      | `state`             |
| `mount/1`        | Setup resources after mounting       | No       | `{state, commands}` |
| `update/2`       | Update state in response to messages | Yes      | `{state, commands}` |
| `render/1`       | Produce component view               | Yes      | `element`           |
| `handle_event/2` | Handle user/system events            | Yes      | `{state, commands}` |
| `unmount/1`      | Clean up resources                   | No       | `state`             |

## Component Types

### Input Components

#### TextInput

```elixir
defmodule Raxol.UI.Components.Input.TextInput do
  @type props :: %{
    value: String.t(),
    placeholder: String.t(),
    label: String.t(),
    error: String.t() | nil,
    disabled: boolean(),
    required: boolean(),
    max_length: non_neg_integer(),
    on_change: (String.t() -> term()),
    on_submit: (String.t() -> term())
  }

  @type state :: %{
    value: String.t(),
    focused: boolean(),
    error: String.t() | nil,
    cursor_position: non_neg_integer()
  }
end
```

**Events**: `:change`, `:focus`, `:blur`, `:submit`

#### SelectList

```elixir
defmodule Raxol.UI.Components.Input.SelectList do
  @type props :: %{
    items: [term()],
    selected: term() | nil,
    label: String.t(),
    placeholder: String.t(),
    searchable: boolean(),
    multi_select: boolean(),
    on_select: (term() -> term())
  }

  @type state :: %{
    items: [term()],
    selected: term() | nil,
    search_term: String.t(),
    scroll_offset: non_neg_integer(),
    focused_index: non_neg_integer()
  }
end
```

**Events**: `:select`, `:search`, `:scroll`, `:focus`

### Display Components

#### Table

```elixir
defmodule Raxol.UI.Components.Display.Table do
  @type column :: %{
    key: atom(),
    label: String.t(),
    sortable: boolean(),
    filterable: boolean(),
    width: non_neg_integer()
  }

  @type props :: %{
    columns: [column()],
    data: [map()],
    sort_by: atom() | nil,
    sort_direction: :asc | :desc,
    page_size: non_neg_integer(),
    current_page: non_neg_integer(),
    on_sort: (atom() -> term()),
    on_filter: (map() -> term()),
    on_page_change: (non_neg_integer() -> term())
  }

  @type state :: %{
    columns: [column()],
    data: [map()],
    sort_by: atom() | nil,
    sort_direction: :asc | :desc,
    filters: map(),
    page_size: non_neg_integer(),
    current_page: non_neg_integer(),
    total_pages: non_neg_integer()
  }
end
```

**Events**: `:sort`, `:filter`, `:page_change`, `:row_select`

#### ProgressBar

```elixir
defmodule Raxol.UI.Components.Display.ProgressBar do
  @type props :: %{
    value: number(),
    max: number(),
    label: String.t(),
    show_percentage: boolean(),
    animated: boolean()
  }

  @type state :: %{
    value: number(),
    max: number(),
    percentage: number(),
    animation_frame: non_neg_integer()
  }
end
```

**Events**: `:complete`, `:update`

### Layout Components

#### Box

```elixir
defmodule Raxol.UI.Components.Layout.Box do
  @type props :: %{
    border: :none | :single | :double | :rounded,
    padding: non_neg_integer(),
    margin: non_neg_integer(),
    width: non_neg_integer() | :auto,
    height: non_neg_integer() | :auto,
    content: [element()] | element()
  }

  @type state :: %{
    border: :none | :single | :double | :rounded,
    padding: non_neg_integer(),
    margin: non_neg_integer(),
    width: non_neg_integer() | :auto,
    height: non_neg_integer() | :auto,
    content: [element()]
  }
end
```

#### Row/Column

```elixir
defmodule Raxol.UI.Components.Layout.Row do
  @type props :: %{
    gap: non_neg_integer(),
    justify: :start | :center | :end | :space_between,
    align: :start | :center | :end,
    content: [element()]
  }
end

defmodule Raxol.UI.Components.Layout.Column do
  @type props :: %{
    gap: non_neg_integer(),
    justify: :start | :center | :end | :space_between,
    align: :start | :center | :end,
    content: [element()]
  }
end
```

## Event System

### Event Types

```elixir
# Mouse events
%{type: :click, x: integer(), y: integer()}
%{type: :double_click, x: integer(), y: integer()}
%{type: :mouse_move, x: integer(), y: integer()}

# Keyboard events
%{type: :key_press, key: atom(), modifiers: [atom()]}
%{type: :key_release, key: atom(), modifiers: [atom()]}

# Focus events
%{type: :focus}
%{type: :blur}

# Form events
%{type: :change, value: term()}
%{type: :submit, value: term()}

# Custom events
%{type: :custom, data: term()}
```

### Event Handling

```elixir
def handle_event(%{type: :click, x: x, y: y}, state) do
  # Handle click at coordinates
  {state, [{:command, {:clicked, x, y}}]}
end

def handle_event(%{type: :key_press, key: :enter}, state) do
  # Handle enter key
  {state, [{:command, :submitted}]}
end

def handle_event(%{type: :change, value: value}, state) do
  # Handle value change
  {Map.put(state, :value, value), [{:command, :value_changed}]}
end
```

## Rendering

### Element Structure

```elixir
@type element :: %{
  type: atom(),
  content: String.t() | [element()],
  attributes: map(),
  style: map(),
  events: [map()]
}
```

### Common Element Types

```elixir
# Text element
%{
  type: :text,
  content: "Hello, World!",
  attributes: %{color: :cyan, bold: true}
}

# Container element
%{
  type: :box,
  content: [child_element1, child_element2],
  attributes: %{border: :single, padding: 1}
}

# Interactive element
%{
  type: :button,
  content: "Click me",
  attributes: %{on_click: :button_clicked}
}
```

### Styling

```elixir
# Color attributes
%{color: :red | :green | :blue | :cyan | :magenta | :yellow | :white | :black}

# Text attributes
%{bold: true, italic: true, underline: true}

# Layout attributes
%{width: 10, height: 5, padding: 1, margin: 1}

# Border attributes
%{border: :none | :single | :double | :rounded}
```

## State Management

### State Patterns

```elixir
# Simple state
def init(props) do
  %{
    value: props[:value] || "",
    focused: false,
    error: nil
  }
end

# Complex state with validation
def init(props) do
  state = %{
    value: props[:value] || "",
    focused: false,
    error: nil,
    valid: true,
    dirty: false
  }

  case validate_props(props) do
    {:ok, _} -> state
    {:error, error} -> Map.put(state, :error, error)
  end
end
```

### State Updates

```elixir
# Immutable updates
def update({:set_value, value}, state) do
  {Map.put(state, :value, value), []}
end

# Complex updates
def update({:validate_and_set, value}, state) do
  case validate_value(value) do
    {:ok, _} ->
      new_state = %{state |
        value: value,
        error: nil,
        valid: true,
        dirty: true
      }
      {new_state, [{:command, :value_changed}]}

    {:error, error} ->
      new_state = %{state |
        value: value,
        error: error,
        valid: false,
        dirty: true
      }
      {new_state, [{:command, :validation_failed}]}
  end
end
```

## Command System

### Command Types

```elixir
# Navigation commands
{:navigate, :next}
{:navigate, :previous}

# Action commands
{:action, :submit}
{:action, :cancel}

# Communication commands
{:notify, {:value_changed, value}}
{:notify, {:error, error}}

# Custom commands
{:custom, {:my_action, data}}
```

### Command Handling

```elixir
def update({:set_value, value}, state) do
  new_state = Map.put(state, :value, value)
  commands = [
    {:command, :value_changed},
    {:command, {:notify_parent, value}}
  ]
  {new_state, commands}
end
```

## Performance Guidelines

### Optimization Techniques

1. **Memoization**: Cache expensive computations
2. **Lazy Loading**: Load components on demand
3. **Event Batching**: Batch multiple events together
4. **Render Optimization**: Only re-render when necessary

### Performance Targets

- Component initialization: < 0.1ms
- Event handling: < 1ms
- Rendering: < 2ms
- Memory usage: < 1MB per component

## Best Practices

### Component Design

- Keep components small and focused
- Use clear, descriptive names
- Handle errors gracefully
- Follow consistent patterns

### State Management

- Minimize component state
- Use immutable updates
- Avoid deep nesting
- Clear data flow

### Event Handling

- Use consistent event types
- Validate event data
- Handle all expected events
- Provide meaningful feedback

## Additional Resources

- [Component Guide](../README.md) - Component development patterns
- [Style Guide](../style_guide.md) - Styling and design patterns
- [Testing Guide](../testing.md) - Component testing patterns
