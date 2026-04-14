# `Raxol.Core.Runtime.Plugins.LoaderBehaviour`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/runtime/plugins/loader_behaviour.ex#L1)

Behavior for plugin loading functionality.

# `list_available_plugins`

```elixir
@callback list_available_plugins(opts :: keyword()) :: [String.t()]
```

Lists available plugins.

# `load_plugin`

```elixir
@callback load_plugin(plugin_spec :: term(), opts :: keyword()) ::
  {:ok, term()} | {:error, term()}
```

Loads a plugin from a given path or configuration.

# `unload_plugin`

```elixir
@callback unload_plugin(plugin_id :: String.t()) :: :ok | {:error, term()}
```

Unloads a plugin.

# `validate_plugin`

```elixir
@callback validate_plugin(plugin_spec :: term()) :: :ok | {:error, term()}
```

Validates a plugin before loading.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
