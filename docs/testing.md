# Testing Raxol Components

## Overview

Raxol provides a comprehensive testing framework for components, including utilities for component creation, event simulation, and state verification. The framework emphasizes event-based testing, proper test isolation, and performance monitoring.

## Test Helpers

### Setup Helpers (`Raxol.Test.SetupHelpers`)

The `Raxol.Test.SetupHelpers` module provides standardized setup for test environments:

```elixir
defmodule MyComponentTest do
  use ExUnit.Case
  import Raxol.Test.SetupHelpers

  setup do
    context = setup_test_env()
    {:ok, component} = setup_isolated_component(MyComponent)
    {:ok, context: context, component: component}
  end

  test "component lifecycle" do
    # Component is already set up in the context
    assert component.state != nil
  end
end
```

### Assertion Helpers (`Raxol.Test.AssertionHelpers`)

The `Raxol.Test.AssertionHelpers` module provides standardized assertions:

```elixir
defmodule MyComponentTest do
  use ExUnit.Case
  import Raxol.Test.AssertionHelpers

  test "component state" do
    assert_state_match(component, %{value: 1})
    assert_renders_with(component, "Expected Text")
    assert_matches_snapshot(component, "my_component", context)
  end
end
```

### Event Helpers (`Raxol.Test.EventHelpers`)

The `Raxol.Test.EventHelpers` module provides utilities for event testing:

```elixir
defmodule MyComponentTest do
  use ExUnit.Case
  import Raxol.Test.EventHelpers

  test "event handling" do
    simulate_user_action(component, {:click, {10, 10}})
    assert_child_received(child, :click)
    assert_parent_updated(parent, :child_clicked)
  end
end
```

### Performance Helpers (`Raxol.Test.PerformanceHelpers`)

The `Raxol.Test.PerformanceHelpers` module provides performance testing utilities:

```elixir
defmodule MyComponentTest do
  use ExUnit.Case
  import Raxol.Test.PerformanceHelpers

  test "performance metrics" do
    assert_performance_metrics(
      fn -> simulate_user_action(component, {:click, {10, 10}}) end,
      "click handling"
    )
  end
end
```

## Best Practices

### 1. Event-Based Testing

Replace `Process.sleep` with event-based assertions:

```elixir
# Bad: Using Process.sleep
def test_async_operation do
  start_operation()
  Process.sleep(100)  # Arbitrary wait time
  assert result == expected
end

# Good: Using event-based synchronization
def test_async_operation do
  start_operation()
  assert_event_received :operation_completed, expected_result, 1000
end
```

### 2. Test Isolation

- Use `async: true` when possible (except with Mox)
- Clean up resources in `on_exit` callbacks
- Use appropriate timeouts for event assertions
- Update snapshots intentionally and document changes

### 3. Component Testing

```elixir
defmodule MyComponentTest do
  use ExUnit.Case
  import Raxol.Test.SetupHelpers
  import Raxol.Test.AssertionHelpers
  import Raxol.Test.EventHelpers
  import Raxol.Test.PerformanceHelpers

  setup do
    context = setup_test_env()
    {:ok, component} = setup_isolated_component(MyComponent)
    {:ok, context: context, component: component}
  end

  describe "Component Lifecycle" do
    test "initializes with default state" do
      assert_state_match(component, %{value: 0})
    end

    test "handles user events" do
      simulate_user_action(component, {:click, {10, 10}})
      assert_state_match(component, %{clicked: true})
    end

    test "meets performance requirements" do
      assert_performance_metrics(
        fn -> simulate_user_action(component, {:click, {10, 10}}) end,
        "click handling"
      )
    end
  end
end
```

### 4. Integration Testing

```elixir
defmodule ComponentIntegrationTest do
  use ExUnit.Case
  import Raxol.Test.SetupHelpers
  import Raxol.Test.EventHelpers

  setup do
    context = setup_test_env()
    {parent, child} = setup_component_hierarchy(ParentComponent, ChildComponent)
    {:ok, context: context, parent: parent, child: child}
  end

  test "parent-child communication" do
    simulate_user_action(child, {:click, {10, 10}})
    assert_parent_updated(parent, :child_clicked)
    assert_state_synchronized([parent, child], fn states ->
      [parent_state, child_state] = states
      parent_state.child_states[child_state.id] == child_state
    end)
  end
end
```

### 5. Performance Testing

```elixir
defmodule PerformanceTest do
  use ExUnit.Case
  import Raxol.Test.PerformanceHelpers

  test "render performance" do
    assert_performance(
      fn -> component.render(state) end,
      "component render",
      0.001,
      1000
    )
  end

  test "memory usage" do
    assert_memory_usage(
      fn -> component.render(state) end,
      "component render",
      1_000_000
    )
  end
end
```

## Troubleshooting

### Common Issues

1. **Test Flakiness**

   - Replace `Process.sleep` with event assertions
   - Ensure proper resource cleanup
   - Use unique state for each test

2. **Mock Verification Failures**

   - Reset mocks in setup
   - Use `verify_on_exit!`
   - Check mock expectations

3. **Resource Leaks**
   - Use `on_exit` for cleanup
   - Create unique resource names
   - Track resource creation

### Debugging Tips

1. **Event Tracing**

   ```elixir
   :sys.trace(pid, true)
   assert_receive {:trace, ^pid, :receive, message}, 5000
   ```

2. **State Inspection**

   ```elixir
   IO.inspect(state, label: "State after event")
   ```

3. **Mock Verification**
   ```elixir
   Mox.verify!(MyMock)
   ```

## Resources

- [ExUnit Documentation](https://hexdocs.pm/ex_unit/ExUnit.html)
- [Mox Documentation](https://hexdocs.pm/mox/Mox.html)
- [Testing Best Practices](https://hexdocs.pm/mix/Mix.Tasks.Test.html)
