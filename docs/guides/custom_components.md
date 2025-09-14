# Custom Component Creation Guide

This guide walks you through creating reusable, high-performance components for Raxol applications.

## Table of Contents
1. [Component Fundamentals](#component-fundamentals)
2. [Component Types](#component-types)
3. [State Management](#state-management)
4. [Event Handling](#event-handling)
5. [Advanced Patterns](#advanced-patterns)
6. [Testing Components](#testing-components)

## Component Fundamentals

### Basic Component Structure

Every Raxol component follows a consistent pattern:

```elixir
defmodule MyApp.Components.MyComponent do
  @moduledoc """
  A reusable component that demonstrates best practices.
  
  ## Example
      MyComponent
        title: "Hello World",
        items: [1, 2, 3],
        on_click: &handle_click/1
  """
  
  use Raxol.UI.Component
  
  # Define component props with types and defaults
  prop :title, :string, required: true
  prop :items, :list, default: []
  prop :on_click, :function, default: nil
  prop :disabled, :boolean, default: false
  
  # Internal state (optional)
  defstruct [:selected_index, :hover_index]
  
  @impl true
  def init(props) do
    # Initialize component state
    %__MODULE__{
      selected_index: 0,
      hover_index: nil
    }
  end
  
  @impl true
  def render(state, props) do
    div class: "my-component", 
        style: [disabled: props.disabled] do
      
      h2 do
        props.title
      end
      
      ul do
        props.items
        |> Enum.with_index()
        |> Enum.map(fn {item, index} ->
          render_item(item, index, state, props)
        end)
      end
    end
  end
  
  @impl true
  def handle_event(state, props, {:click, index}) do
    # Update internal state
    new_state = %{state | selected_index: index}
    
    # Notify parent if callback provided
    if props.on_click do
      props.on_click.(index)
    end
    
    new_state
  end
  
  defp render_item(item, index, state, props) do
    selected = index == state.selected_index
    
    li style: [bg: if(selected, do: :blue, else: :default)],
       on_click: {:click, index} do
      "#{item}"
    end
  end
end
```

### Component Props

Props are the interface to your component. Define them clearly:

```elixir
defmodule MyApp.Components.DataTable do
  use Raxol.UI.Component
  
  # Required props
  prop :data, :list, required: true,
    doc: "List of maps representing table rows"
    
  prop :columns, :list, required: true,
    doc: "Column definitions with :key, :label, :width"
  
  # Optional props with defaults
  prop :sortable, :boolean, default: true,
    doc: "Whether columns can be sorted"
    
  prop :paginated, :boolean, default: false,
    doc: "Enable pagination"
    
  prop :page_size, :integer, default: 50,
    doc: "Items per page when paginated"
  
  # Event callbacks
  prop :on_row_click, :function, default: nil,
    doc: "Called when a row is clicked: (row_data) -> any()"
    
  prop :on_sort, :function, default: nil,
    doc: "Called when column is sorted: (column, direction) -> any()"
  
  # Style customization
  prop :theme, :atom, default: :default,
    options: [:default, :dark, :minimal],
    doc: "Visual theme"
    
  prop :striped, :boolean, default: true,
    doc: "Alternating row colors"
end
```

### Component Lifecycle

Components have a clear lifecycle:

```elixir
defmodule MyApp.Components.AnimatedCounter do
  use Raxol.UI.Component
  
  prop :target_value, :integer, required: true
  prop :duration_ms, :integer, default: 1000
  
  defstruct [:current_value, :start_time, :timer_ref]
  
  @impl true
  def init(props) do
    # Component initialization
    state = %__MODULE__{
      current_value: 0,
      start_time: System.monotonic_time(:millisecond)
    }
    
    # Start animation
    start_animation(state, props)
  end
  
  @impl true
  def update(state, props, changes) do
    # Called when props change
    if :target_value in changes do
      # Restart animation with new target
      cancel_animation(state)
      start_animation(%{state | start_time: System.monotonic_time(:millisecond)}, props)
    else
      state
    end
  end
  
  @impl true
  def handle_info(state, props, :animate) do
    # Handle animation tick
    now = System.monotonic_time(:millisecond)
    elapsed = now - state.start_time
    
    if elapsed >= props.duration_ms do
      # Animation complete
      %{state | current_value: props.target_value, timer_ref: nil}
    else
      # Update current value based on easing function
      progress = elapsed / props.duration_ms
      new_value = ease_out_cubic(progress) * props.target_value
      
      # Schedule next frame
      timer_ref = Process.send_after(self(), :animate, 16)  # 60fps
      
      %{state | current_value: round(new_value), timer_ref: timer_ref}
    end
  end
  
  @impl true
  def cleanup(state, _props) do
    # Component cleanup
    cancel_animation(state)
    :ok
  end
  
  defp start_animation(state, props) do
    timer_ref = Process.send_after(self(), :animate, 16)
    %{state | timer_ref: timer_ref}
  end
  
  defp cancel_animation(%{timer_ref: nil}), do: :ok
  defp cancel_animation(%{timer_ref: ref}), do: Process.cancel_timer(ref)
  
  defp ease_out_cubic(t), do: 1 - :math.pow(1 - t, 3)
end
```

## Component Types

### 1. Stateless Components

Simple, pure components that only depend on props:

```elixir
defmodule MyApp.Components.Badge do
  use Raxol.UI.Component
  
  prop :text, :string, required: true
  prop :type, :atom, default: :info,
    options: [:info, :success, :warning, :error]
  
  def render(_state, props) do
    span class: "badge badge-#{props.type}" do
      props.text
    end
  end
end
```

### 2. Stateful Components

Components that maintain internal state:

```elixir
defmodule MyApp.Components.Accordion do
  use Raxol.UI.Component
  
  prop :sections, :list, required: true
  prop :allow_multiple, :boolean, default: false
  
  defstruct [:expanded_sections]
  
  def init(props) do
    %__MODULE__{expanded_sections: MapSet.new()}
  end
  
  def render(state, props) do
    div class: "accordion" do
      props.sections
      |> Enum.with_index()
      |> Enum.map(fn {section, index} ->
        expanded = MapSet.member?(state.expanded_sections, index)
        
        div class: "section" do
          div class: "header", 
              on_click: {:toggle, index} do
            section.title
            span class: "icon" do
              if expanded, do: "−", else: "+"
            end
          end
          
          if expanded do
            div class: "content" do
              section.content
            end
          end
        end
      end)
    end
  end
  
  def handle_event(state, props, {:toggle, index}) do
    if props.allow_multiple do
      # Toggle this section
      new_sections = if MapSet.member?(state.expanded_sections, index) do
        MapSet.delete(state.expanded_sections, index)
      else
        MapSet.put(state.expanded_sections, index)
      end
      
      %{state | expanded_sections: new_sections}
    else
      # Only one section can be open
      new_sections = if MapSet.member?(state.expanded_sections, index) do
        MapSet.new()
      else
        MapSet.new([index])
      end
      
      %{state | expanded_sections: new_sections}
    end
  end
end
```

### 3. Container Components

Components that manage data and delegate rendering:

```elixir
defmodule MyApp.Components.DataProvider do
  use Raxol.UI.Component
  
  prop :url, :string, required: true
  prop :children, :function, required: true
  prop :loading_component, :function, default: &default_loading/1
  prop :error_component, :function, default: &default_error/1
  
  defstruct [:data, :loading, :error]
  
  def init(props) do
    state = %__MODULE__{loading: true}
    
    # Start async data fetch
    Task.async(fn ->
      case HTTPoison.get(props.url) do
        {:ok, response} -> {:data, Jason.decode!(response.body)}
        {:error, error} -> {:error, error}
      end
    end)
    
    state
  end
  
  def handle_info(state, _props, {_ref, {:data, data}}) do
    %{state | data: data, loading: false}
  end
  
  def handle_info(state, _props, {_ref, {:error, error}}) do
    %{state | error: error, loading: false}
  end
  
  def render(state, props) do
    cond do
      state.loading ->
        props.loading_component.(state)
        
      state.error ->
        props.error_component.(state.error)
        
      true ->
        props.children.(state.data)
    end
  end
  
  defp default_loading(_state) do
    div class: "loading" do
      "Loading..."
    end
  end
  
  defp default_error(error) do
    div class: "error" do
      "Error: #{inspect(error)}"
    end
  end
end

# Usage
DataProvider url: "/api/users" do
  fn users ->
    UserList users: users
  end
end
```

### 4. Higher-Order Components

Components that enhance other components:

```elixir
defmodule MyApp.Components.WithErrorBoundary do
  use Raxol.UI.Component
  
  prop :fallback, :function, required: true
  prop :children, :function, required: true
  
  defstruct [:error, :error_info]
  
  def init(_props) do
    %__MODULE__{error: nil, error_info: nil}
  end
  
  def render(state, props) do
    if state.error do
      props.fallback.(state.error, state.error_info)
    else
      try do
        props.children.()
      rescue
        error ->
          error_info = __STACKTRACE__
          new_state = %{state | error: error, error_info: error_info}
          
          # Log error
          Logger.error("Component error: #{inspect(error)}", error_info)
          
          # Render fallback
          props.fallback.(error, error_info)
      end
    end
  end
  
  def handle_event(state, props, :reset_error) do
    %{state | error: nil, error_info: nil}
  end
end

# Usage
WithErrorBoundary fallback: &error_fallback/2 do
  fn ->
    MyRiskyComponent data: data
  end
end
```

## State Management

### Local Component State

For simple, isolated state:

```elixir
defmodule MyApp.Components.Counter do
  use Raxol.UI.Component
  
  prop :initial_value, :integer, default: 0
  
  defstruct [:count]
  
  def init(props) do
    %__MODULE__{count: props.initial_value}
  end
  
  def render(state, _props) do
    div do
      "Count: #{state.count}"
      button on_click: :increment do
        "+"
      end
      button on_click: :decrement do
        "-"
      end
    end
  end
  
  def handle_event(state, _props, :increment) do
    %{state | count: state.count + 1}
  end
  
  def handle_event(state, _props, :decrement) do
    %{state | count: state.count - 1}
  end
end
```

### Shared State with Context

For state shared across components:

```elixir
defmodule MyApp.Context.Theme do
  use Raxol.UI.Context
  
  defstruct [:colors, :fonts, :spacing]
  
  def create_context(theme_name \\ :default) do
    case theme_name do
      :default ->
        %__MODULE__{
          colors: %{primary: :blue, secondary: :gray},
          fonts: %{body: "monospace", heading: "sans-serif"},
          spacing: %{small: 1, medium: 2, large: 4}
        }
        
      :dark ->
        %__MODULE__{
          colors: %{primary: :cyan, secondary: :white},
          fonts: %{body: "monospace", heading: "sans-serif"},
          spacing: %{small: 1, medium: 2, large: 4}
        }
    end
  end
end

defmodule MyApp.Components.ThemedButton do
  use Raxol.UI.Component
  use MyApp.Context.Theme
  
  prop :text, :string, required: true
  prop :variant, :atom, default: :primary
  
  def render(_state, props) do
    theme = use_context(Theme)
    
    button style: [
      fg: theme.colors[props.variant],
      font: theme.fonts.body,
      padding: theme.spacing.medium
    ] do
      props.text
    end
  end
end

# Usage with context provider
ThemeProvider theme: :dark do
  ThemedButton text: "Click me", variant: :primary
end
```

### External State Management

For complex state, use external stores:

```elixir
defmodule MyApp.Store.AppState do
  use GenServer
  
  def start_link(initial_state) do
    GenServer.start_link(__MODULE__, initial_state, name: __MODULE__)
  end
  
  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end
  
  def dispatch(action) do
    GenServer.cast(__MODULE__, {:dispatch, action})
  end
  
  def subscribe(pid) do
    GenServer.cast(__MODULE__, {:subscribe, pid})
  end
  
  # Reducer-like pattern
  def reduce(state, {:increment, amount}) do
    %{state | count: state.count + amount}
  end
  
  def reduce(state, {:set_user, user}) do
    %{state | current_user: user}
  end
  
  # GenServer callbacks
  def handle_cast({:dispatch, action}, {state, subscribers}) do
    new_state = reduce(state, action)
    
    # Notify all subscribers
    Enum.each(subscribers, fn pid ->
      send(pid, {:state_changed, new_state})
    end)
    
    {:noreply, {new_state, subscribers}}
  end
end

defmodule MyApp.Components.ConnectedComponent do
  use Raxol.UI.Component
  
  defstruct [:app_state]
  
  def init(_props) do
    # Subscribe to store updates
    MyApp.Store.AppState.subscribe(self())
    
    %__MODULE__{
      app_state: MyApp.Store.AppState.get_state()
    }
  end
  
  def handle_info(state, _props, {:state_changed, new_app_state}) do
    %{state | app_state: new_app_state}
  end
  
  def render(state, _props) do
    div do
      "Count: #{state.app_state.count}"
      
      if state.app_state.current_user do
        "User: #{state.app_state.current_user.name}"
      end
    end
  end
end
```

## Event Handling

### Basic Event Handling

```elixir
defmodule MyApp.Components.InteractiveList do
  use Raxol.UI.Component
  
  prop :items, :list, required: true
  prop :on_item_click, :function, default: nil
  
  def render(_state, props) do
    ul do
      props.items
      |> Enum.with_index()
      |> Enum.map(fn {item, index} ->
        li on_click: {:item_click, index},
           on_hover: {:item_hover, index} do
          item.name
        end
      end)
    end
  end
  
  def handle_event(state, props, {:item_click, index}) do
    item = Enum.at(props.items, index)
    
    if props.on_item_click do
      props.on_item_click.(item, index)
    end
    
    state
  end
  
  def handle_event(state, _props, {:item_hover, index}) do
    # Handle hover state
    state
  end
end
```

### Custom Event System

For complex event handling:

```elixir
defmodule MyApp.Events do
  @moduledoc "Custom event system for components"
  
  defstruct [:handlers, :middleware]
  
  def new do
    %__MODULE__{
      handlers: %{},
      middleware: []
    }
  end
  
  def on(events, event_type, handler) do
    handlers = Map.update(events.handlers, event_type, [handler], &[handler | &1])
    %{events | handlers: handlers}
  end
  
  def emit(events, event_type, data \\ nil) do
    # Apply middleware
    processed_data = Enum.reduce(events.middleware, data, fn middleware, acc ->
      middleware.(event_type, acc)
    end)
    
    # Call handlers
    case Map.get(events.handlers, event_type) do
      nil -> :ok
      handlers -> 
        Enum.each(handlers, fn handler ->
          handler.(processed_data)
        end)
    end
  end
  
  def middleware(events, middleware_fn) do
    %{events | middleware: [middleware_fn | events.middleware]}
  end
end

defmodule MyApp.Components.EventDrivenComponent do
  use Raxol.UI.Component
  
  defstruct [:events]
  
  def init(_props) do
    events = MyApp.Events.new()
             |> MyApp.Events.on(:click, &handle_click/1)
             |> MyApp.Events.on(:double_click, &handle_double_click/1)
             |> MyApp.Events.middleware(&log_events/2)
    
    %__MODULE__{events: events}
  end
  
  def render(state, props) do
    div on_click: :click,
        on_double_click: :double_click do
      "Click me!"
    end
  end
  
  def handle_event(state, _props, event_type) do
    MyApp.Events.emit(state.events, event_type)
    state
  end
  
  defp handle_click(_data) do
    IO.puts("Single click!")
  end
  
  defp handle_double_click(_data) do
    IO.puts("Double click!")
  end
  
  defp log_events(event_type, data) do
    Logger.debug("Event: #{event_type}, Data: #{inspect(data)}")
    data
  end
end
```

## Advanced Patterns

### 1. Render Props Pattern

Pass rendering logic as props:

```elixir
defmodule MyApp.Components.Virtualized do
  use Raxol.UI.Component
  
  prop :items, :list, required: true
  prop :item_height, :integer, required: true
  prop :height, :integer, required: true
  prop :render_item, :function, required: true
  
  defstruct [:scroll_top, :visible_start, :visible_end]
  
  def render(state, props) do
    # Calculate visible range
    visible_start = div(state.scroll_top, props.item_height)
    visible_count = div(props.height, props.item_height) + 2
    visible_end = min(visible_start + visible_count, length(props.items))
    
    div class: "virtualized",
        style: [height: props.height],
        on_scroll: :scroll do
      
      # Spacer for items above viewport
      if visible_start > 0 do
        div style: [height: visible_start * props.item_height]
      end
      
      # Visible items
      props.items
      |> Enum.slice(visible_start..visible_end)
      |> Enum.with_index(visible_start)
      |> Enum.map(fn {item, index} ->
        props.render_item.(item, index)
      end)
      
      # Spacer for items below viewport
      remaining = length(props.items) - visible_end
      if remaining > 0 do
        div style: [height: remaining * props.item_height]
      end
    end
  end
end

# Usage
Virtualized 
  items: large_list,
  item_height: 30,
  height: 300,
  render_item: fn item, index ->
    div style: [height: 30] do
      "Item #{index}: #{item.name}"
    end
  end
```

### 2. Compound Components

Components that work together:

```elixir
defmodule MyApp.Components.Tabs do
  use Raxol.UI.Component
  
  prop :active_tab, :string, default: nil
  prop :on_tab_change, :function, default: nil
  prop :children, :list, required: true
  
  def render(_state, props) do
    # Find TabList and TabPanels children
    {tab_list, tab_panels} = separate_children(props.children)
    
    div class: "tabs" do
      render_child(tab_list, %{
        active_tab: props.active_tab,
        on_tab_change: props.on_tab_change
      })
      
      render_child(tab_panels, %{
        active_tab: props.active_tab
      })
    end
  end
  
  defp separate_children(children) do
    Enum.reduce(children, {nil, nil}, fn
      %TabList{} = tab_list, {_old, panels} ->
        {tab_list, panels}
      %TabPanels{} = tab_panels, {list, _old} ->
        {list, tab_panels}
      _, acc -> acc
    end)
  end
end

defmodule MyApp.Components.TabList do
  use Raxol.UI.Component
  
  prop :children, :list, required: true
  
  def render(_state, props, context) do
    div class: "tab-list" do
      Enum.map(props.children, fn tab ->
        render_child(tab, context)
      end)
    end
  end
end

defmodule MyApp.Components.Tab do
  use Raxol.UI.Component
  
  prop :id, :string, required: true
  prop :children, :any, required: true
  
  def render(_state, props, context) do
    active = props.id == context.active_tab
    
    button class: "tab",
           style: [active: active],
           on_click: {:select_tab, props.id} do
      props.children
    end
  end
  
  def handle_event(_state, props, {:select_tab, tab_id}, context) do
    if context.on_tab_change do
      context.on_tab_change.(tab_id)
    end
  end
end

# Usage
Tabs active_tab: "tab1", on_tab_change: &set_active_tab/1 do
  [
    TabList do
      [
        Tab(id: "tab1") { "First Tab" },
        Tab(id: "tab2") { "Second Tab" }
      ]
    end,
    
    TabPanels do
      [
        TabPanel(id: "tab1") { "First Panel Content" },
        TabPanel(id: "tab2") { "Second Panel Content" }
      ]
    end
  ]
end
```

### 3. Composition Pattern

Build complex components from simple ones:

```elixir
defmodule MyApp.Components.Card do
  use Raxol.UI.Component
  
  prop :children, :any, required: true
  prop :elevated, :boolean, default: false
  
  def render(_state, props) do
    div class: "card",
        style: [elevated: props.elevated] do
      props.children
    end
  end
end

defmodule MyApp.Components.CardHeader do
  use Raxol.UI.Component
  
  prop :title, :string, required: true
  prop :subtitle, :string, default: nil
  prop :actions, :any, default: nil
  
  def render(_state, props) do
    div class: "card-header" do
      div class: "titles" do
        h3 do
          props.title
        end
        
        if props.subtitle do
          p class: "subtitle" do
            props.subtitle
          end
        end
      end
      
      if props.actions do
        div class: "actions" do
          props.actions
        end
      end
    end
  end
end

defmodule MyApp.Components.CardContent do
  use Raxol.UI.Component
  
  prop :children, :any, required: true
  
  def render(_state, props) do
    div class: "card-content" do
      props.children
    end
  end
end

# Usage
Card elevated: true do
  [
    CardHeader(
      title: "User Profile",
      subtitle: "Manage your account",
      actions: [
        Button(text: "Edit", on_click: &edit_profile/0),
        Button(text: "Delete", variant: :danger, on_click: &delete_profile/0)
      ]
    ),
    
    CardContent do
      UserProfile user: current_user
    end
  ]
end
```

## Testing Components

### Unit Testing

```elixir
defmodule MyApp.Components.CounterTest do
  use ExUnit.Case
  use Raxol.UI.ComponentTest
  
  alias MyApp.Components.Counter
  
  describe "Counter component" do
    test "renders initial value" do
      result = render(Counter, initial_value: 5)
      
      assert result =~ "Count: 5"
      assert has_button?(result, "+")
      assert has_button?(result, "-")
    end
    
    test "increments on + button click" do
      {component, _html} = render_component(Counter, initial_value: 0)
      
      # Simulate button click
      new_component = handle_event(component, :increment)
      html = render(new_component)
      
      assert html =~ "Count: 1"
    end
    
    test "decrements on - button click" do
      {component, _html} = render_component(Counter, initial_value: 5)
      
      new_component = handle_event(component, :decrement)
      html = render(new_component)
      
      assert html =~ "Count: 4"
    end
  end
end
```

### Integration Testing

```elixir
defmodule MyApp.Components.DataTableTest do
  use ExUnit.Case
  use Raxol.UI.IntegrationTest
  
  alias MyApp.Components.DataTable
  
  describe "DataTable integration" do
    test "renders table with data" do
      data = [
        %{name: "Alice", age: 30},
        %{name: "Bob", age: 25}
      ]
      
      columns = [
        %{key: :name, label: "Name"},
        %{key: :age, label: "Age"}
      ]
      
      {:ok, view, html} = live_isolated(DataTable, 
        data: data, 
        columns: columns
      )
      
      assert html =~ "Alice"
      assert html =~ "Bob"
      assert html =~ "30"
      assert html =~ "25"
    end
    
    test "handles row click events" do
      data = [%{name: "Alice", age: 30}]
      columns = [%{key: :name, label: "Name"}]
      
      parent = self()
      on_click = fn row -> send(parent, {:row_clicked, row}) end
      
      {:ok, view, html} = live_isolated(DataTable,
        data: data,
        columns: columns,
        on_row_click: on_click
      )
      
      # Click on first row
      html |> element("tr:first-child") |> render_click()
      
      assert_received {:row_clicked, %{name: "Alice", age: 30}}
    end
    
    test "sorts columns when clicked" do
      data = [
        %{name: "Bob", age: 25},
        %{name: "Alice", age: 30}
      ]
      
      columns = [%{key: :name, label: "Name", sortable: true}]
      
      {:ok, view, html} = live_isolated(DataTable,
        data: data,
        columns: columns
      )
      
      # Click column header to sort
      html |> element("th[data-column='name']") |> render_click()
      
      # Check that Alice now comes first
      updated_html = render(view)
      rows = updated_html |> Floki.find("tr") |> tl()  # Skip header
      first_row = hd(rows) |> Floki.text()
      
      assert first_row =~ "Alice"
    end
  end
end
```

### Visual Testing

```elixir
defmodule MyApp.Components.VisualTest do
  use ExUnit.Case
  use Raxol.UI.VisualTest
  
  describe "Component visual regression" do
    test "Button component renders correctly" do
      variants = [
        {Button, [text: "Default"]},
        {Button, [text: "Primary", variant: :primary]},
        {Button, [text: "Disabled", disabled: true]},
        {Button, [text: "Large", size: :large]}
      ]
      
      Enum.each(variants, fn {component, props} ->
        name = "button_#{props[:variant] || :default}_#{props[:size] || :medium}"
        take_screenshot(component, props, name)
        assert_visual_match(name)
      end)
    end
    
    test "Card layout in different screen sizes" do
      card_props = [
        title: "Test Card",
        content: "This is some test content for the card component."
      ]
      
      screen_sizes = [
        {:mobile, 320, 568},
        {:tablet, 768, 1024},
        {:desktop, 1920, 1080}
      ]
      
      Enum.each(screen_sizes, fn {size_name, width, height} ->
        set_viewport_size(width, height)
        take_screenshot(Card, card_props, "card_#{size_name}")
        assert_visual_match("card_#{size_name}")
      end)
    end
  end
end
```

### Performance Testing

```elixir
defmodule MyApp.Components.PerformanceTest do
  use ExUnit.Case
  use Raxol.UI.PerformanceTest
  
  alias MyApp.Components.VirtualList
  
  describe "VirtualList performance" do
    test "renders large lists efficiently" do
      # Generate large dataset
      items = for i <- 1..10_000, do: %{id: i, name: "Item #{i}"}
      
      # Measure render time
      {render_time, _result} = :timer.tc(fn ->
        render(VirtualList, items: items, item_height: 30, height: 300)
      end)
      
      # Should render in less than 10ms regardless of item count
      assert render_time < 10_000
    end
    
    test "memory usage stays constant with large datasets" do
      base_items = for i <- 1..100, do: %{id: i, name: "Item #{i}"}
      large_items = for i <- 1..10_000, do: %{id: i, name: "Item #{i}"}
      
      # Measure memory usage
      base_memory = measure_memory(fn ->
        render(VirtualList, items: base_items, item_height: 30, height: 300)
      end)
      
      large_memory = measure_memory(fn ->
        render(VirtualList, items: large_items, item_height: 30, height: 300)
      end)
      
      # Memory usage should not increase significantly
      ratio = large_memory / base_memory
      assert ratio < 2.0, "Memory usage grew by #{ratio}x"
    end
  end
end
```

## Best Practices

1. **Single Responsibility**: Each component should have one clear purpose
2. **Composition over Inheritance**: Build complex components by composing simpler ones
3. **Props as API**: Design props like a public API - stable and well-documented
4. **Avoid Deep Nesting**: Keep component hierarchies shallow
5. **Performance by Default**: Optimize for common use cases
6. **Test Everything**: Unit test behavior, integration test interactions
7. **Document Usage**: Provide clear examples and API documentation
8. **Handle Errors Gracefully**: Use error boundaries and fallbacks
9. **Accessibility First**: Support keyboard navigation and screen readers
10. **Consistent Naming**: Use clear, consistent naming conventions

## Component Library Structure

```
lib/my_app/components/
├── atoms/           # Basic building blocks
│   ├── button.ex
│   ├── input.ex
│   └── badge.ex
├── molecules/       # Simple combinations
│   ├── form_field.ex
│   ├── search_box.ex
│   └── pagination.ex
├── organisms/       # Complex UI sections
│   ├── data_table.ex
│   ├── navigation.ex
│   └── sidebar.ex
└── templates/       # Full page layouts
    ├── dashboard.ex
    ├── form.ex
    └── list.ex
```

This structure follows atomic design principles and makes it easy to find and maintain components.

## Next Steps

- Read the [Performance Optimization Guide](performance_optimization.md)
- Explore [Advanced Patterns](../architecture/patterns.md)  
- Check out [Example Components](../../examples/components/)
- Join the [Community](https://github.com/raxol/raxol/discussions)