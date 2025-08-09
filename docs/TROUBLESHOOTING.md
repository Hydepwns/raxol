# Troubleshooting Guide

Complete guide to troubleshooting issues in Raxol, including common errors, solutions, and debugging techniques.

## Quick Reference

- [Common Errors](#common-errors) - Frequently encountered issues
- [Test Failures](#test-failures) - Testing problems and solutions
- [Performance Issues](#performance-issues) - Performance troubleshooting
- [Nix Environment](#nix-environment) - Nix-specific issues
- [Debugging](#debugging) - Debugging techniques

## Common Errors

### 1. Mox.UnexpectedCallError

**Problem**: Mocked function called without expectation.

**Example**:

```
** (Mox.UnexpectedCallError) no expectation defined for MyMockModule.my_function/1
```

**Solution**:

```elixir
# Add expectation before the call
expect(FeatureMock, :function_name, fn arg1, arg2 ->
  # Mock implementation
end)
```

### 2. FunctionClauseError

**Problem**: Function called with wrong arguments.

**Example**:

```
** (FunctionClauseError) no function clause matching in MyModule.my_function/2
Args: ("an_atom_instead_of_a_map", %{key: "value"})
```

**Solution**:

- Check argument types and patterns
- Verify function definition matches call site
- Use pattern matching appropriately

### 3. KeyError

**Problem**: Accessing non-existent map key.

**Example**:

```
** (KeyError) key :my_expected_key not found in: %{another_key: "value"}
```

**Solution**:

```elixir
# Use Map.get with default
value = Map.get(my_map, :key, default_value)

# Or check existence first
if Map.has_key?(my_map, :key) do
  # Access the key
end
```

### 4. Path-related FunctionClauseError

**Problem**: `IO.chardata_to_string/1` called with `nil`.

**Example**:

```
** (FunctionClauseError) no function clause matching in IO.chardata_to_string/1
```

**Solution**:

- Ensure module attributes for paths are defined
- Verify configuration provides valid string paths
- Check path construction logic

## Test Failures

### Unhandled Exits in on_exit

**Problem**: Cleanup operations failing in test teardown.

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

### Mocked Callback Issues

**Problem**: Event system callbacks not working with mocks.

**Solution**:

```elixir
# Initialize event system first
MySystem.enable_feature(:events)

# Manually register the mock's handler
EventManager.register_handler(
  :keyboard_event,
  MockedModule,
  :handle_keyboard_event
)

# Stub the mock's init to prevent conflicts
Mox.stub(MockedModule, :init, fn -> :ok end)

# Enable the feature that uses the mock
MySystem.enable_feature(:keyboard_shortcuts)
```

### Plugin Command Handler Errors

**Problem**: Plugin command handlers with wrong arity or patterns.

**Solution**:

```elixir
# Correct plugin command handler signature
def handle_command(command_name, args_list, state) do
  case command_name do
    :my_command -> handle_my_command(args_list, state)
    _ -> {:error, :unknown_command}
  end
end
```

## Performance Issues

### Slow Event Processing

**Symptoms**: Events taking > 1ms to process.

**Debugging**:

```elixir
# Add timing measurements
start_time = System.monotonic_time(:microsecond)
result = process_event(event)
end_time = System.monotonic_time(:microsecond)
duration = end_time - start_time

if duration > 1000 do
  Logger.warning("Slow event processing: #{duration}μs")
end
```

**Solutions**:

- Optimize event handlers
- Use event batching
- Reduce unnecessary state updates
- Profile with `:fprof`

### Memory Leaks

**Symptoms**: Memory usage growing over time.

**Debugging**:

```elixir
# Monitor memory usage
memory = :erlang.memory()
Logger.info("Memory usage: #{inspect(memory)}")
```

**Solutions**:

- Clean up resources in `unmount/1`
- Use `on_exit` for cleanup
- Monitor ETS table growth
- Check for circular references

### Slow Rendering

**Symptoms**: Screen updates taking > 2ms.

**Debugging**:

```elixir
# Profile rendering
start_time = System.monotonic_time(:microsecond)
render_result = render(state)
end_time = System.monotonic_time(:microsecond)
duration = end_time - start_time

if duration > 2000 do
  Logger.warning("Slow rendering: #{duration}μs")
end
```

**Solutions**:

- Optimize render functions
- Use memoization
- Reduce component complexity
- Implement render caching

## Nix Environment

### Shell Not Loading

**Problem**: `nix-shell` fails to load.

**Solution**:

```bash
# Update Nix channels
nix-channel --update
nix-env -u

# Clear Nix cache
nix-store --gc

# Rebuild the shell
nix-shell --run "echo 'Shell rebuilt'"
```

### PostgreSQL Issues

**Problem**: PostgreSQL fails to start or connect.

**Solution**:

```bash
# Check if PostgreSQL is running
pg_ctl -D $PGDATA status

# If not running, start it
pg_ctl -D $PGDATA start

# If there are permission issues, reinitialize
rm -rf .postgres
nix-shell  # This will reinitialize the database
```

### Native Compilation Errors

**Problem**: `termbox2_nif` or other native dependencies fail to compile.

**Solution**:

```bash
# Clean all dependencies
mix deps.clean --all

# Reinstall dependencies
mix deps.get

# Recompile with verbose output
mix deps.compile --verbose

# Check environment variables
echo $ERL_EI_INCLUDE_DIR
echo $ERL_EI_LIBDIR
echo $ERLANG_PATH
```

## Debugging

### Logging

```elixir
# Add debug logging
Logger.debug("Processing event: #{inspect(event)}")
Logger.debug("Component state: #{inspect(state)}")

# Use structured logging
Logger.info("Component lifecycle", %{
  component: component_name,
  event: event_type,
  duration: duration_ms
})
```

### Tracing

```elixir
# Enable function tracing
:dbg.tracer()
:dbg.p(:all, :c)
:dbg.tpl(MyModule, :my_function, :x)

# Or use :fprof for profiling
:fprof.apply(MyModule, :my_function, [args])
:fprof.profile()
:fprof.analyse()
```

### Interactive Debugging

```elixir
# Use IEx.pry for breakpoints
def my_function(arg) do
  require IEx; IEx.pry
  # Function body
end

# Or use :debugger
:debugger.start()
:debugger.quick(MyModule, :my_function, [args])
```

### State Inspection

```elixir
# Inspect component state
IO.inspect(component.state, label: "Component State")

# Inspect event data
IO.inspect(event, label: "Event Data")

# Inspect render result
IO.inspect(render_result, label: "Render Result")
```

## Performance Monitoring

### Metrics Collection

```elixir
# Track performance metrics
def track_performance(operation, fn ->
  start_time = System.monotonic_time(:microsecond)
  result = fn.()
  end_time = System.monotonic_time(:microsecond)
  duration = end_time - start_time

  :telemetry.execute([:raxol, :performance, operation], %{
    duration: duration,
    timestamp: System.system_time()
  })

  result
end)
```

### Performance Targets

- **Event Processing**: < 1ms average
- **Screen Updates**: < 2ms average
- **Component Initialization**: < 0.1ms
- **Memory Usage**: < 1MB per component

## Getting Help

### Before Asking for Help

1. **Check the logs**: Look for error messages and warnings
2. **Verify environment**: Run `scripts/verify_nix_env.sh`
3. **Search existing issues**: Check GitHub issues
4. **Reproduce the problem**: Create a minimal test case

### When Reporting Issues

Include:

- System information (`uname -a`, `cat /etc/os-release`)
- Nix version (`nix --version`)
- Environment variables (`env | grep -E "(ERL|ELIXIR|PG|MIX|NIX)"`)
- Error logs and stack traces
- Steps to reproduce

### Resources

- [Development Guide](DEVELOPMENT.md) - Setup and workflow
- [Nix Troubleshooting](DEVELOPMENT.md#nix-cache-issues) - Nix-specific issues
- [GitHub Issues](https://github.com/Hydepwns/raxol/issues)
