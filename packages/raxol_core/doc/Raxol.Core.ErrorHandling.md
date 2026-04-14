# `Raxol.Core.ErrorHandling`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/error_handling.ex#L1)

Functional error handling patterns for Raxol.

This module provides composable error handling utilities to replace
try/catch blocks with more functional patterns. It implements Result
and Option types along with safe execution functions.

## Philosophy

Instead of using try/catch for error handling, we use:
- Result types ({:ok, value} | {:error, reason})
- Safe execution wrappers
- Pipeline-friendly error handling
- Explicit error propagation

## Examples

    # Instead of try/catch
    result = safe_call(fn -> risky_operation() end)

    # Chain operations safely
    with {:ok, data} <- fetch_data(),
         {:ok, processed} <- process_data(data),
         {:ok, result} <- save_result(processed) do
      {:ok, result}
    end

    # Safe binary operations
    safe_deserialize(binary_data)

# `error_context`

```elixir
@type error_context() :: map()
```

# `error_result`

```elixir
@type error_result() ::
  {:error, error_type(), String.t()}
  | {:error, error_type(), String.t(), error_context()}
```

# `error_severity`

```elixir
@type error_severity() :: :debug | :info | :warning | :error | :critical
```

# `error_type`

```elixir
@type error_type() ::
  :validation
  | :runtime
  | :system
  | :network
  | :permission
  | :not_found
  | :timeout
```

# `result`

```elixir
@type result(ok) :: {:ok, ok} | {:error, term()}
```

# `result`

```elixir
@type result(ok, error) :: {:ok, ok} | {:error, error}
```

# `ensure_cleanup`

```elixir
@spec ensure_cleanup((-&gt; any()), (-&gt; any())) ::
  {:ok, any()}
  | {:error,
     Exception.t() | {:exit, term()} | {:throw, term()} | {atom(), term()}}
```

Ensures cleanup is called regardless of success or failure.

# `error`

Creates a standardized error tuple.

## Examples

    error(:validation, "Invalid email format")
    error(:not_found, "User not found", %{user_id: 123})

# `execute_pipeline`

Chains multiple `{:step, name, fun}` tuples, halting on first error.

## Examples

    steps = [
      {:step, :validate, &validate/1},
      {:step, :process, &process/1}
    ]
    execute_pipeline(steps)

# `execute_with_handling`

Executes a function with error handling, retry, and telemetry.

# `flat_map`

```elixir
@spec flat_map(result(a), (a -&gt; result(b))) :: result(b) when a: any(), b: any()
```

FlatMaps over a Result type.

## Examples

    {:ok, 5}
    |> flat_map(fn x -> {:ok, x * 2} end)
    # => {:ok, 10}

# `handle_error`

Handles an error result with optional recovery.

## Examples

    result
    |> handle_error(default: "fallback")
    |> handle_error(with: fn error -> recover(error) end)

# `handle_genserver_error`

Creates a supervisor-friendly error handler for GenServer processes.

# `log_error`

Logs an error with operation context and severity.

# `map`

```elixir
@spec map(result(a), (a -&gt; b)) :: result(b) when a: any(), b: any()
```

Maps over a Result type.

## Examples

    {:ok, 5}
    |> map(fn x -> x * 2 end)
    # => {:ok, 10}

# `normalize_error`

Converts various error formats to a standardized `{:error, type, message, context}` tuple.

# `safe_apply`

```elixir
@spec safe_apply(module(), atom(), list()) :: {:ok, any()} | {:error, atom()}
```

Safely calls a module function if it's exported.

## Examples

    safe_apply(MyModule, :init, [])

# `safe_arithmetic`

```elixir
@spec safe_arithmetic((number() -&gt; number()), any(), number()) :: number()
```

Safely performs arithmetic with a fallback for nil values.

## Examples

    safe_arithmetic(fn x -> x + 10 end, nil, 0)
    # => 10 (uses fallback 0, then adds 10)

# `safe_batch`

```elixir
@spec safe_batch([(-&gt; any())]) :: [result(any())]
```

Safely executes multiple operations, collecting all results.

## Examples

    safe_batch([
      fn -> operation1() end,
      fn -> operation2() end,
      fn -> operation3() end
    ])
    # => [{:ok, result1}, {:error, error2}, {:ok, result3}]

# `safe_call`

```elixir
@spec safe_call((-&gt; any())) ::
  {:ok, any()}
  | {:error,
     Exception.t() | {:exit, term()} | {:throw, term()} | {atom(), term()}}
```

Safely executes a function and returns a Result type.

## Examples

    iex> safe_call(fn -> 1 + 1 end)
    {:ok, 2}

    iex> safe_call(fn -> raise "oops" end)
    {:error, %RuntimeError{message: "oops"}}

# `safe_call_with_default`

```elixir
@spec safe_call_with_default((-&gt; any()), any()) :: any()
```

Safely executes a function with a fallback value on error.

## Examples

    iex> safe_call_with_default(fn -> raise "oops" end, 42)
    42

# `safe_call_with_info`

```elixir
@spec safe_call_with_info((-&gt; any())) ::
  {:ok, any()} | {:error, {atom(), any(), list()}}
```

Safely executes a function and returns error details with stacktrace for re-raising.

## Examples

    iex> safe_call_with_info(fn -> 42 end)
    {:ok, 42}

    iex> safe_call_with_info(fn -> raise "oops" end)
    {:error, {:error, %RuntimeError{message: "oops"}, [...]}}

# `safe_call_with_logging`

```elixir
@spec safe_call_with_logging((-&gt; any()), String.t()) :: result(any())
```

Safely executes a function with error logging.

## Examples

    safe_call_with_logging(fn -> process() end, "Processing failed")

# `safe_callback`

```elixir
@spec safe_callback(module(), atom(), list()) ::
  {:ok, any()}
  | {:error,
     Exception.t() | {:exit, term()} | {:throw, term()} | {atom(), term()}}
```

Safely calls an optional callback on a module.
Returns {:ok, nil} if the callback doesn't exist.

# `safe_deserialize`

```elixir
@spec safe_deserialize(binary()) :: {:ok, term()} | {:error, :invalid_binary}
```

Safely deserializes Erlang terms from binary data.

## Examples

    iex> binary = :erlang.term_to_binary({:ok, "data"})
    iex> safe_deserialize(binary)
    {:ok, {:ok, "data"}}

    iex> safe_deserialize("invalid")
    {:error, :invalid_binary}

# `safe_genserver_call`

```elixir
@spec safe_genserver_call(GenServer.server(), any(), timeout()) :: result(any())
```

Safely makes a GenServer call with proper error handling.

## Examples

    safe_genserver_call(MyServer, :get_state)

# `safe_read_term`

```elixir
@spec safe_read_term(Path.t()) :: {:ok, term()} | {:error, atom()}
```

Safely reads and deserializes a file.

## Examples

    safe_read_term("/path/to/file")

# `safe_sequence`

```elixir
@spec safe_sequence([(-&gt; any())]) :: result([any()])
```

Executes operations until one fails.

# `safe_serialize`

```elixir
@spec safe_serialize(term()) :: result(binary())
```

Safely serializes a term to binary.

# `safe_write_term`

```elixir
@spec safe_write_term(Path.t(), term()) :: result(:ok)
```

Safely writes a term to a file.

# `unwrap_or`

```elixir
@spec unwrap_or(result(a), a) :: a when a: any()
```

Unwraps a Result or returns a default value.

## Examples

    unwrap_or({:ok, 42}, 0)     # => 42
    unwrap_or({:error, _}, 0)   # => 0

# `unwrap_or_else`

```elixir
@spec unwrap_or_else(result(a), (-&gt; a)) :: a when a: any()
```

Unwraps a Result or calls a function to get default.

## Examples

    unwrap_or_else({:error, :not_found}, fn -> fetch_default() end)

# `with_cleanup`

```elixir
@spec with_cleanup((-&gt; result(a)), (a -&gt; any())) :: result(a) when a: any()
```

Ensures a cleanup function is called even if the main function fails.

## Examples

    with_cleanup(
      fn -> open_resource() end,
      fn resource -> close_resource(resource) end
    )

# `with_error_handling`
*macro* 

Wraps a block with error handling, logging, and optional retry.

## Options

- `:context` - Additional context map to log with errors
- `:severity` - Error severity level (default: :error)
- `:fallback` - Fallback value on error
- `:retry` - Number of retry attempts (default: 0)
- `:retry_delay` - Delay between retries in ms (default: 1000)

## Examples

    import Raxol.Core.ErrorHandling

    with_error_handling(:database_query, context: %{user_id: 123}) do
      Repo.get!(User, user_id)
    end

---

*Consult [api-reference.md](api-reference.md) for complete listing*
