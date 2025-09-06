# Error Handling Quick Reference

Fast reference for Raxol v1.1.0 functional error handling.

## Functions

```elixir
alias Raxol.Core.ErrorHandling, as: EH

# Core functions
EH.safe_call(fn -> operation() end)           # {:ok, result} | {:error, reason}
EH.safe_call_with_default(fn -> op() end, x) # result | x  
EH.safe_genserver_call(pid, msg)             # Safe GenServer calls
EH.safe_apply(Mod, :func, [args])            # Safe module calls

# Combinators
result |> EH.map(&transform/1)               # Transform success
result |> EH.flat_map(&chain_op/1)           # Chain operations  
result |> EH.unwrap_or(default)              # Extract or default
result |> EH.unwrap_or_else(fn -> x end)     # Extract or compute
```

## Patterns

**Simple Operation**
```elixir
case EH.safe_call(fn -> fetch_user(id) end) do
  {:ok, user} -> user
  {:error, _} -> nil
end
```

**Pipeline**
```elixir
fetch_user_id()
|> EH.safe_call()  
|> EH.flat_map(fn id -> EH.safe_call(fn -> fetch_user(id) end) end)
|> EH.map(fn user -> user.name end)
|> EH.unwrap_or("Anonymous")
```

**Multi-step with `with`**
```elixir
with {:ok, data} <- validate(input),
     {:ok, result} <- process(data) do
  {:ok, result}
else
  {:error, reason} -> {:error, reason}
end
```

**Batch Processing**
```elixir
# All results
EH.safe_batch([fn -> op1() end, fn -> op2() end])

# Fail fast
EH.safe_sequence([fn -> step1() end, fn -> step2() end])
```

## Result Types

```elixir
{:ok, value}           # Success
{:error, reason}       # Generic error  
{:error, :not_found}   # Specific error
{:error, "message"}    # Error with description
```

## Anti-Patterns

- Nested `safe_call` - use `flat_map`
- Ignoring error context
- Not using combinators for pipelines

---

*See [Error Handling Guide](ERROR_HANDLING_GUIDE.md) for details.*