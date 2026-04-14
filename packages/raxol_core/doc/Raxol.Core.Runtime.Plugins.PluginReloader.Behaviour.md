# `Raxol.Core.Runtime.Plugins.PluginReloader.Behaviour`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/runtime/plugins/plugin_reloader_behaviour.ex#L1)

Behaviour for plugin reloading operations.

# `reload_plugin`

```elixir
@callback reload_plugin(plugin_id :: term(), state :: term()) ::
  {:ok, term()} | {:error, term(), term()}
```

Reloads a plugin.

# `reload_plugin_by_id`

```elixir
@callback reload_plugin_by_id(plugin_id_string :: String.t(), state :: term()) ::
  {:ok, term()} | {:error, term(), term()}
```

Reloads a plugin by ID.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
