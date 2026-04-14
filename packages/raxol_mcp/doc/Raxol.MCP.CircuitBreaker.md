# `Raxol.MCP.CircuitBreaker`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/mcp/circuit_breaker.ex#L1)

Lightweight ETS-backed circuit breaker for MCP tool/resource callbacks.

Tracks failure counts per key and transitions through three states:

- **closed** -- normal operation, failures below threshold
- **open** -- callback blocked after repeated failures, returns `{:error, :circuit_open}`
- **half_open** -- recovery probe allowed after cooldown; success resets, failure re-opens

No GenServer -- all state lives in a public ETS table with atomic counter
updates. The table is created by the owning process (typically `MCP.Registry`).

## Configuration

Defaults can be overridden via application env or per-call opts:

    config :raxol_mcp, :circuit_breaker,
      failure_threshold: 5,
      recovery_ms: 30_000

# `key`

```elixir
@type key() :: {:tool, String.t()} | {:resource, String.t()} | {:prompt, String.t()}
```

# `state`

```elixir
@type state() :: :closed | :open | :half_open
```

# `check`

```elixir
@spec check(:ets.tid(), key(), keyword()) :: state()
```

Check the circuit state for a key.

Returns `:closed` (proceed), `:open` (block), or `:half_open` (probe).
Automatically transitions from open to half_open after the recovery period.

# `new`

```elixir
@spec new(atom()) :: :ets.tid()
```

Create a new circuit breaker ETS table.

# `record_failure`

```elixir
@spec record_failure(:ets.tid(), key(), keyword()) :: :ok
```

Record a failed callback invocation.

Increments the failure counter. Transitions to open when the threshold is reached.
In half_open state, a single failure re-opens the circuit.

# `record_success`

```elixir
@spec record_success(:ets.tid(), key()) :: :ok
```

Record a successful callback invocation. Resets the circuit to closed.

# `reset`

```elixir
@spec reset(:ets.tid(), key()) :: :ok
```

Manually reset a circuit to closed.

# `reset_all`

```elixir
@spec reset_all(:ets.tid()) :: :ok
```

Reset all circuit breaker state.

# `status`

```elixir
@spec status(:ets.tid(), key()) :: %{state: state(), failures: non_neg_integer()}
```

Get the current status of a circuit.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
