# Raxol Component Composition Patterns

## Overview

This document outlines common patterns for composing components in Raxol, including parent-child relationships, component communication, and state management across component hierarchies.

## Basic Composition

### Parent-Child Relationship

```elixir
defmodule ParentComponent do
  @behaviour Raxol.UI.Components.Base.Component

  def init(props) do
    %{
      children: [],
      child_states: %{}
    }
  end

  def render(state, context) do
    {state, %{
      type: :parent,
      children: state.children
    }}
  end

  def handle_event(%{type: :child_event} = event, state) do
    # Handle child events
    {new_state, commands}
  end
end

defmodule ChildComponent do
  @behaviour Raxol.UI.Components.Base.Component

  def init(props) do
    %{
      parent_id: props[:parent_id],
      value: props[:value]
    }
  end

  def handle_event(%{type: :click}, state) do
    # Notify parent of event
    {state, [{:command, {:notify_parent, state}}]}
  end
end
```

### Component Communication

1. **Event Propagation**

   ```elixir
   # Parent component
   def handle_event(%{type: :child_event, child_id: child_id} = event, state) do
     # Handle child event
     {new_state, commands}
   end

   # Child component
   def handle_event(%{type: :click}, state) do
     # Propagate event to parent
     {state, [{:command, {:notify_parent, state}}]}
   end
   ```

2. **State Synchronization**

   ```elixir
   # Parent component
   def update({:child_updated, child_id, new_state}, state) do
     # Update child state
     new_state = put_in(state.child_states[child_id], new_state)
     {new_state, []}
   end

   # Child component
   def update(:parent_update, state) do
     # Update based on parent state
     {new_state, []}
   end
   ```

## Advanced Patterns

### Container Components

```elixir
defmodule ContainerComponent do
  @behaviour Raxol.UI.Components.Base.Component

  def init(props) do
    %{
      items: props[:items] || [],
      render_item: props[:render_item],
      on_item_select: props[:on_item_select]
    }
  end

  def render(state, context) do
    items = Enum.map(state.items, fn item ->
      state.render_item.(item, context)
    end)

    {state, %{
      type: :container,
      items: items
    }}
  end
end
```

### Higher-Order Components

```elixir
defmodule WithErrorBoundary do
  def wrap(component, error_handler) do
    %{
      type: :error_boundary,
      component: component,
      error_handler: error_handler
    }
  end

  def handle_event(event, state) do
    try do
      component.handle_event(event, state)
    rescue
      error ->
        state.error_handler.(error)
        {state, []}
    end
  end
end
```

### Compound Components

```elixir
defmodule Tabs do
  @behaviour Raxol.UI.Components.Base.Component

  def init(props) do
    %{
      tabs: props[:tabs] || [],
      active_tab: props[:active_tab] || 0
    }
  end

  def render(state, context) do
    {state, %{
      type: :tabs,
      header: render_header(state),
      content: render_content(state)
    }}
  end

  defp render_header(state) do
    %{
      type: :tab_header,
      tabs: state.tabs,
      active_tab: state.active_tab
    }
  end

  defp render_content(state) do
    %{
      type: :tab_content,
      content: Enum.at(state.tabs, state.active_tab)
    }
  end
end
```

## State Management Patterns

### Lifted State

```elixir
defmodule ParentComponent do
  def init(props) do
    %{
      shared_state: props[:initial_state] || %{},
      children: []
    }
  end

  def update({:update_shared_state, new_state}, state) do
    # Update shared state
    new_state = Map.merge(state.shared_state, new_state)
    # Notify children
    {state, [{:command, {:notify_children, new_state}}]}
  end
end
```

### Context Provider

```elixir
defmodule ThemeProvider do
  def init(props) do
    %{
      theme: props[:theme] || %{},
      children: props[:children] || []
    }
  end

  def render(state, context) do
    # Merge theme with context
    new_context = Map.merge(context, %{theme: state.theme})

    # Render children with new context
    children = Enum.map(state.children, fn child ->
      child.render(child.state, new_context)
    end)

    {state, %{
      type: :theme_provider,
      children: children
    }}
  end
end
```

## Event Handling Patterns

### Event Delegation

```elixir
defmodule EventDelegator do
  def init(props) do
    %{
      handlers: props[:handlers] || %{},
      children: props[:children] || []
    }
  end

  def handle_event(event, state) do
    case Map.get(state.handlers, event.type) do
      nil -> {state, []}
      handler -> handler.(event, state)
    end
  end
end
```

### Event Bubbling

```elixir
defmodule EventBubbler do
  def handle_event(event, state) do
    # Handle event locally
    {new_state, local_commands} = handle_local_event(event, state)

    # Bubble event up
    {new_state, local_commands ++ [{:command, {:bubble_event, event}}]}
  end
end
```

## Performance Patterns

### Memoization

```elixir
defmodule MemoizedComponent do
  def init(props) do
    %{
      cache: %{},
      compute_fn: props[:compute_fn]
    }
  end

  def render(state, context) do
    # Check cache first
    case Map.get(state.cache, context.key) do
      nil ->
        # Compute and cache
        value = state.compute_fn.(context)
        new_state = put_in(state.cache[context.key], value)
        {new_state, %{type: :memoized, value: value}}

      cached_value ->
        {state, %{type: :memoized, value: cached_value}}
    end
  end
end
```

### Virtual Lists

```elixir
defmodule VirtualList do
  def init(props) do
    %{
      items: props[:items] || [],
      item_height: props[:item_height],
      visible_height: props[:visible_height],
      scroll_top: 0
    }
  end

  def render(state, context) do
    # Calculate visible items
    visible_items = calculate_visible_items(state)

    {state, %{
      type: :virtual_list,
      items: visible_items,
      total_height: length(state.items) * state.item_height
    }}
  end
end
```

## Testing Composition

### Component Hierarchy Testing

```elixir
defmodule ComponentHierarchyTest do
  use ExUnit.Case

  test "parent-child relationship" do
    # Set up components
    parent = create_test_component(ParentComponent)
    child = create_test_component(ChildComponent, %{parent_id: parent.state.id})

    # Set up hierarchy
    {parent, child} = setup_component_hierarchy(ParentComponent, ChildComponent)

    # Verify hierarchy
    assert_hierarchy_valid(parent, [child])
  end
end
```

### Event Propagation Testing

```elixir
test "event propagation" do
  # Set up components
  parent = create_test_component(ParentComponent)
  child = create_test_component(ChildComponent, %{parent_id: parent.state.id})

  # Simulate child event
  {updated_child, child_commands} = Unit.simulate_event(child, %{type: :click})

  # Verify parent received event
  assert_receive {:component_updated, ^parent.state.id}
  updated_parent = ComponentManager.get_component(parent.state.id)
  assert updated_parent.state.events == [{child.state.id, 1}]
end
```

## Best Practices

1. **Component Design**

   - Keep components focused and single-purpose
   - Use composition over inheritance
   - Document component interfaces
   - Handle edge cases gracefully

2. **State Management**

   - Lift state to appropriate level
   - Use immutable updates
   - Minimize shared state
   - Document state structure

3. **Event Handling**

   - Use consistent event structure
   - Handle all expected events
   - Provide fallback handlers
   - Document event types

4. **Performance**

   - Use memoization when appropriate
   - Implement virtual lists for large datasets
   - Batch related updates
   - Profile component performance

5. **Testing**
   - Test component hierarchy
   - Verify event propagation
   - Test edge cases
   - Use test helpers
