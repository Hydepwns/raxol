# Raxol Component Testing Guide

## Overview

This document outlines testing patterns and best practices for Raxol components, including unit testing, integration testing, and performance testing.

## Test Structure

### Basic Test Module

```elixir
defmodule MyComponentTest do
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
        events: []
      }, props)
    end

    def mount(state) do
      new_state = %{state | mounted: true}
      {new_state, [{:command, :mounted}]}
    end

    def update(:increment, state) do
      %{state | counter: state.counter + 1}
    end

    def render(state, _context) do
      {state, %{
        type: :test_component,
        counter: state.counter
      }}
    end

    def handle_event(%{type: :test_event}, state) do
      new_state = %{state | events: [:test_event | state.events]}
      {new_state, [{:command, :event_handled}]}
    end

    def unmount(state) do
      %{state | unmounted: true}
    end
  end

  describe "Component Lifecycle" do
    test "complete lifecycle flow" do
      component = create_test_component(TestComponent)

      {final_component, events} = simulate_lifecycle(component, fn mounted ->
        # Verify mounted state
        assert mounted.state.mounted
        assert_receive {:commands, [{:command, :mounted}]}

        # Update state
        updated = simulate_event_sequence(mounted, [
          %{type: :test_event},
          %{type: :test_event}
        ])

        # Verify updates
        assert updated.state.counter == 0
        assert updated.state.events == [:test_event, :test_event]

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
    component = create_test_component(TestComponent, %{counter: 5})
    assert component.state.counter == 5
  end

  test "mounts correctly" do
    component = create_test_component(TestComponent)
    {mounted, _} = simulate_lifecycle(component, &(&1))
    assert mounted.state.mounted
  end

  test "unmounts correctly" do
    component = create_test_component(TestComponent)
    {unmounted, _} = simulate_lifecycle(component, &(&1))
    assert unmounted.state.unmounted
  end
end
```

### State Management Testing

```elixir
describe "State Management" do
  test "updates state through events" do
    component = create_test_component(TestComponent)

    updated = simulate_event_sequence(component, [
      %{type: :test_event},
      %{type: :test_event}
    ])

    assert updated.state.events == [:test_event, :test_event]
  end

  test "handles state updates through commands" do
    component = create_test_component(TestComponent)

    {updated, commands} = Unit.simulate_event(component, %{type: :test_event})

    assert updated.state.events == [:test_event]
    assert commands == [{:command, :event_handled}]
  end
end
```

### Event Handling Testing

```elixir
describe "Event Handling" do
  test "handles known events" do
    component = create_test_component(TestComponent)

    {updated, commands} = Unit.simulate_event(component, %{type: :test_event})

    assert updated.state.events == [:test_event]
    assert commands == [{:command, :event_handled}]
  end

  test "ignores unknown events" do
    component = create_test_component(TestComponent)

    {updated, commands} = Unit.simulate_event(component, %{type: :unknown_event})

    assert updated.state == component.state
    assert commands == []
  end
end
```

### Rendering Testing

```elixir
describe "Rendering" do
  test "renders with different contexts" do
    component = create_test_component(TestComponent)

    contexts = [
      %{theme: %{mode: :light}},
      %{theme: %{mode: :dark}},
      %{theme: %{mode: :high_contrast}}
    ]

    rendered = validate_rendering(component, contexts)

    assert length(rendered) == 3
    assert Enum.all?(rendered, &(&1.type == :test_component))
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
    child = create_test_component(ChildComponent, %{parent_id: parent.state.id})

    # Set up hierarchy
    {parent, child} = setup_component_hierarchy(ParentComponent, ChildComponent)

    # Verify hierarchy
    assert_hierarchy_valid(parent, [child])
  end

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
end
```

### Component Communication Testing

```elixir
describe "Component Communication" do
  test "broadcast events" do
    # Set up multiple components
    parent = create_test_component(ParentComponent)
    child1 = create_test_component(ChildComponent, %{parent_id: parent.state.id})
    child2 = create_test_component(ChildComponent, %{parent_id: parent.state.id})

    # Set up hierarchy
    {parent, [child1, child2]} = setup_component_hierarchy(ParentComponent, [ChildComponent, ChildComponent])

    # Simulate broadcast event
    {updated_parent, _} = Unit.simulate_event(parent, %{
      type: :broadcast,
      value: :increment
    })

    # Verify all children received the event
    updated_child1 = ComponentManager.get_component(child1.state.id)
    updated_child2 = ComponentManager.get_component(child2.state.id)
    assert updated_child1.state.value == 1
    assert updated_child2.state.value == 1
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
      events = Enum.map(1..100, &%{type: :test_event, value: "test#{&1}"})
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
      {updated, _} = Unit.simulate_event(comp, %{type: :add_data})
      assert length(updated.state.data) == 1000
    end)

    assert metrics.average_time < 1000 # Less than 1 second per iteration
  end
end
```

## Edge Case Testing

### Error Handling

```elixir
describe "Error Handling" do
  test "handles render errors gracefully" do
    component = create_test_component(ErrorProneComponent)

    # Trigger render errors
    assert_raise RuntimeError, "Simulated render error", fn ->
      simulate_event_sequence(component, [
        %{type: :trigger_error},
        %{type: :trigger_error},
        %{type: :trigger_error}
      ])
    end
  end

  test "handles event handling errors gracefully" do
    component = create_test_component(ErrorProneComponent)

    # Trigger event handling error
    assert_raise RuntimeError, "Simulated event handling error", fn ->
      Unit.simulate_event(component, %{type: :error_event})
    end
  end
end
```

### State Management Edge Cases

```elixir
describe "State Management Edge Cases" do
  test "handles nil state values" do
    component = create_test_component(ErrorProneComponent, %{last_error: nil})

    # Verify component handles nil values
    {updated, _} = Unit.simulate_event(component, %{type: :trigger_error})
    assert updated.state.last_error == :simulated_error
  end

  test "handles invalid state updates" do
    component = create_test_component(ErrorProneComponent)

    # Attempt invalid state update
    {updated, _} = Unit.simulate_event(component, %{type: :invalid_update})
    assert updated.state == component.state
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
