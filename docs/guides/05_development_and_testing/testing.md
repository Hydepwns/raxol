---
title: Testing Guide
description: Comprehensive guide for testing Raxol applications and components
date: 2025-05-10
author: Raxol Team
section: guides
tags: [guides, testing, documentation, exunit]
---

# Raxol Testing Guide

## Overview

This guide covers best practices and examples for testing Raxol applications and components. Testing typically involves standard Elixir tooling like ExUnit, complemented by project-specific helpers found in `test/support/`.

Testing strategies include:

1. **Unit Testing:** Testing individual functions or components in isolation.
2. **Integration Testing:** Testing the interaction between multiple components or parts of the application.
3. **Visual/Snapshot Testing:** Verifying the rendered output of components using snapshot testing.
4. **Performance Testing:** Measuring the performance characteristics of components or the application.
5. **Event-Based Testing:** Testing asynchronous behavior using event-based synchronization.

## Test Types & Examples

### Unit Testing

Unit tests focus on testing individual functions or modules. For UI components, this involves testing state transitions, event handling, and helper functions.

```elixir
# Example of a unit test with event-based synchronization
defmodule MyApp.MyComponentTest do
  use ExUnit.Case, async: true
  import Raxol.Test.EventAssertions

  alias MyApp.MyComponent

  test "component logic updates state correctly" do
    # Initialize component
    {:ok, component} = MyComponent.start_link([])

    # Send event and wait for state update
    MyComponent.send_event(component, :some_event, %{value: "test"})
    assert_event_received :state_updated, %{value: "test"}, 1000

    # Verify final state
    state = MyComponent.get_state(component)
    assert state.value == "test"
  end
end
```

### Plugin Testing

Plugin testing requires special consideration for system interactions and state management. Here's an example of testing a plugin:

```elixir
defmodule Raxol.Plugins.NotificationPluginTest do
  use ExUnit.Case, async: false  # Note: async: false for Mox
  import Mox

  # Define mock for system interactions
  Mox.defmock(SystemInteractionMock, for: Raxol.System.Interaction)

  # Setup Mox before each test
  setup :verify_on_exit!

  describe "handle_command" do
    setup do
      # Set up common mocks
      Mox.stub(SystemInteractionMock, :get_os_type, fn -> {:unix, :linux} end)

      # Basic state needed by the plugin
      state = %{
        interaction_module: SystemInteractionMock,
        name: "notification_test",
        enabled: true,
        config: %{},
        notifications: []
      }

      # Define test arguments
      args = ["Test Level", "Test Message"]

      %{current_state: state, args: args}
    end

    test "handles command successfully", %{current_state: state, args: args} do
      # Set up specific mock expectations
      Mox.expect(SystemInteractionMock, :find_executable, fn "notify-send" ->
        "/usr/bin/notify-send"
      end)

      # Call the command handler
      assert {:ok, _, :notification_sent} = NotificationPlugin.handle_command(args, state)
    end
  end
end
```

**Best Practices for Plugin Testing:**

1. **Mock System Interactions:**

   - Use Mox for mocking system interactions
   - Set `async: false` when using Mox
   - Use `verify_on_exit!` to ensure mock expectations are met
   - Stub common functions in setup
   - Set specific expectations in individual tests

2. **State Management:**

   - Initialize plugin state in setup blocks
   - Use consistent state structure across tests
   - Clean up state after tests
   - Test state transitions thoroughly

3. **Command Handling:**

   - Test command registration
   - Test command execution
   - Test error cases
   - Verify command results

4. **Error Handling:**
   - Test invalid inputs
   - Test system failures
   - Test edge cases
   - Verify error messages

### Integration Testing

Integration tests verify interactions between different parts of your Raxol application, focusing on event flow, component interactions, and state changes.

```elixir
# Example of integration test with event-based synchronization
defmodule MyApp.AppIntegrationTest do
  use ExUnit.Case
  import Raxol.Test.EventAssertions

  setup do
    # Start the application and wait for initialization
    {:ok, _pid} = MyApp.start_link([])
    assert_event_received :app_initialized, _, 1000

    # Return test context
    :ok
  end

  test "user action triggers expected state change across components" do
    # Simulate user action
    MyApp.send_user_action(:click_button, %{button_id: "save"})

    # Wait for and verify event chain
    assert_event_received :button_clicked, %{button_id: "save"}, 1000
    assert_event_received :save_operation_started, _, 1000
    assert_event_received :save_operation_completed, _, 1000

    # Verify final state
    state = MyApp.get_state()
    assert state.saved == true
  end
end
```

### Visual/Snapshot Testing

Visual tests ensure components render correctly by comparing output against approved snapshots.

```elixir
# Example of snapshot test with event-based synchronization
defmodule MyApp.MyComponentSnapshotTest do
  use ExUnit.Case
  import Raxol.Test.SnapshotAssertions
  import Raxol.Test.EventAssertions

  test "component renders correctly with given state" do
    # Initialize component
    {:ok, component} = MyComponent.start_link([])

    # Update state and wait for render
    MyComponent.set_state(component, %{value: "Example"})
    assert_event_received :render_completed, _, 1000

    # Capture and verify snapshot
    output = MyComponent.render(component)
    assert_snapshot "my_component_example_state", output
  end
end
```

## Test Organization

### Directory Structure

```bash
test/
  ├── support/           # Test helpers and utilities
  ├── raxol/            # Unit and integration tests
  │   ├── core/         # Core functionality tests
  │   ├── terminal/     # Terminal-specific tests
  │   └── ui/          # UI component tests
  ├── raxol_web/        # Web-specific tests (if applicable)
  └── test_helper.exs   # Test configuration
```

### Test Helpers

The `test/support/` directory contains various test helpers:

1. **Event Assertions:** Helpers for event-based testing
2. **Mock System:** Utilities for mocking system interactions
3. **Snapshot Helpers:** Tools for visual testing
4. **Performance Tools:** Benchmarking utilities

## Best Practices

### Event-Based Testing

Instead of using `Process.sleep` for asynchronous operations, use event-based synchronization:

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

### Test Isolation

1. **Parallel Execution:** Use `async: true` when possible (except with Mox)
2. **Resource Cleanup:** Always clean up resources in `on_exit` callbacks
3. **Event Timing:** Use appropriate timeouts for event assertions
4. **Snapshot Maintenance:** Update snapshots intentionally and document changes

### Mocking Strategy

1. **System Interactions:**

   - Use Mox for mocking system interactions
   - Set `async: false` when using Mox
   - Use `verify_on_exit!` to ensure mock expectations are met
   - Stub common functions in setup
   - Set specific expectations in individual tests

2. **Mock Organization:**
   - Group related mocks in setup blocks
   - Use descriptive mock names
   - Document mock behavior
   - Clean up mocks after tests

### Plugin Testing

1. **State Management:**

   - Initialize plugin state in setup blocks
   - Use consistent state structure
   - Clean up state after tests
   - Test state transitions

2. **Command Handling:**

   - Test command registration
   - Test command execution
   - Test error cases
   - Verify command results

3. **Error Handling:**
   - Test invalid inputs
   - Test system failures
   - Test edge cases
   - Verify error messages

## Current Status

As of 2025-05-08:

- 49 doctests
- 1528 tests
- 279 failures
- 17 invalid tests
- 21 skipped tests

## Common Patterns

### Event Assertions

```elixir
# Wait for specific event
assert_receive {:event_name, payload}, 5000

# Wait for multiple events
assert_receive {:first_event, _}, 5000
assert_receive {:second_event, _}, 5000

# Pattern matching
assert_receive {:event_name, %{status: :success} = payload}, 5000
```

### State Management

```elixir
# Track state changes
def handle_event(event, state) do
  new_state = %{state |
    last_event: event,
    handled_at: System.monotonic_time()
  }
  {:ok, new_state}
end
```

### Resource Cleanup

```elixir
setup do
  # Create resources
  {:ok, resource} = create_resource()

  # Ensure cleanup
  on_exit(fn ->
    cleanup_resource(resource)
  end)

  {:ok, %{resource: resource}}
end
```

## Troubleshooting

### Common Issues

1. **Test Flakiness:**

   - Replace `Process.sleep` with event assertions
   - Ensure proper resource cleanup
   - Use unique state for each test

2. **Mock Verification Failures:**

   - Reset mocks in setup
   - Use `verify_on_exit!`
   - Check mock expectations

3. **Resource Leaks:**
   - Use `on_exit` for cleanup
   - Create unique resource names
   - Track resource creation

### Debugging Tips

1. **Event Tracing:**

   ```elixir
   # Enable event tracing
   :sys.trace(pid, true)

   # Check event flow
   assert_receive {:trace, ^pid, :receive, message}, 5000
   ```

2. **State Inspection:**

   ```elixir
   # Inspect state changes
   IO.inspect(state, label: "State after event")
   ```

3. **Mock Verification:**
   ```elixir
   # Verify mock calls
   Mox.verify!(MyMock)
   ```

## Contributing

When adding new tests:

1. Follow the event-based testing pattern
2. Ensure proper test isolation
3. Use the adapter pattern for system interactions
4. Add appropriate cleanup
5. Document test requirements
6. Use meaningful error messages
7. Track test coverage

## Resources

- [ExUnit Documentation](https://hexdocs.pm/ex_unit/ExUnit.html)
- [Mox Documentation](https://hexdocs.pm/mox/Mox.html)
- [Testing Best Practices](https://hexdocs.pm/mix/Mix.Tasks.Test.html)

## Polling for State Changes in GenServer Tests

In some cases, a GenServer does not emit events or messages that can be captured with `assert_receive` after a call (e.g., after a `GenServer.cast`). In these situations, the best practice is to use a polling helper that repeatedly checks the state until a condition is met or a timeout occurs. This avoids race conditions and is more deterministic than using a fixed `Process.sleep`.

### Example: Polling for State Change in a Session Test

```elixir
defmodule Raxol.Terminal.SessionTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Session
  alias Raxol.Terminal.Emulator

  # Helper: Poll until a condition is met or timeout (default 100ms)
  defp eventually(assertion_fun, timeout_ms \\ 100) do
    start = System.monotonic_time(:millisecond)
    do_eventually(assertion_fun, start, timeout_ms)
  end

  defp do_eventually(assertion_fun, start, timeout_ms) do
    case assertion_fun.() do
      {:ok, value} -> value
      :ok -> :ok
      :error ->
        if System.monotonic_time(:millisecond) - start < timeout_ms do
          Process.sleep(2)
          do_eventually(assertion_fun, start, timeout_ms)
        else
          flunk("Condition not met within #{timeout_ms}ms")
        end
      other ->
        if System.monotonic_time(:millisecond) - start < timeout_ms do
          Process.sleep(2)
          do_eventually(assertion_fun, start, timeout_ms)
        else
          flunk("Condition not met within #{timeout_ms}ms: #{inspect(other)}")
        end
    end
  end

  test "send_input/2 processes input and updates emulator state" do
    {:ok, pid} = Session.start_link(width: 80, height: 24)
    initial_state = Session.get_state(pid)
    :ok = Session.send_input(pid, "hello world")
    eventually(fn ->
      new_state = Session.get_state(pid)
      if new_state.emulator != initial_state.emulator do
        {:ok, new_state}
      else
        :error
      end
    end)
    state = Session.get_state(pid)
    assert %Emulator{} = state.emulator
  end
end
```

**Best Practice:**

- Use polling helpers like `eventually/2` for state changes when no events are emitted.
- Avoid arbitrary `Process.sleep` calls, which can lead to race conditions and flakiness.
- Prefer event-based assertions (`assert_receive`) when the system emits events.
