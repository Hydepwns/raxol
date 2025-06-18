# Raxol Component Testing Guide

> See also: [Component Architecture](./component_architecture.md) for component lifecycle and patterns.

## Table of Contents

1. [Overview](#overview)
2. [Test Structure](#test-structure)
3. [Testing Patterns](#testing-patterns)
4. [Integration Testing](#integration-testing)
5. [Performance Testing](#performance-testing)
6. [Test Helpers](#test-helpers)
7. [Best Practices](#best-practices)
8. [Common Pitfalls](#common-pitfalls)

## Overview

This document outlines testing patterns and best practices for Raxol components, including unit testing, integration testing, and performance testing. The testing framework provides utilities for testing component lifecycle, state management, event handling, and rendering.

## Test Structure

### Basic Test Module

```elixir
defmodule Raxol.UI.Components.Input.TextInputTest do
  use ExUnit.Case, async: true
  import Raxol.ComponentTestHelpers

  # Test component that implements all lifecycle hooks
  defmodule TestComponent do
    @behaviour Raxol.UI.Components.Base.Component

    def init(props) do
      Map.merge(%{
        counter: 0,
        mounted: false,
        unmounted: false,
        events: [],
        value: props[:value] || "",
        error: nil
      }, props)
    end

    def mount(state) do
      new_state = %{state | mounted: true}
      {new_state, [{:command, :mounted}]}
    end

    def update({:set_value, value}, state) do
      {put_in(state, [:value], value), []}
    end

    def render(state) do
      %{
        type: :text_input,
        value: state.value,
        error: state.error,
        counter: state.counter
      }
    end

    def handle_event(%{type: :change, value: value}, state) do
      new_state = %{state |
        value: value,
        events: [{:change, value} | state.events]
      }
      {new_state, [{:command, :value_changed}]}
    end

    def unmount(state) do
      %{state | unmounted: true}
    end
  end

  describe "Component Lifecycle" do
    test "complete lifecycle flow" do
      component = create_test_component(TestComponent, %{value: "initial"})

      {final_component, events} = simulate_lifecycle(component, fn mounted ->
        # Verify mounted state
        assert mounted.state.mounted
        assert_receive {:commands, [{:command, :mounted}]}

        # Update state
        updated = simulate_event_sequence(mounted, [
          %{type: :change, value: "updated"},
          %{type: :change, value: "final"}
        ])

        # Verify updates
        assert updated.state.value == "final"
        assert length(updated.state.events) == 2

        updated
      end)

      # Verify final state
      assert final_component.state.unmounted
      assert length(events) > 0
    end
  end
end
```

## Testing Patterns

### Lifecycle Testing

```elixir
describe "Component Lifecycle" do
  test "initializes with props" do
    component = create_test_component(TestComponent, %{
      value: "test",
      counter: 5
    })
    assert component.state.value == "test"
    assert component.state.counter == 5
  end

  test "mounts correctly" do
    component = create_test_component(TestComponent)
    {mounted, _} = simulate_lifecycle(component, &(&1))
    assert mounted.state.mounted
    assert_receive {:commands, [{:command, :mounted}]}
  end

  test "unmounts correctly" do
    component = create_test_component(TestComponent)
    {unmounted, _} = simulate_lifecycle(component, &(&1))
    assert unmounted.state.unmounted
  end

  test "handles mount errors gracefully" do
    component = create_test_component(ErrorProneComponent)
    {mounted, _} = simulate_lifecycle(component, &(&1))
    assert mounted.state.error != nil
  end
end
```

### State Management Testing

```elixir
describe "State Management" do
  test "updates state through events" do
    component = create_test_component(TestComponent, %{value: "initial"})

    updated = simulate_event_sequence(component, [
      %{type: :change, value: "updated"},
      %{type: :change, value: "final"}
    ])

    assert updated.state.value == "final"
    assert length(updated.state.events) == 2
  end

  test "handles state updates through commands" do
    component = create_test_component(TestComponent)

    {updated, commands} = Unit.simulate_event(component, %{
      type: :change,
      value: "new value"
    })

    assert updated.state.value == "new value"
    assert commands == [{:command, :value_changed}]
  end

  test "preserves unrelated state during updates" do
    component = create_test_component(TestComponent, %{
      value: "initial",
      counter: 5
    })

    {updated, _} = Unit.simulate_event(component, %{
      type: :change,
      value: "updated"
    })

    assert updated.state.value == "updated"
    assert updated.state.counter == 5
  end
end
```

### Event Handling Testing

```elixir
describe "Event Handling" do
  test "handles known events" do
    component = create_test_component(TestComponent)

    {updated, commands} = Unit.simulate_event(component, %{
      type: :change,
      value: "test"
    })

    assert updated.state.value == "test"
    assert commands == [{:command, :value_changed}]
  end

  test "ignores unknown events" do
    component = create_test_component(TestComponent)

    {updated, commands} = Unit.simulate_event(component, %{
      type: :unknown_event
    })

    assert updated.state == component.state
    assert commands == []
  end

  test "handles event errors gracefully" do
    component = create_test_component(ErrorProneComponent)

    {updated, _} = Unit.simulate_event(component, %{
      type: :error_event
    })

    assert updated.state.error != nil
  end
end
```

### Rendering Testing

```elixir
describe "Rendering" do
  test "renders with different contexts" do
    component = create_test_component(TestComponent, %{value: "test"})

    contexts = [
      %{theme: %{mode: :light}},
      %{theme: %{mode: :dark}},
      %{theme: %{mode: :high_contrast}}
    ]

    rendered = validate_rendering(component, contexts)

    assert length(rendered) == 3
    assert Enum.all?(rendered, &(&1.type == :text_input))
    assert Enum.all?(rendered, &(&1.value == "test"))
  end

  test "renders with error state" do
    component = create_test_component(TestComponent, %{
      value: "test",
      error: "Invalid input"
    })

    rendered = validate_rendering(component, [%{theme: %{mode: :light}}])

    assert rendered.type == :text_input
    assert rendered.value == "test"
    assert rendered.error == "Invalid input"
  end
end
```

## Integration Testing

### Component Hierarchy Testing

```elixir
describe "Component Hierarchy" do
  test "parent-child relationship" do
    # Set up components
    parent = create_test_component(ParentComponent)
    child = create_test_component(ChildComponent, %{
      parent_id: parent.state.id,
      value: "child value"
    })

    # Set up hierarchy
    {parent, child} = setup_component_hierarchy(ParentComponent, ChildComponent)

    # Verify hierarchy
    assert_hierarchy_valid(parent, [child])
    assert child.state.parent_id == parent.state.id
  end

  test "event propagation" do
    # Set up components
    parent = create_test_component(ParentComponent)
    child = create_test_component(ChildComponent, %{
      parent_id: parent.state.id,
      value: "initial"
    })

    # Simulate child event
    {updated_child, child_commands} = Unit.simulate_event(child, %{
      type: :change,
      value: "updated"
    })

    # Verify parent received event
    assert_receive {:component_updated, ^parent.state.id}
    updated_parent = ComponentManager.get_component(parent.state.id)
    assert updated_parent.state.child_states[child.state.id].value == "updated"
  end
end
```

### Component Communication Testing

```elixir
describe "Component Communication" do
  test "broadcast events" do
    # Set up multiple components
    parent = create_test_component(ParentComponent)
    child1 = create_test_component(ChildComponent, %{
      parent_id: parent.state.id,
      value: "child1"
    })
    child2 = create_test_component(ChildComponent, %{
      parent_id: parent.state.id,
      value: "child2"
    })

    # Set up hierarchy
    {parent, [child1, child2]} = setup_component_hierarchy(
      ParentComponent,
      [ChildComponent, ChildComponent]
    )

    # Simulate broadcast event
    {updated_parent, _} = Unit.simulate_event(parent, %{
      type: :broadcast,
      value: "broadcast value"
    })

    # Verify all children received the event
    updated_child1 = ComponentManager.get_component(child1.state.id)
    updated_child2 = ComponentManager.get_component(child2.state.id)
    assert updated_child1.state.value == "broadcast value"
    assert updated_child2.state.value == "broadcast value"
  end
end
```

## Performance Testing

### Load Testing

```elixir
describe "Performance" do
  test "handles rapid event sequences" do
    component = create_test_component(TestComponent)

    # Create a workload of 100 events
    workload = fn comp ->
      events = Enum.map(1..100, &%{
        type: :change,
        value: "test#{&1}"
      })
      simulate_event_sequence(comp, events)
    end

    metrics = measure_performance(component, workload)

    assert metrics.iterations == 100
    assert metrics.average_time < 100 # Less than 100ms per iteration
  end

  test "handles large data sets" do
    component = create_test_component(HeavyComponent)

    # Measure performance with large data set
    metrics = measure_performance(component, fn comp ->
      {updated, _} = Unit.simulate_event(comp, %{
        type: :add_data,
        data: generate_large_dataset(1000)
      })
      assert length(updated.state.data) == 1000
    end)

    assert metrics.average_time < 1000 # Less than 1 second per iteration
  end
end
```

## Test Helpers

### Component Creation

```elixir
defmodule ComponentTestHelpers do
  def create_test_component(module, initial_state \\ %{}, opts \\ []) do
    props = Map.merge(%{
      id: "test-#{:erlang.unique_integer([:positive])}",
      debug_mode: true
    }, initial_state)

    {:ok, component} = Unit.setup_isolated_component(module, props)
    component
  end
end
```

### Lifecycle Simulation

```elixir
def simulate_lifecycle(component, lifecycle_fn) do
  # Mount
  mounted = mount_component(component)

  # Execute lifecycle function
  result = lifecycle_fn.(mounted)

  # Unmount
  unmounted = unmount_component(result)

  # Return final state and lifecycle events
  {unmounted, get_lifecycle_events(unmounted)}
end
```

### Event Simulation

```elixir
def simulate_event_sequence(component, events) do
  Enum.reduce(events, component, fn event, acc ->
    {updated, _commands} = Unit.simulate_event(acc, event)
    updated
  end)
end
```

## Best Practices

1. **Test Organization**

   - Group related tests in describe blocks
   - Use clear, descriptive test names
   - Follow a consistent test structure
   - Document test purpose

2. **Test Coverage**

   - Test all lifecycle methods
   - Test state management
   - Test event handling
   - Test edge cases
   - Test performance

3. **Test Isolation**

   - Use unique component IDs
   - Clean up after tests
   - Avoid test interdependence
   - Use test helpers

4. **Test Readability**

   - Use descriptive test names
   - Document test setup
   - Use helper functions
   - Follow consistent patterns

5. **Test Maintenance**
   - Keep tests focused
   - Update tests with code changes
   - Remove obsolete tests
   - Document test dependencies

## Common Pitfalls

1. **State Management**

   - Forgetting to test state immutability
   - Not testing state updates in isolation
   - Missing edge cases in state transitions

2. **Event Handling**

   - Not testing error cases
   - Missing event validation
   - Incomplete event coverage

3. **Lifecycle**

   - Not testing cleanup
   - Missing mount/unmount edge cases
   - Incomplete resource management

4. **Performance**
   - Not testing with realistic data
   - Missing memory leak tests
   - Incomplete load testing

## Related Documentation

- [Component Architecture](./component_architecture.md)
- [Component Style Guide](./style_guide.md)
- [Component Composition Patterns](./composition.md)
