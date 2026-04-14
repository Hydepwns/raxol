# `Raxol.Core.GlobalRegistry.RegistryBehaviour`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/global_registry.ex#L35)

Behaviour for unified registry operations.

# `entry_data`

```elixir
@type entry_data() :: any()
```

# `entry_id`

```elixir
@type entry_id() :: String.t() | atom()
```

# `registry_type`

```elixir
@type registry_type() :: :sessions | :plugins | :commands | :themes | :components
```

# `count`

```elixir
@callback count(registry_type()) :: non_neg_integer()
```

# `list`

```elixir
@callback list(registry_type()) :: [entry_data()]
```

# `lookup`

```elixir
@callback lookup(registry_type(), entry_id()) ::
  {:ok, entry_data()} | {:error, :not_found}
```

# `register`

```elixir
@callback register(registry_type(), entry_id(), entry_data()) :: :ok | {:error, term()}
```

# `search`

```elixir
@callback search(registry_type(), String.t()) :: [entry_data()]
```

# `unregister`

```elixir
@callback unregister(registry_type(), entry_id()) :: :ok | {:error, term()}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
