# Testing Workflow Guide

## Overview
Raxol maintains 98.7% test coverage with 1751+ tests. This guide covers testing strategies, patterns, and commands for maintaining quality.

## Test Organization

### Test Structure
```
test/
├── raxol/                    # Unit tests (mirrors lib/raxol/)
├── raxol_web/                # Web interface tests
├── integration/              # Integration tests (@tag :integration)
├── performance/              # Performance tests (@tag :performance)
├── support/                  # Test helpers and mocks
└── platform_specific/        # Platform-specific tests
```

### Test Types

#### 1. Unit Tests
Fast, isolated tests for individual modules:
```elixir
defmodule Raxol.Terminal.BufferTest do
  use ExUnit.Case, async: true
  
  describe "write_char/3" do
    test "writes character at position" do
      buffer = Buffer.new(80, 24)
      buffer = Buffer.write_char(buffer, 0, 0, "A")
      assert Buffer.get_char(buffer, 0, 0) == "A"
    end
  end
end
```

#### 2. Integration Tests
Tests that verify component interaction:
```elixir
@tag :integration
test "terminal processes input and updates buffer" do
  {:ok, emulator} = Emulator.start_link()
  Emulator.write(emulator, "Hello\r\n")
  assert Emulator.read_line(emulator, 0) =~ "Hello"
end
```

#### 3. Performance Tests
Benchmarks and performance regression tests:
```elixir
@tag :performance
test "buffer operations meet performance targets" do
  buffer = Buffer.new(1000, 1000)
  
  {time, _} = :timer.tc(fn ->
    for row <- 0..999, col <- 0..999 do
      Buffer.write_char(buffer, row, col, "X")
    end
  end)
  
  assert time < 1_000_000  # Less than 1 second
end
```

## Essential Test Commands

### Basic Testing
```bash
# Run all tests (excludes slow/integration by default)
mix test

# Run specific test file
mix test test/raxol/terminal/buffer_test.exs

# Run specific test by line number
mix test test/raxol/terminal/buffer_test.exs:42

# Run tests matching pattern
mix test --only buffer
```

### Advanced Testing
```bash
# Run with failure limit
mix test --max-failures 3

# Run with specific seed for reproducibility
mix test --seed 42

# Run previously failed tests
mix test --failed

# Run with timeout to prevent hanging
timeout 60 mix test

# Run all tests including slow ones
mix test --include integration --include slow --include performance
```

### Coverage Analysis
```bash
# Generate coverage report
mix test --cover

# Detailed coverage
mix coveralls.html
open cover/excoveralls.html
```

## Test Patterns

### 1. Setup and Teardown
```elixir
setup do
  # Setup before each test
  {:ok, pid} = GenServer.start_link(MyServer, [])
  
  on_exit(fn ->
    # Cleanup after test
    GenServer.stop(pid)
  end)
  
  {:ok, server: pid}
end

test "server responds", %{server: server} do
  assert GenServer.call(server, :ping) == :pong
end
```

### 2. Mocking with Mox
```elixir
# In test
Mox.defmock(MockTerminal, for: Raxol.Terminal.Behaviour)

setup :verify_on_exit!

test "handles terminal input" do
  expect(MockTerminal, :write, fn data ->
    assert data == "test"
    :ok
  end)
  
  MyModule.process_input("test")
end
```

### 3. Property-Based Testing
```elixir
use ExUnitProperties

property "buffer maintains dimensions" do
  check all width <- positive_integer(),
            height <- positive_integer(),
            max_runs: 100 do
    buffer = Buffer.new(width, height)
    assert Buffer.width(buffer) == width
    assert Buffer.height(buffer) == height
  end
end
```

### 4. Async Testing
```elixir
use ExUnit.Case, async: true  # Enable for independent tests

test "concurrent operations" do
  tasks = for i <- 1..100 do
    Task.async(fn ->
      MyModule.process(i)
    end)
  end
  
  results = Task.await_many(tasks)
  assert length(results) == 100
end
```

## Common Test Scenarios

### Testing GenServers
```elixir
test "genserver state management" do
  {:ok, pid} = MyServer.start_link(initial_state: 0)
  
  assert MyServer.get_state(pid) == 0
  MyServer.increment(pid)
  assert MyServer.get_state(pid) == 1
  
  GenServer.stop(pid)
end
```

### Testing Supervisors
```elixir
test "supervisor restarts children" do
  {:ok, sup} = MySupervisor.start_link()
  
  [{_, child_pid, _, _}] = Supervisor.which_children(sup)
  Process.exit(child_pid, :kill)
  
  :timer.sleep(100)
  
  [{_, new_pid, _, _}] = Supervisor.which_children(sup)
  assert new_pid != child_pid
  assert Process.alive?(new_pid)
end
```

### Testing Events
```elixir
test "event dispatch and handling" do
  EventManager.subscribe(:test_event)
  
  EventManager.dispatch(:test_event, %{data: "test"})
  
  assert_receive {:test_event, %{data: "test"}}, 100
end
```

## Debugging Failed Tests

### 1. Run with Detailed Output
```bash
# Verbose output
mix test --trace

# With specific reporter
mix test --formatter ExUnit.CLIFormatter
```

### 2. Focus on Single Test
```elixir
@tag :focus
test "debugging this specific test" do
  # test code
end
```
Run with: `mix test --only focus`

### 3. Add Debug Output
```elixir
test "debug output" do
  value = compute_something()
  IO.inspect(value, label: "Debug value")
  require IEx; IEx.pry()  # Breakpoint
  assert value == expected
end
```

### 4. Check Test Logs
```bash
# Set log level for tests
MIX_ENV=test TERMINAL_LOG_LEVEL=debug mix test
```

## Test Helpers

### Common Test Utilities
Location: `test/support/`

```elixir
# test/support/test_helpers.ex
defmodule Raxol.TestHelpers do
  def create_buffer(opts \\ []) do
    width = Keyword.get(opts, :width, 80)
    height = Keyword.get(opts, :height, 24)
    Buffer.new(width, height)
  end
  
  def wait_for(fun, timeout \\ 1000) do
    # Implementation
  end
end
```

### Fixtures
```elixir
# test/support/fixtures.ex
defmodule Raxol.Fixtures do
  def ansi_sequence(:clear), do: "\e[2J"
  def ansi_sequence(:home), do: "\e[H"
  def ansi_sequence(:bold), do: "\e[1m"
end
```

## CI/CD Test Configuration

### GitHub Actions
```yaml
# .github/workflows/test.yml
- name: Run tests
  run: |
    mix test --cover --warnings-as-errors
    mix format --check-formatted
    mix credo --strict
```

### Local CI Simulation
```bash
# Run full CI suite locally
./scripts/ci.sh

# Or manually:
mix format --check-formatted && \
mix compile --warnings-as-errors && \
mix credo --strict && \
mix test --cover && \
mix dialyzer
```

## Performance Testing

### Benchmarking
```elixir
# bench/my_benchmark.exs
Benchee.run(%{
  "buffer_write" => fn ->
    Buffer.write_char(buffer, 0, 0, "A")
  end,
  "buffer_read" => fn ->
    Buffer.get_char(buffer, 0, 0)
  end
})
```

Run with: `mix run bench/my_benchmark.exs`

### Load Testing
```elixir
@tag :load
test "handles concurrent connections" do
  tasks = for _ <- 1..1000 do
    Task.async(fn ->
      {:ok, conn} = Terminal.connect()
      Terminal.write(conn, "test")
      Terminal.disconnect(conn)
    end)
  end
  
  Task.await_many(tasks, 30_000)
end
```

## Test Maintenance

### Keep Tests Fast
- Use `async: true` when possible
- Mock external dependencies
- Use factories for test data
- Avoid sleep/timing dependencies

### Keep Tests Reliable
- Clean up resources in `on_exit`
- Use deterministic seeds
- Isolate test data
- Avoid shared state

### Keep Tests Readable
- Descriptive test names
- Clear assertions
- Minimal setup
- Focus on one behavior

## Troubleshooting

### Common Issues

#### Tests Hanging
```bash
# Use timeout wrapper
timeout 60 mix test

# Find hanging test
mix test --trace
```

#### Flaky Tests
```bash
# Run multiple times with same seed
for i in {1..10}; do
  mix test test/flaky_test.exs --seed 42
done
```

#### Module Loading Issues
```elixir
# Clear module cache in test
setup do
  :code.purge(MyModule)
  :code.delete(MyModule)
  {:ok, []}
end
```

## Best Practices

1. **Write tests first** - TDD approach
2. **One assertion per test** - Clear failures
3. **Test behavior, not implementation** - Resilient tests
4. **Use descriptive names** - Self-documenting
5. **Keep tests DRY** - Extract helpers
6. **Mock at boundaries** - Not internals
7. **Test edge cases** - Empty, nil, boundaries
8. **Maintain coverage** - Keep above 98%