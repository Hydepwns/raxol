# Component Testing Guide

Essential testing patterns and best practices for Raxol components.

## Quick Reference

- [Test Structure](#test-structure) - Test organization and setup
- [Lifecycle Testing](#lifecycle-testing) - Testing component lifecycle
- [Event Testing](#event-testing) - Testing event handling
- [State Testing](#state-testing) - Testing state management
- [Integration Testing](#integration-testing) - Testing component interactions

## Test Structure

### Basic Test Module

```elixir
defmodule Raxol.UI.Components.Input.TextInputTest do
  use ExUnit.Case, async: true
  import Raxol.ComponentTestHelpers

  alias Raxol.UI.Components.Input.TextInput

  describe "Component Lifecycle" do
    test "initializes with props" do
      props = %{value: "test", placeholder: "Enter text"}
      component = create_component(TextInput, props)
      
      assert component.state.value == "test"
      assert component.state.placeholder == "Enter text"
    end

    test "mounts correctly" do
      component = create_component(TextInput, %{})
      {mounted, commands} = simulate_mount(component)
      
      assert mounted.state.mounted == true
      assert commands == []
    end

    test "unmounts correctly" do
      component = create_component(TextInput, %{})
      mounted = simulate_mount(component)
      unmounted = simulate_unmount(mounted)
      
      assert unmounted.state.mounted == false
    end
  end

  describe "Event Handling" do
    test "handles text change events" do
      component = create_component(TextInput, %{})
      event = %{type: :change, value: "new value"}
      {updated, commands} = simulate_event(component, event)
      
      assert updated.state.value == "new value"
      assert commands == [{:command, :value_changed}]
    end

    test "handles focus events" do
      component = create_component(TextInput, %{})
      event = %{type: :focus}
      {updated, commands} = simulate_event(component, event)
      
      assert updated.state.focused == true
      assert commands == [{:command, :focus_gained}]
    end

    test "handles invalid events gracefully" do
      component = create_component(TextInput, %{})
      event = %{type: :invalid_event}
      {updated, commands} = simulate_event(component, event)
      
      assert updated.state == component.state
      assert commands == []
    end
  end

  describe "State Management" do
    test "updates state immutably" do
      component = create_component(TextInput, %{})
      message = {:set_value, "new value"}
      {updated, commands} = simulate_update(component, message)
      
      assert updated.state.value == "new value"
      assert updated.state != component.state
    end

    test "validates state changes" do
      component = create_component(TextInput, %{})
      message = {:set_value, nil}
      {updated, commands} = simulate_update(component, message)
      
      assert updated.state.error != nil
      assert commands == [{:command, :validation_failed}]
    end
  end

  describe "Rendering" do
    test "renders correctly" do
      component = create_component(TextInput, %{value: "test"})
      element = simulate_render(component)
      
      assert element.type == :text_input
      assert element.content == "test"
      assert element.attributes.focused == false
    end

    test "renders with error state" do
      component = create_component(TextInput, %{})
      component = %{component | state: Map.put(component.state, :error, "Invalid input")}
      element = simulate_render(component)
      
      assert element.attributes.error == "Invalid input"
      assert element.attributes.color == :red
    end
  end
end
```

## Lifecycle Testing

### Initialization Testing

```elixir
describe "Initialization" do
  test "sets default values" do
    component = create_component(TextInput, %{})
    
    assert component.state.value == ""
    assert component.state.focused == false
    assert component.state.error == nil
  end

  test "validates required props" do
    assert_raise ArgumentError, fn ->
      create_component(TextInput, %{})
    end
  end

  test "handles optional props" do
    component = create_component(TextInput, %{
      value: "test",
      placeholder: "Enter text",
      disabled: true
    })
    
    assert component.state.value == "test"
    assert component.state.placeholder == "Enter text"
    assert component.state.disabled == true
  end
end
```

### Mount/Unmount Testing

```elixir
describe "Mount/Unmount" do
  test "sets up resources on mount" do
    component = create_component(TextInput, %{})
    {mounted, commands} = simulate_mount(component)
    
    assert mounted.state.mounted == true
    assert commands == [{:command, :resources_setup}]
  end

  test "cleans up resources on unmount" do
    component = create_component(TextInput, %{})
    mounted = simulate_mount(component)
    unmounted = simulate_unmount(mounted)
    
    assert unmounted.state.mounted == false
    assert unmounted.state.resources_cleaned == true
  end
end
```

## Event Testing

### Input Event Testing

```elixir
describe "Input Events" do
  test "handles text input changes" do
    component = create_component(TextInput, %{})
    
    events = [
      %{type: :change, value: "h"},
      %{type: :change, value: "he"},
      %{type: :change, value: "hel"},
      %{type: :change, value: "hell"},
      %{type: :change, value: "hello"}
    ]
    
    final_component = Enum.reduce(events, component, fn event, acc ->
      {updated, _} = simulate_event(acc, event)
      updated
    end)
    
    assert final_component.state.value == "hello"
  end

  test "handles keyboard events" do
    component = create_component(TextInput, %{})
    
    # Test enter key
    {updated, commands} = simulate_event(component, %{type: :key_press, key: :enter})
    assert commands == [{:command, :submitted}]
    
    # Test escape key
    {updated, commands} = simulate_event(updated, %{type: :key_press, key: :escape})
    assert commands == [{:command, :cancelled}]
  end

  test "handles focus events" do
    component = create_component(TextInput, %{})
    
    # Focus
    {focused, commands} = simulate_event(component, %{type: :focus})
    assert focused.state.focused == true
    assert commands == [{:command, :focus_gained}]
    
    # Blur
    {blurred, commands} = simulate_event(focused, %{type: :blur})
    assert blurred.state.focused == false
    assert commands == [{:command, :focus_lost}]
  end
end
```

### Error Event Testing

```elixir
describe "Error Handling" do
  test "handles validation errors" do
    component = create_component(TextInput, %{})
    event = %{type: :change, value: "invalid_value"}
    {updated, commands} = simulate_event(component, event)
    
    assert updated.state.error != nil
    assert commands == [{:command, :validation_failed}]
  end

  test "recovers from errors" do
    component = create_component(TextInput, %{})
    component = %{component | state: Map.put(component.state, :error, "Invalid")}
    
    event = %{type: :change, value: "valid_value"}
    {updated, commands} = simulate_event(component, event)
    
    assert updated.state.error == nil
    assert commands == [{:command, :value_changed}]
  end
end
```

## State Testing

### State Update Testing

```elixir
describe "State Updates" do
  test "updates state immutably" do
    component = create_component(TextInput, %{})
    original_state = component.state
    
    message = {:set_value, "new value"}
    {updated, _} = simulate_update(component, message)
    
    assert updated.state.value == "new value"
    assert updated.state != original_state
  end

  test "batches multiple updates" do
    component = create_component(TextInput, %{})
    
    updates = [
      {:set_value, "first"},
      {:set_focused, true},
      {:set_error, "test error"}
    ]
    
    final_component = Enum.reduce(updates, component, fn update, acc ->
      {updated, _} = simulate_update(acc, update)
      updated
    end)
    
    assert final_component.state.value == "first"
    assert final_component.state.focused == true
    assert final_component.state.error == "test error"
  end
end
```

### State Validation Testing

```elixir
describe "State Validation" do
  test "validates state constraints" do
    component = create_component(TextInput, %{})
    
    # Test invalid state
    invalid_state = Map.put(component.state, :value, nil)
    component = %{component | state: invalid_state}
    
    assert_raise ArgumentError, fn ->
      simulate_render(component)
    end
  end

  test "maintains state invariants" do
    component = create_component(TextInput, %{})
    
    # Test that focused and error can't both be true
    component = %{component | state: %{
      component.state | 
      focused: true,
      error: "test error"
    }}
    
    {updated, _} = simulate_event(component, %{type: :focus})
    assert updated.state.focused == true
    assert updated.state.error == nil
  end
end
```

## Integration Testing

### Component Interaction Testing

```elixir
describe "Component Interactions" do
  test "communicates with parent component" do
    parent = create_component(ParentComponent, %{})
    child = create_component(TextInput, %{})
    
    # Simulate child event
    event = %{type: :change, value: "new value"}
    {updated_child, commands} = simulate_event(child, event)
    
    # Simulate parent receiving command
    parent_event = {:child_command, commands}
    {updated_parent, _} = simulate_event(parent, parent_event)
    
    assert updated_parent.state.child_value == "new value"
  end

  test "handles multiple child components" do
    parent = create_component(FormComponent, %{})
    
    # Create multiple text inputs
    inputs = [
      create_component(TextInput, %{id: "name"}),
      create_component(TextInput, %{id: "email"}),
      create_component(TextInput, %{id: "phone"})
    ]
    
    # Simulate events on each input
    events = [
      %{id: "name", type: :change, value: "John"},
      %{id: "email", type: :change, value: "john@example.com"},
      %{id: "phone", type: :change, value: "123-456-7890"}
    ]
    
    final_parent = Enum.reduce(events, parent, fn event, acc ->
      {updated, _} = simulate_event(acc, event)
      updated
    end)
    
    assert final_parent.state.form_data.name == "John"
    assert final_parent.state.form_data.email == "john@example.com"
    assert final_parent.state.form_data.phone == "123-456-7890"
  end
end
```

### Performance Testing

```elixir
describe "Performance" do
  test "renders within time limit" do
    component = create_component(TextInput, %{})
    
    start_time = System.monotonic_time(:microsecond)
    element = simulate_render(component)
    end_time = System.monotonic_time(:microsecond)
    
    render_time = end_time - start_time
    assert render_time < 2000  # 2ms limit
    assert element != nil
  end

  test "handles rapid events efficiently" do
    component = create_component(TextInput, %{})
    
    # Generate 100 rapid events
    events = for i <- 1..100 do
      %{type: :change, value: "value_#{i}"}
    end
    
    start_time = System.monotonic_time(:microsecond)
    
    final_component = Enum.reduce(events, component, fn event, acc ->
      {updated, _} = simulate_event(acc, event)
      updated
    end)
    
    end_time = System.monotonic_time(:microsecond)
    total_time = end_time - start_time
    
    assert total_time < 100_000  # 100ms limit
    assert final_component.state.value == "value_100"
  end
end
```

## Test Helpers

### Common Test Utilities

```elixir
defmodule Raxol.ComponentTestHelpers do
  import ExUnit.Assertions

  def create_component(module, props) do
    state = module.init(props)
    %{
      module: module,
      state: state,
      props: props
    }
  end

  def simulate_mount(component) do
    {state, commands} = component.module.mount(component.state)
    {%{component | state: state}, commands}
  end

  def simulate_unmount(component) do
    state = component.module.unmount(component.state)
    %{component | state: state}
  end

  def simulate_update(component, message) do
    {state, commands} = component.module.update(message, component.state)
    {%{component | state: state}, commands}
  end

  def simulate_render(component) do
    component.module.render(component.state)
  end

  def simulate_event(component, event) do
    {state, commands} = component.module.handle_event(event, component.state)
    {%{component | state: state}, commands}
  end

  def assert_state_unchanged(component, updated) do
    assert updated.state == component.state
  end

  def assert_commands_contain(commands, expected_command) do
    assert Enum.any?(commands, fn cmd -> cmd == expected_command end)
  end

  def assert_element_has_attribute(element, attribute, value) do
    assert get_in(element, [:attributes, attribute]) == value
  end
end
```

## Best Practices

### Test Organization

1. **Group Related Tests**: Use `describe` blocks to group related tests
2. **Clear Test Names**: Use descriptive test names that explain the scenario
3. **Arrange-Act-Assert**: Structure tests with clear setup, action, and verification
4. **Test One Thing**: Each test should verify one specific behavior

### Test Data

1. **Use Fixtures**: Create reusable test data
2. **Edge Cases**: Test boundary conditions and error cases
3. **Realistic Data**: Use realistic test data that matches production scenarios
4. **Randomization**: Use randomized data for stress testing

### Test Maintenance

1. **Keep Tests Simple**: Avoid complex test logic
2. **Update Tests**: Keep tests in sync with component changes
3. **Remove Dead Tests**: Delete tests for removed functionality
4. **Document Complex Tests**: Add comments for complex test scenarios

## Additional Resources

- [Component Guide](README.md) - Component development patterns
- [API Reference](api/README.md) - Component APIs
- [Style Guide](style_guide.md) - Styling and design patterns
