# `Raxol.Core.Behaviours.BaseRegistry`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/behaviours/base_registry.ex#L1)

Base behavior for registry GenServers to reduce code duplication.
Provides common patterns for registering, unregistering, and looking up resources.

# `init_registry`

```elixir
@callback init_registry(keyword()) :: {:ok, any()} | {:error, any()}
```

Called to initialize the registry state.

# `on_register`
*optional* 

```elixir
@callback on_register(any(), any(), any()) :: any()
```

Called when a resource is registered.

# `on_unregister`
*optional* 

```elixir
@callback on_unregister(any(), any()) :: any()
```

Called when a resource is unregistered.

# `validate_resource`
*optional* 

```elixir
@callback validate_resource(any(), any()) :: :ok | {:error, any()}
```

Called to validate a resource before registration.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
