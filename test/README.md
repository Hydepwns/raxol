# Raxol Test Suite

This directory contains the test suite for Raxol. The tests are designed to be reliable, fast, and maintainable.

## Test Structure

- `test/support/` - Test helpers and support modules
  - `data_case.ex` - Database test setup
  - `test_helpers.ex` - Common test utilities
- `test/` - Test files organized by module/feature

## Best Practices

1. **No Process.sleep**

   - Use event-based synchronization with `assert_receive`
   - Use `Raxol.TestHelpers.wait_for_state/2` for polling conditions
   - Example:

     ```elixir
     # Instead of:
     Process.sleep(100)
     assert condition

     # Use:
     Raxol.TestHelpers.wait_for_state(fn -> condition end, 100)
     ```

2. **Resource Cleanup**

   - Use `on_exit` callbacks in `setup` blocks
   - Clean up processes, ETS tables, and temporary files
   - Example:
     ```elixir
     setup do
       dir = Raxol.TestHelpers.create_temp_dir()
       on_exit(fn -> Raxol.TestHelpers.cleanup_temp_dir(dir) end)
       {:ok, dir: dir}
     end
     ```

3. **Database Tests**

   - Use `Raxol.DataCase` for database-backed tests
   - Set `async: false` for tests that modify shared state
   - Example:
     ```elixir
     defmodule MyApp.MyTest do
       use Raxol.DataCase, async: false
       # ...
     end
     ```

4. **Test Isolation**

   - Use unique names for processes in each test
   - Reset shared state in `setup` blocks
   - Use `async: false` where needed
   - Example:
     ```elixir
     setup do
       name = :"test_process_#{:rand.uniform(1000000)}"
       {:ok, pid} = GenServer.start_link(MyServer, [], name: name)
       on_exit(fn -> Raxol.TestHelpers.cleanup_process(pid) end)
       {:ok, name: name}
     end
     ```

5. **Event-Based Testing**
   - Use `assert_receive` for event-based synchronization
   - Use `ref = make_ref()` for precise timing
   - Example:
     ```elixir
     ref = make_ref()
     send(pid, {:do_something, ref})
     assert_receive {:done, ^ref}, 1000
     ```

## Test Categories

1. **Unit Tests**

   - Test individual functions and modules
   - Use `ExUnit.Case`
   - Can run in parallel (`async: true`)

2. **Integration Tests**

   - Test component interactions
   - Use `ExUnit.Case, async: false`
   - May need database access

3. **Database Tests**

   - Test database operations
   - Use `Raxol.DataCase`
   - Always `async: false`

4. **Performance Tests**
   - Test performance characteristics
   - Use `ExUnit.Case, async: false`
   - May need longer timeouts

## Running Tests

```bash
# Run all tests
mix test

# Run specific test file
mix test test/path/to/test.exs

# Run specific test
mix test test/path/to/test.exs:123
```

## Test Configuration

Test configuration is in `config/test.exs`. Key settings:

- Database pool size: 10
- Logger level: :warn
- Assert receive timeout: 1000ms
- Test mode enabled
- Database enabled

## Adding New Tests

1. Choose the appropriate test case:

   - `ExUnit.Case` for basic tests
   - `Raxol.DataCase` for database tests
   - `Raxol.ConnCase` for web tests

2. Follow the best practices above

3. Add proper cleanup in `setup` blocks

4. Use the test helpers from `Raxol.TestHelpers`

5. Document any special test requirements

## Test Helpers

### Raxol.TestHelpers

Common test utilities for:

- Event-based synchronization
- Process cleanup
- ETS table management
- Registry cleanup
- Temporary file handling

### Raxol.DataCase

Database test utilities for:

- Transaction management
- Sandbox setup
- Error handling
- Changeset validation

## Troubleshooting

1. **Flaky Tests**

   - Replace `Process.sleep` with event-based synchronization
   - Ensure proper resource cleanup
   - Use unique state for each test

2. **Database Issues**

   - Use `Raxol.DataCase`
   - Set `async: false`
   - Clean up after tests

3. **Process Cleanup**

   - Use `on_exit` callbacks
   - Monitor process state
   - Clean up resources

4. **Event Timing**
   - Use appropriate timeouts
   - Add event tracing
   - Check event propagation
