# `Raxol.Core.Behaviours.Lifecycle`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/behaviours/lifecycle.ex#L1)

Common behavior for lifecycle management across different components.

This behavior defines a consistent interface for components that have
initialization, start, stop, and cleanup phases.

# `opts`

```elixir
@type opts() :: keyword()
```

# `reason`

```elixir
@type reason() :: term()
```

# `state`

```elixir
@type state() :: any()
```

# `health_check`
*optional* 

```elixir
@callback health_check(state()) :: :ok | {:error, reason()}
```

Checks if the component is healthy and running.

# `init`

```elixir
@callback init(opts()) :: {:ok, state()} | {:error, reason()}
```

Initializes the component with the given options.

# `restart`
*optional* 

```elixir
@callback restart(state(), opts()) :: {:ok, state()} | {:error, reason()}
```

Restarts the component. Default implementation stops then starts.

# `start`

```elixir
@callback start(state(), opts()) :: {:ok, state()} | {:error, reason()}
```

Starts the component. Called after successful initialization.

# `stop`

```elixir
@callback stop(state(), reason()) :: {:ok, state()} | {:error, reason()}
```

Stops the component gracefully.

# `terminate`

```elixir
@callback terminate(state(), reason()) :: :ok
```

Cleans up resources. Always called during shutdown.

# `__using__`
*macro* 

Default implementations for optional callbacks.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
