---
title: Component API Reference
description: Comprehensive API documentation for Raxol components
date: 2025-05-10
author: Raxol Team
section: components
tags: [api, components, documentation]
---

## Base Component Behaviour

All components in Raxol implement the `Raxol.UI.Components.Base.Component` behaviour. Components are reusable, stateful modules that support a clear lifecycle:

- `init/1` — Initialize state from props
- `mount/1` — Set up resources after mounting
- `update/2` — Update state in response to messages
- `render/1` — Produce the component's view
- `handle_event/2` — Handle user/system events
- `unmount/1` — Clean up resources

```elixir
defmodule Raxol.UI.Components.Base.Component do
  @callback init(props :: map()) :: state :: map()
  @callback mount(state :: map()) :: {state :: map(), command :: term()}
  @callback update(msg :: term(), state :: map()) :: {state :: map(), command :: term()}
  @callback render(state :: map()) :: element :: term()
  @callback handle_event(event :: term(), state :: map()) :: {state :: map(), command :: term()}
  @callback unmount(state :: map()) :: state :: map()
end
```

### Lifecycle Hooks

1. **init/1**

   - Called when component is created
   - Validates and processes props
   - Returns initial state
   - Required callback

2. **mount/1**

   - Called when component is mounted
   - Sets up resources
   - Returns initial state and command
   - Optional callback

3. **update/2**

   - Called when component receives a message
   - Updates state based on message
   - Returns new state and command
   - Required callback

4. **render/1**

   - Called to render component
   - Converts state to view elements
   - Returns element structure
   - Required callback

5. **handle_event/2**

   - Called when component receives an event
   - Processes event and updates state
   - Returns new state and command
   - Required callback

6. **unmount/1**
   - Called when component is unmounted
   - Cleans up resources
   - Returns final state
   - Optional callback

## Component Types

### Input Components

#### TextInput

```elixir
defmodule Raxol.UI.Components.Input.TextInput do
  @moduledoc """
  A text input component with validation and formatting support.
  """

  @type props :: %{
    value: String.t(),
    placeholder: String.t(),
    label: String.t(),
    error: String.t(),
    disabled: boolean(),
    required: boolean(),
    max_length: non_neg_integer(),
    on_change: (String.t() -> term()),
    on_submit: (String.t() -> term())
  }

  @type state :: %{
    value: String.t(),
    focused: boolean(),
    error: String.t(),
    cursor_position: non_neg_integer()
  }
end
```

#### SelectList

```elixir
defmodule Raxol.UI.Components.Input.SelectList do
  @moduledoc """
  A selectable list component with search and filtering support.
  """

  @type props :: %{
    items: [term()],
    selected: term(),
    label: String.t(),
    placeholder: String.t(),
    searchable: boolean(),
    multi_select: boolean(),
    on_select: (term() -> term())
  }

  @type state :: %{
    items: [term()],
    selected: term(),
    search_term: String.t(),
    scroll_offset: non_neg_integer(),
    focused_index: non_neg_integer()
  }
end
```

### Display Components

#### Table

```elixir
defmodule Raxol.UI.Components.Display.Table do
  @moduledoc """
  A table component with sorting, filtering, and pagination.
  """

  @type props :: %{
    columns: [column()],
    data: [map()],
    sort_by: atom(),
    sort_direction: :asc | :desc,
    page_size: non_neg_integer(),
    current_page: non_neg_integer(),
    on_sort: (atom() -> term()),
    on_filter: (map() -> term()),
    on_page_change: (non_neg_integer() -> term())
  }

  @type column :: %{
    key: atom(),
    label: String.t(),
    sortable: boolean(),
    filterable: boolean(),
    width: non_neg_integer()
  }

  @type state :: %{
    columns: [column()],
    data: [map()],
    sort_by: atom(),
    sort_direction: :asc | :desc,
    filters: map(),
    page_size: non_neg_integer(),
    current_page: non_neg_integer(),
    total_pages: non_neg_integer()
  }
end
```

#### ProgressBar

```elixir
defmodule Raxol.UI.Components.Display.ProgressBar do
  @moduledoc """
  A progress bar component with animation and label support.
  """

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

### Visualization Components

#### Chart

```elixir
defmodule Raxol.UI.Components.Visualization.Chart do
  @moduledoc """
  A chart component supporting multiple visualization types.
  """

  @type chart_type :: :line | :bar | :area | :pie | :scatter

  @type props :: %{
    type: chart_type(),
    data: [series()],
    title: String.t(),
    x_axis: axis_config(),
    y_axis: axis_config(),
    legend: legend_config(),
    colors: [String.t()]
  }

  @type series :: %{
    name: String.t(),
    data: [point()],
    color: String.t()
  }

  @type point :: %{
    x: term(),
    y: number(),
    label: String.t()
  }

  @type axis_config :: %{
    label: String.t(),
    min: number(),
    max: number(),
    format: (term() -> String.t())
  }

  @type legend_config :: %{
    position: :top | :right | :bottom | :left,
    show: boolean()
  }

  @type state :: %{
    type: chart_type(),
    data: [series()],
    dimensions: dimensions(),
    hovered_point: point() | nil
  }

  @type dimensions :: %{
    width: non_neg_integer(),
    height: non_neg_integer(),
    margin: margin()
  }

  @type margin :: %{
    top: non_neg_integer(),
    right: non_neg_integer(),
    bottom: non_neg_integer(),
    left: non_neg_integer()
  }
end
```

#### TreeMap

```elixir
defmodule Raxol.UI.Components.Visualization.TreeMap do
  @moduledoc """
  A treemap visualization component for hierarchical data.
  """

  @type props :: %{
    data: node(),
    title: String.t(),
    colors: [String.t()],
    show_labels: boolean(),
    min_label_size: non_neg_integer()
  }

  @type node :: %{
    id: String.t(),
    name: String.t(),
    value: number(),
    color: String.t(),
    children: [node()]
  }

  @type state :: %{
    data: node(),
    dimensions: dimensions(),
    hovered_node: node() | nil,
    selected_node: node() | nil
  }

  @type dimensions :: %{
    width: non_neg_integer(),
    height: non_neg_integer(),
    padding: non_neg_integer()
  }
end
```

## Component Composition

Components can be composed using the `View.Elements` DSL:

```elixir
defmodule MyComponent do
  use Raxol.UI.Components.Base.Component

  def render(state) do
    panel do
      row do
        column do
          text_input(%{
            value: state.value,
            on_change: &handle_change/1
          })
        end
        column do
          button("Submit", %{
            on_click: &handle_submit/0
          })
        end
      end
    end
  end
end
```

## Event Handling

Components handle events through the `handle_event/2` callback:

```elixir
def handle_event({:click, _}, state) do
  {update_in(state, [:click_count], &(&1 + 1)), []}
end

def handle_event({:key, key}, state) do
  case key do
    :enter -> {state, [{:submit, state.value}]}
    :escape -> {state, [{:cancel, nil}]}
    _ -> {state, []}
  end
end
```

## State Management

Components maintain their own state and can update it through messages:

```elixir
def update({:set_value, value}, state) do
  {put_in(state, [:value], value), []}
end

def update({:set_error, error}, state) do
  {put_in(state, [:error], error), []}
end
```

## Theme Integration

Components can access theme values through the `Core.ColorSystem`:

```elixir
def render(state) do
  colors = Raxol.Core.ColorSystem.get_colors()

  panel do
    text("Hello", %{
      color: colors.text,
      background: colors.background
    })
  end
end
```

## Accessibility

Components should implement accessibility features:

```elixir
def render(state) do
  panel do
    text_input(%{
      value: state.value,
      aria_label: "Search input",
      aria_describedby: "search-description"
    })
    text("Enter search terms", %{
      id: "search-description",
      aria_hidden: true
    })
  end
end
```

## Performance Considerations

1. **State Updates**

   - Use immutable updates
   - Minimize state changes
   - Batch related updates

2. **Rendering**

   - Cache expensive computations
   - Use efficient data structures
   - Implement should_update? callback

3. **Event Handling**
   - Debounce frequent events
   - Throttle expensive operations
   - Clean up event listeners

## Testing

Components should be tested using the `ComponentTestHelpers`:

```elixir
defmodule MyComponentTest do
  use ExUnit.Case
  import Raxol.ComponentTestHelpers

  test "handles click events" do
    component = create_test_component(MyComponent, %{})
    {new_state, _} = simulate_event_sequence(component, [{:click, nil}])
    assert new_state.click_count == 1
  end
end
```
