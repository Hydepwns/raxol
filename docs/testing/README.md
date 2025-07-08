# Testing Guide

Complete guide to testing in Raxol, covering unit tests, integration tests, component tests, and best practices.

## Quick Reference

- [Writing Tests](#writing-tests) - Basic test structure and patterns
- [Component Testing](#component-testing) - Testing UI components
- [Performance Testing](#performance-testing) - Measuring performance
- [Quality Standards](#quality-standards) - Test quality and best practices
- [Troubleshooting](#troubleshooting) - Common issues and solutions

## Writing Tests

### Basic Test Structure

```elixir
defmodule Raxol.Feature.Test do
  use ExUnit.Case, async: true
  import Mox

  setup :verify_on_exit!

  defmock(FeatureMock, for: Raxol.Feature.Behaviour)

  setup do
    {:ok, %{test_data: "value"}}
  end

  describe "feature_name" do
    test "specific test case", %{test_data: data} do
      # Test implementation
    end
  end
end
```

### Test Categories

- **Unit Tests**: Test individual functions and modules
- **Integration Tests**: Test interactions between components
- **Performance Tests**: Measure execution time and resource usage

### Best Practices

- Use descriptive test names
- Keep tests independent and isolated
- Mock external dependencies
- Clean up resources after tests
- Document test purpose and scenarios

## Component Testing

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
end
```

## Performance Testing

### Benchmark Structure

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

### Performance Targets

- **Event Processing**: < 1ms average, < 2ms 95th percentile
- **Screen Updates**: < 2ms average, < 5ms 95th percentile
- **Concurrent Operations**: < 5ms average, < 10ms 95th percentile

## Quality Standards

### Test Structure Standards

- Use descriptive test names
- Group related tests with `describe`
- Use setup and teardown appropriately
- Maintain test isolation

### Assertion Standards

- Use clear assertion messages
- Assert one thing per test
- Cover happy path, error cases, and edge cases
- Use custom assertions when helpful

### Documentation Standards

- Document test purpose
- Explain test scenarios
- Document test data requirements

## Troubleshooting

### Common Issues

#### 1. Mox.UnexpectedCallError

**Problem**: Mocked function called without expectation.

**Solution**:
```elixir
# Add expectation before the call
expect(FeatureMock, :function_name, fn arg1, arg2 ->
  # Mock implementation
end)
```

#### 2. FunctionClauseError

**Problem**: Function called with wrong arguments.

**Solution**:
- Check argument types and patterns
- Verify function definition matches call site
- Use pattern matching appropriately

#### 3. KeyError

**Problem**: Accessing non-existent map key.

**Solution**:
```elixir
# Use Map.get with default
value = Map.get(my_map, :key, default_value)

# Or check existence first
if Map.has_key?(my_map, :key) do
  # Access the key
end
```

#### 4. Unhandled Exits in on_exit

**Problem**: Cleanup operations failing.

**Solution**:
```elixir
on_exit(fn ->
  try do
    Supervisor.stop(supervisor_pid, :shutdown, :infinity)
  catch
    :exit, reason ->
      Logger.error("Cleanup failed: #{inspect(reason)}")
  end
end)
```

### Test Helpers

#### Common Assertions

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

#### Test Setup Helpers

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

## Tools and Utilities

### Coverage

```bash
# Run tests with coverage
mix test --cover

# Generate coverage report
mix coveralls.html
```

### Quality Checks

```bash
# Run credo for code quality
mix credo

# Run dialyzer for type checking
mix dialyzer
```

### Performance Testing

```bash
# Run performance benchmarks
mix test --only performance

# Generate performance report
mix perf.report
```

## Additional Resources

- [Component Testing Guide](../components/testing.md) - Detailed component testing
- [Performance Testing Guide](performance_testing.md) - Advanced performance testing
- [Quality Guide](quality.md) - Test quality metrics and improvement
- [Tools Guide](tools.md) - Testing tools and utilities 