# Raxol Error Handling Style Guide

## Philosophy

Raxol follows functional programming principles for error handling, favoring explicit error propagation over exceptions. This guide outlines the patterns and best practices for error handling throughout the codebase.

## Core ErrorHandling Module Functions

The `Raxol.Core.ErrorHandling` module provides the primary functions for safe execution:

### Primary Functions

- **`safe_call/1`** - Executes a function and returns `{:ok, result}` or `{:error, error}`
- **`safe_call_with_info/1`** - Like `safe_call/1` but includes stacktrace for debugging
- **`safe_genserver_call/3`** - Makes GenServer calls with proper timeout and error handling

### Supporting Functions

- **`safe_call_with_default/2`** - Returns a default value on error
- **`safe_apply/3`** - Safely calls module functions, checking if they're exported
- **`safe_callback/3`** - Calls optional callbacks, returns `{:ok, nil}` if not found
- **`safe_deserialize/1`** - Safely deserializes binary data
- **`safe_serialize/1`** - Safely serializes terms to binary

## Core Principles

1. **Explicit over Implicit**: Errors should be explicit in function signatures
2. **Composable**: Error handling should work well with pipelines
3. **Recoverable**: Provide sensible defaults where appropriate
4. **Traceable**: Log errors with context for debugging

## Preferred Patterns

### ✅ Use Result Types

```elixir
# Good - Explicit error handling
def fetch_data(id) do
  case Database.get(id) do
    nil -> {:error, :not_found}
    data -> {:ok, data}
  end
end

# Usage with pattern matching
case fetch_data(123) do
  {:ok, data} -> process(data)
  {:error, :not_found} -> handle_missing()
end
```

### ✅ Use With Statements for Sequential Operations

```elixir
# Good - Clean error propagation
def process_user_data(user_id) do
  with {:ok, user} <- fetch_user(user_id),
       {:ok, profile} <- fetch_profile(user.profile_id),
       {:ok, settings} <- fetch_settings(user.id),
       {:ok, result} <- process(user, profile, settings) do
    {:ok, result}
  else
    {:error, :user_not_found} -> {:error, "User not found"}
    {:error, :profile_not_found} -> {:error, "Profile not found"}
    {:error, reason} -> {:error, reason}
  end
end
```

### ✅ Use ErrorHandling Module for Safe Execution

```elixir
alias Raxol.Core.ErrorHandling

# Safe execution with Result type
def execute_callback(fun) do
  ErrorHandling.safe_call(fun)
  # Returns: {:ok, result} | {:error, error}
end

# Safe execution with error details and stacktrace
def execute_with_debugging(fun) do
  ErrorHandling.safe_call_with_info(fun)
  # Returns: {:ok, result} | {:error, {kind, reason, stacktrace}}
end

# Safe execution with fallback value
def compute_value(fun) do
  ErrorHandling.safe_call_with_default(fun, 0)
  # Returns: result or 0 on error
end

# Safe GenServer calls with timeout handling
def get_server_state(server) do
  ErrorHandling.safe_genserver_call(server, :get_state, 5000)
  # Returns: {:ok, result} | {:error, :not_available} | {:error, :timeout}
end

# Safe module function calls
def execute_callback(module, function, args) do
  ErrorHandling.safe_apply(module, function, args)
  # Returns: {:ok, result} | {:error, :function_not_exported}
end

# Binary operations
def load_config(binary_data) do
  ErrorHandling.safe_deserialize(binary_data)
  # Returns: {:ok, term} | {:error, reason}
end
```

## Patterns to Avoid

### ❌ Avoid Try/Catch for Control Flow

```elixir
# Bad - Using exceptions for control flow
try do
  value = risky_operation()
  process(value)
rescue
  _ -> default_value()
end

# Good - Explicit error handling
case safe_risky_operation() do
  {:ok, value} -> process(value)
  {:error, _} -> default_value()
end
```

### ❌ Avoid Silent Failures

```elixir
# Bad - Swallowing errors
try do
  operation()
rescue
  _ -> nil
end

# Good - Log and handle appropriately
case ErrorHandling.safe_call_with_logging(fn -> operation() end, "Operation failed") do
  {:ok, result} -> result
  {:error, _reason} -> nil  # Explicitly choosing nil
end
```

## Common Scenarios

### User Callbacks (Hooks, Effects, Reducers)

```elixir
# Use safe execution for user-provided functions
def execute_effect(effect_fn) do
  ErrorHandling.safe_call_with_logging(
    effect_fn,
    "Effect execution failed"
  )
end
```

### Binary Operations

```elixir
# Safe deserialization from file
def load_from_file(path) do
  ErrorHandling.safe_read_term(path)
end

# Safe serialization to file  
def save_to_file(path, data) do
  ErrorHandling.safe_write_term(path, data)
end

# Safe binary deserialization
def load_config(binary_data) do
  ErrorHandling.safe_deserialize(binary_data)
end
```

### Module Callbacks

```elixir
# Check if function exists before calling
def call_optional_callback(module, callback, args) do
  ErrorHandling.safe_callback(module, callback, args)
end

# Safe module function calls
def call_module_function(module, function, args) do
  ErrorHandling.safe_apply(module, function, args)
end
```

### GenServer Operations

```elixir
# Safe GenServer calls with timeout handling
def get_server_data(server) do
  ErrorHandling.safe_genserver_call(server, :get_data, 5000)
end

# Handle server unavailability gracefully
def update_server(server, data) do
  case ErrorHandling.safe_genserver_call(server, {:update, data}) do
    {:ok, result} -> result
    {:error, :not_available} -> {:error, "Server not available"}
    {:error, :timeout} -> {:error, "Request timed out"}
    {:error, reason} -> {:error, reason}
  end
end
```

### Arithmetic Operations

```elixir
# Handle nil values gracefully
def increment_counter(value) do
  ErrorHandling.safe_arithmetic(fn x -> x + 1 end, value, 0)
end

# Safe percentage calculations
def calculate_percentage(part, total) do
  ErrorHandling.safe_arithmetic(fn _ -> 
    if total > 0, do: (part / total) * 100, else: 0
  end, part, 0)
end
```

### Batch Operations

```elixir
# Execute multiple operations safely
def process_batch(operations) do
  ErrorHandling.safe_batch(operations)
end

# Execute operations in sequence, stop on first error
def process_sequence(operations) do
  ErrorHandling.safe_sequence(operations)
end
```

### Resource Management

```elixir
# Ensure cleanup is called
def with_database_connection(fun) do
  ErrorHandling.with_cleanup(
    fn -> 
      {:ok, conn} = Database.connect()
      {:ok, conn}
    end,
    fn conn -> Database.close(conn) end
  )
end

# Always execute cleanup regardless of outcome
def critical_operation_with_cleanup(fun) do
  ErrorHandling.ensure_cleanup(
    fn -> perform_operation() end,
    fn -> release_resources() end
  )
end
```

## Error Recovery Strategies

### 1. Default Values

```elixir
def get_config_value(key) do
  ErrorHandling.unwrap_or(fetch_config(key), default_config())
end
```

### 2. Lazy Defaults

```elixir
def get_expensive_default(key) do
  ErrorHandling.unwrap_or_else(
    fetch_value(key),
    fn -> compute_expensive_default() end
  )
end
```

### 3. Error Transformation

```elixir
def process_data(input) do
  input
  |> ErrorHandling.map(&transform/1)
  |> ErrorHandling.flat_map(&validate/1)
  |> ErrorHandling.map(&finalize/1)
end
```

## Cleanup Patterns

### Ensure Cleanup

```elixir
def with_resource(fun) do
  ErrorHandling.with_cleanup(
    fn -> acquire_resource() end,
    fn resource -> release_resource(resource) end
  )
end
```

### Always Execute Cleanup

```elixir
def critical_operation do
  ErrorHandling.ensure_cleanup(
    fn -> perform_operation() end,
    fn -> cleanup_always() end
  )
end
```

## Migration Guide

### Converting Try/Catch Blocks

#### Before:
```elixir
try do
  result = operation()
  {:ok, result}
rescue
  e -> 
    Logger.error("Failed: #{inspect(e)}")
    {:error, :failed}
end
```

#### After:
```elixir
ErrorHandling.safe_call_with_logging(
  fn -> operation() end,
  "Operation failed"
)
```

### Converting Try/Catch with Cleanup

#### Before:
```elixir
resource = nil
try do
  resource = acquire_resource()
  process_resource(resource)
after
  if resource, do: release_resource(resource)
end
```

#### After:
```elixir
ErrorHandling.with_cleanup(
  fn -> 
    resource = acquire_resource()
    {:ok, process_resource(resource)}
  end,
  fn _resource -> release_resource(resource) end
)
```

### Converting Batch Operations

#### Before:
```elixir
results = []
errors = []

for operation <- operations do
  try do
    result = operation.()
    results = [result | results]
  rescue
    error -> errors = [error | errors]
  end
end
```

#### After:
```elixir
# For collecting all results
results = ErrorHandling.safe_batch(operations)

# Or for stopping on first error
case ErrorHandling.safe_sequence(operations) do
  {:ok, results} -> process_results(results)
  {:error, reason} -> handle_error(reason)
end
```

### Converting Complex Try/Catch

#### Before:
```elixir
try do
  step1()
  step2()
  step3()
rescue
  ArgumentError -> handle_arg_error()
  RuntimeError -> handle_runtime_error()
  _ -> handle_generic_error()
end
```

#### After:
```elixir
with {:ok, _} <- ErrorHandling.safe_call(fn -> step1() end),
     {:ok, _} <- ErrorHandling.safe_call(fn -> step2() end),
     {:ok, result} <- ErrorHandling.safe_call(fn -> step3() end) do
  {:ok, result}
else
  {:error, %ArgumentError{}} -> handle_arg_error()
  {:error, %RuntimeError{}} -> handle_runtime_error()
  {:error, _} -> handle_generic_error()
end
```

## Testing Error Cases

```elixir
defmodule MyModuleTest do
  use ExUnit.Case
  
  describe "error handling" do
    test "handles missing data gracefully" do
      assert {:error, :not_found} = MyModule.fetch(999)
    end
    
    test "provides default on error" do
      result = MyModule.fetch_with_default(999, "default")
      assert result == "default"
    end
    
    test "logs errors appropriately" do
      import ExUnit.CaptureLog
      
      log = capture_log(fn ->
        MyModule.risky_operation()
      end)
      
      assert log =~ "Operation failed"
    end
  end
end
```

## Telemetry Integration

When using the ErrorHandling module, consider emitting telemetry events:

```elixir
def monitored_operation do
  case ErrorHandling.safe_call(fn -> operation() end) do
    {:ok, result} ->
      :telemetry.execute([:app, :operation, :success], %{count: 1})
      {:ok, result}
    {:error, reason} = error ->
      :telemetry.execute([:app, :operation, :failure], %{count: 1}, %{reason: reason})
      error
  end
end
```

## Summary

1. **Prefer explicit error handling** with Result types
2. **Use `with` statements** for sequential operations
3. **Leverage ErrorHandling module** for safe execution
4. **Always log errors** with appropriate context
5. **Provide sensible defaults** where appropriate
6. **Test error paths** explicitly
7. **Emit telemetry** for monitoring

By following these patterns, Raxol maintains a consistent, functional approach to error handling that is both robust and maintainable.