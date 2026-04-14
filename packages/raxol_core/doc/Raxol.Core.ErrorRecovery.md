# `Raxol.Core.ErrorRecovery`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/error_recovery.ex#L1)

Error recovery strategies for the Raxol application.

Provides various recovery mechanisms for different types of errors,
including circuit breakers, fallback mechanisms, and graceful degradation.

REFACTORED: All try/catch/rescue blocks replaced with functional patterns.

## Features

- Circuit breaker pattern for external services
- Fallback strategies
- Graceful degradation
- Resource cleanup on errors
- State recovery mechanisms

# `circuit_state`

```elixir
@type circuit_state() :: :closed | :open | :half_open
```

# `recovery_strategy`

```elixir
@type recovery_strategy() ::
  :retry | :fallback | :circuit_breaker | :degrade | :cleanup
```

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `circuit_breaker_init`

Initializes a circuit breaker with optional configuration.

# `circuit_breaker_reset`

Resets a circuit breaker to its initial state.

# `circuit_breaker_state`

Gets the current state of a circuit breaker.

# `degrade_gracefully`

Implements graceful degradation for feature availability.

This is now a regular function instead of a macro to avoid try/rescue.

## Examples

    degrade_gracefully(:advanced_search,
      fn -> AdvancedSearch.execute(query) end,
      fn -> BasicSearch.execute(query) end
    )

# `feature_available?`

# `handle_manager_cast`

# `handle_manager_info`

# `mark_feature_degraded`

# `start_link`

# `with_bulkhead`

Implements bulkhead pattern to isolate failures.

# `with_circuit_breaker`

Executes a function with circuit breaker protection.

## Examples

    with_circuit_breaker(:external_api, fn ->
      ExternalAPI.call()
    end)

# `with_cleanup`

Ensures cleanup is performed even on error.

## Examples

    with_cleanup fn ->
      resource = acquire_resource()
      process(resource)
    end, fn resource ->
      release_resource(resource)
    end

# `with_fallback`

Provides fallback mechanism for failed operations.

## Examples

    with_fallback fn ->
      fetch_from_primary()
    end, fn ->
      fetch_from_cache()
    end

# `with_retry`

Implements exponential backoff retry strategy.

## Options

- `:max_retries` - Maximum number of retry attempts (default: 3)
- `:base_delay` - Base delay in milliseconds (default: 100)
- `:max_delay` - Maximum delay in milliseconds (default: 5000)
- `:jitter` - Add randomness to delays (default: true)

---

*Consult [api-reference.md](api-reference.md) for complete listing*
