# Error Handling Quick Reference

Fast reference for Raxol v1.1.0 functional error handling patterns.

## 🚀 Quick Start

```elixir
alias Raxol.Core.ErrorHandling, as: EH

# Basic safe operation
result = EH.safe_call(fn -> risky_operation() end)

# With pipeline
result = 
  EH.safe_call(fn -> fetch_data() end)
  |> EH.map(&process_data/1)
  |> EH.unwrap_or("default_value")
```

---

## 📋 Function Reference

### Core Functions

| Function | Usage | Returns |
|----------|-------|---------|
| `safe_call/1` | `EH.safe_call(fn -> operation() end)` | `{:ok, result} \| {:error, reason}` |
| `safe_call_with_default/2` | `EH.safe_call_with_default(fn -> op() end, default)` | `result \| default` |
| `safe_call_with_info/1` | `EH.safe_call_with_info(fn -> op() end)` | `{:ok, result} \| {:error, reason, context}` |
| `safe_call_with_logging/2` | `EH.safe_call_with_logging(fn -> op() end, "context")` | `{:ok, result} \| {:error, reason}` |

### Result Combinators

| Function | Usage | Purpose |
|----------|-------|---------|
| `map/2` | `result \|> EH.map(&transform/1)` | Transform success value |
| `flat_map/2` | `result \|> EH.flat_map(&nested_op/1)` | Chain operations |
| `unwrap_or/2` | `result \|> EH.unwrap_or(default)` | Get value or default |
| `unwrap_or_else/2` | `result \|> EH.unwrap_or_else(fn -> default end)` | Get value or compute default |

### System Operations

| Function | Usage | Purpose |
|----------|-------|---------|
| `safe_genserver_call/2` | `EH.safe_genserver_call(pid, message)` | Safe GenServer calls |
| `safe_apply/3` | `EH.safe_apply(Module, :function, [args])` | Safe module calls |
| `safe_serialize/1` | `EH.safe_serialize(term)` | Safe serialization |
| `safe_deserialize/1` | `EH.safe_deserialize(binary)` | Safe deserialization |

---

## 🏗️ Common Patterns

### 1. Simple Safe Operation

```elixir
# ❌ Unsafe
result = risky_database_call()

# ✅ Safe
case EH.safe_call(fn -> risky_database_call() end) do
  {:ok, result} -> handle_success(result)
  {:error, reason} -> handle_error(reason)
end
```

### 2. Pipeline with Fallback

```elixir
# Transform and provide fallback
user_name = 
  fetch_user_id()
  |> EH.safe_call()
  |> EH.flat_map(fn id -> EH.safe_call(fn -> fetch_user(id) end) end)
  |> EH.map(fn user -> user.name end)
  |> EH.unwrap_or("Anonymous")
```

### 3. Multiple Operations with `with`

```elixir
def process_user_registration(params) do
  with {:ok, validated} <- validate_params(params),
       {:ok, user} <- create_user(validated),
       {:ok, session} <- create_session(user),
       {:ok, _email} <- send_welcome_email(user) do
    {:ok, %{user: user, session: session}}
  else
    {:error, :validation} -> {:error, :invalid_params}
    {:error, :user_exists} -> {:error, :duplicate_user}
    {:error, reason} -> {:error, reason}
  end
end
```

### 4. Batch Processing

```elixir
# Process all, get all results
results = EH.safe_batch([
  fn -> operation_1() end,
  fn -> operation_2() end,
  fn -> operation_3() end
])

# Process sequentially, fail fast
case EH.safe_sequence([
  fn -> step_1() end,
  fn -> step_2() end,
  fn -> step_3() end
]) do
  {:ok, [result1, result2, result3]} -> process_results([result1, result2, result3])
  {:error, reason} -> handle_failure(reason)
end
```

### 5. Resource Management

```elixir
# Ensure cleanup happens
EH.with_cleanup(
  fn -> 
    file = File.open!("data.txt")
    process_file(file)
  end,
  fn file -> File.close(file) end
)

# Always run cleanup
EH.ensure_cleanup(
  fn -> risky_operation() end,
  fn -> cleanup_resources() end
)
```

---

## 🔧 Advanced Patterns

### Custom Result Types

```elixir
defmodule MyApp.Result do
  def success(value), do: {:ok, value}
  def error(reason), do: {:error, reason}
  
  def chain({:ok, value}, fun), do: fun.(value)
  def chain({:error, _} = error, _fun), do: error
  
  def map_error({:error, reason}, fun), do: {:error, fun.(reason)}
  def map_error(ok, _fun), do: ok
end

# Usage
{:ok, data}
|> MyApp.Result.chain(&validate_data/1)
|> MyApp.Result.chain(&save_data/1)
|> MyApp.Result.map_error(&format_error/1)
```

### Error Context

```elixir
defmodule MyApp.ErrorContext do
  def with_context(operation, context) do
    case EH.safe_call_with_info(operation) do
      {:ok, result} -> 
        {:ok, result}
      {:error, reason, info} -> 
        {:error, %{reason: reason, context: context, info: info}}
    end
  end
end

# Usage
MyApp.ErrorContext.with_context(
  fn -> fetch_user_data(user_id) end,
  %{user_id: user_id, operation: "fetch_profile"}
)
```

### Retry Logic

```elixir
defmodule MyApp.Retry do
  def with_retry(operation, max_retries \\ 3) do
    do_retry(operation, max_retries, 1)
  end
  
  defp do_retry(operation, max_retries, attempt) do
    case EH.safe_call(operation) do
      {:ok, result} -> 
        {:ok, result}
      {:error, reason} when attempt < max_retries ->
        :timer.sleep(attempt * 100)  # Exponential backoff
        do_retry(operation, max_retries, attempt + 1)
      {:error, reason} ->
        {:error, {:max_retries_exceeded, reason}}
    end
  end
end
```

---

## ⚡ Performance Tips

### 1. Avoid Nested Safe Calls

```elixir
# ❌ Inefficient
result = EH.safe_call(fn ->
  EH.safe_call(fn -> operation1() end)
  |> case do
    {:ok, val} -> EH.safe_call(fn -> operation2(val) end)
    error -> error
  end
end)

# ✅ Use flat_map
result = 
  EH.safe_call(fn -> operation1() end)
  |> EH.flat_map(fn val -> EH.safe_call(fn -> operation2(val) end) end)
```

### 2. Batch Similar Operations

```elixir
# ❌ Multiple individual calls
users = Enum.map(user_ids, fn id ->
  EH.safe_call(fn -> fetch_user(id) end)
end)

# ✅ Batch operation
users = EH.safe_call(fn -> fetch_users(user_ids) end)
```

### 3. Use Appropriate Defaults

```elixir
# For expensive defaults
expensive_result = 
  EH.safe_call(fn -> risky_operation() end)
  |> EH.unwrap_or_else(fn -> compute_fallback() end)

# For simple defaults  
simple_result =
  EH.safe_call(fn -> risky_operation() end)
  |> EH.unwrap_or("default")
```

---

## 🚨 Common Mistakes

### 1. Not Using Safe Functions

```elixir
# ❌ Can crash
user = Database.get_user(user_id)

# ✅ Safe
case EH.safe_call(fn -> Database.get_user(user_id) end) do
  {:ok, user} -> user
  {:error, _} -> nil
end
```

### 2. Ignoring Error Context

```elixir
# ❌ Lost context
case fetch_data() do
  {:error, _} -> "Error occurred"
end

# ✅ Preserve context
case EH.safe_call_with_info(fn -> fetch_data() end) do
  {:ok, data} -> data
  {:error, reason, context} -> 
    Logger.error("Data fetch failed", reason: reason, context: context)
    nil
end
```

### 3. Not Using Result Combinators

```elixir
# ❌ Nested case statements
case fetch_user(id) do
  {:ok, user} ->
    case validate_user(user) do
      {:ok, validated} ->
        case save_user(validated) do
          {:ok, saved} -> {:ok, saved}
          error -> error
        end
      error -> error
    end
  error -> error
end

# ✅ Pipeline with combinators
EH.safe_call(fn -> fetch_user(id) end)
|> EH.flat_map(fn user -> EH.safe_call(fn -> validate_user(user) end) end)
|> EH.flat_map(fn validated -> EH.safe_call(fn -> save_user(validated) end) end)
```

---

## 📊 Result Type Reference

```elixir
@type result(t) :: {:ok, t} | {:error, term()}

# Success cases
{:ok, value}                    # Operation succeeded
{:ok, nil}                      # Succeeded with nil result

# Error cases  
{:error, reason}                # Generic error
{:error, :not_found}           # Specific error atom
{:error, "Description"}        # Error with message
{:error, {type, details}}      # Structured error
{:error, %{code: 404, msg: ""}} # Error map
```

---

## 🔍 Debugging Tips

### Enable Detailed Logging

```elixir
# Set log level
Logger.configure(level: :debug)

# Use logging wrapper
result = EH.safe_call_with_logging(
  fn -> complex_operation() end,
  "user_profile_fetch"
)
```

### Error Pattern Analysis

```elixir
# Log error patterns
defmodule MyApp.ErrorAnalyzer do
  def analyze_error({:error, reason}) do
    case reason do
      :timeout -> Logger.warn("Timeout detected - check network")
      :not_found -> Logger.info("Resource not found - normal")
      %{status: 500} -> Logger.error("Server error - investigate")
      _ -> Logger.debug("Other error: #{inspect(reason)}")
    end
  end
end
```

---

## 📖 Quick Decision Tree

```
Operation can fail?
├─ Yes → Use EH.safe_call/1
│   ├─ Need to transform result? → Add |> EH.map/2
│   ├─ Chain more operations? → Add |> EH.flat_map/2  
│   ├─ Want fallback value? → Add |> EH.unwrap_or/2
│   └─ Multiple operations? → Use `with` statement
└─ No → Use direct call
```

---

**Version**: 1.1.0  
**Last Updated**: 2025-09-06

*See [Error Handling Guide](ERROR_HANDLING_GUIDE.md) for detailed explanations and [API Reference](API_REFERENCE.md) for complete function signatures.*