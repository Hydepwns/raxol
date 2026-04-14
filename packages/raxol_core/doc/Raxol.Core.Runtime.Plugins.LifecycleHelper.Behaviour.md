# `Raxol.Core.Runtime.Plugins.LifecycleHelper.Behaviour`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/runtime/plugins/lifecycle_helper_behaviour.ex#L1)

Behavior for plugin lifecycle management.

# `init_lifecycle`

```elixir
@callback init_lifecycle(plugin_id :: String.t(), opts :: keyword()) ::
  {:ok, term()} | {:error, term()}
```

Initializes a plugin's lifecycle.

# `start_lifecycle`

```elixir
@callback start_lifecycle(plugin_id :: String.t(), state :: term()) ::
  {:ok, term()} | {:error, term()}
```

Starts a plugin's lifecycle.

# `stop_lifecycle`

```elixir
@callback stop_lifecycle(plugin_id :: String.t(), state :: term()) ::
  {:ok, term()} | {:error, term()}
```

Stops a plugin's lifecycle.

# `terminate_lifecycle`

```elixir
@callback terminate_lifecycle(plugin_id :: String.t(), state :: term()) :: :ok
```

Terminates a plugin's lifecycle.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
