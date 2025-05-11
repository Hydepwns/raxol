# Test Writing Guide

## Overview

This guide outlines the best practices and standards for writing tests in the Raxol project. Following these guidelines ensures consistency, maintainability, and reliability of our test suite.

## Test Structure

### 1. Test Module Organization

```elixir
defmodule Raxol.Feature.Test do
  use ExUnit.Case, async: true
  import Mox

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  # Define mocks
  defmock(FeatureMock, for: Raxol.Feature.Behaviour)

  # Setup block for common test data
  setup do
    # Setup test data
    {:ok, %{test_data: "value"}}
  end

  describe "feature_name" do
    test "specific test case", %{test_data: data} do
      # Test implementation
    end
  end
end
```

### 2. Test Categories

#### Unit Tests

- Test individual functions and modules
- Mock external dependencies
- Focus on specific functionality
- Use clear, descriptive test names

#### Integration Tests

- Test interactions between components
- Use real dependencies where appropriate
- Focus on end-to-end functionality
- Include setup and teardown of test environment

#### Performance Tests

- Measure execution time and resource usage
- Compare against performance targets
- Include stress testing scenarios
- Document performance requirements

## Best Practices

### 1. Test Naming

```elixir
# Good
test "handles missing dependency gracefully"
test "processes valid input correctly"
test "returns error for invalid version"

# Bad
test "test1"
test "dependency test"
test "version test"
```

### 2. Test Isolation

- Each test should be independent
- Clean up resources after tests
- Use setup blocks for common setup
- Avoid test interdependencies

### 3. Mocking

```elixir
# Define mock
defmock(FeatureMock, for: Raxol.Feature.Behaviour)

# Setup mock expectations
expect(FeatureMock, :function_name, fn arg1, arg2 ->
  # Mock implementation
end)

# Verify mock calls
verify!(FeatureMock)
```

### 4. Assertions

```elixir
# Basic assertions
assert result == expected
assert_raise ErrorType, fn -> code end
assert_receive {:event, data}

# Custom assertions
assert_matches_any_pattern(result, [pattern1, pattern2])
assert_performance_meets_targets(measurements, targets)
```

### 5. Error Handling

```elixir
# Test error cases
test "handles error gracefully" do
  assert {:error, reason} = function_call()
  assert reason == :expected_error
end

# Test error recovery
test "recovers from error state" do
  # Setup error state
  # Verify recovery
  assert :ok == recovery_function()
end
```

## Performance Testing

### 1. Benchmark Structure

```elixir
test "meets performance targets" do
  measurements = Benchmark.measure(fn ->
    # Code to measure
  end)

  assert_performance_meets_targets(measurements, %{
    average: 1,    # ms
    p95: 2,        # ms
    p99: 5         # ms
  })
end
```

### 2. Performance Targets

- Event Processing: < 1ms average, < 2ms 95th percentile
- Screen Updates: < 2ms average, < 5ms 95th percentile
- Concurrent Operations: < 5ms average, < 10ms 95th percentile

## Test Helpers

### 1. Common Assertions

```elixir
defmodule Raxol.Test.AssertionHelpers do
  def assert_matches_any_pattern(term, patterns) do
    assert Enum.any?(patterns, &match?(&1, term))
  end

  def assert_performance_meets_targets(measurements, targets) do
    assert measurements.average <= targets.average
    assert measurements.p95 <= targets.p95
    assert measurements.p99 <= targets.p99
  end
end
```

### 2. Test Setup Helpers

```elixir
defmodule Raxol.Test.SetupHelpers do
  def setup_test_environment do
    # Setup test environment
  end

  def cleanup_test_environment do
    # Cleanup test environment
  end
end
```

## Documentation

### 1. Test Documentation

```elixir
@moduledoc """
Tests for the Feature module.

These tests verify:
- Basic functionality
- Error handling
- Performance requirements
- Integration with other components
"""

test "specific test case" do
  @moduledoc """
  Verifies that the feature handles specific case correctly.

  Steps:
  1. Setup test data
  2. Execute function
  3. Verify results

  Expected:
  - Correct output
  - No side effects
  - Performance targets met
  """
end
```

### 2. Test Coverage

- Document test coverage requirements
- Include edge cases
- Test error conditions
- Verify performance targets

## Common Patterns

### 1. Async Testing

```elixir
use ExUnit.Case, async: true

test "handles concurrent operations" do
  tasks = for _ <- 1..10 do
    Task.async(fn -> operation() end)
  end

  results = Task.await_many(tasks, 5000)
  assert Enum.all?(results, &valid_result?/1)
end
```

### 2. State Management

```elixir
setup do
  state = initial_state()
  {:ok, %{state: state}}
end

test "updates state correctly", %{state: state} do
  new_state = update_state(state)
  assert state_changed_correctly?(state, new_state)
end
```

### 3. Event Testing

```elixir
test "handles events correctly" do
  # Setup event handler
  # Send event
  # Verify event handling
  assert_receive {:event_handled, result}
  assert result == expected
end
```

## Troubleshooting

### 1. Common Issues

- Test isolation failures
- Mock verification errors
- Performance test flakiness
- Resource cleanup issues

### 2. Debugging Tips

- Use `IO.inspect/2` for debugging
- Check test isolation
- Verify mock expectations
- Monitor resource usage

## Resources

- [ExUnit Documentation](https://hexdocs.pm/ex_unit/ExUnit.html)
- [Mox Documentation](https://hexdocs.pm/mox/Mox.html)
- [Performance Testing Guide](docs/testing/performance_testing.md)
