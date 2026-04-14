# `Raxol.Core.Runtime.Plugins.Lifecycle`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/runtime/plugins/lifecycle.ex#L1)

Defines the behaviour for plugin lifecycle management.

Plugins that implement this behaviour will have their lifecycle events
called during plugin loading and unloading.

# `start`

```elixir
@callback start(config :: map()) :: {:ok, map()} | {:error, any()}
```

Called when the plugin is started after initialization.

Should return `{:ok, updated_config}` or `{:error, reason}`.
The `updated_config` will be stored in the plugin's configuration.

# `stop`

```elixir
@callback stop(config :: map()) :: {:ok, map()} | {:error, any()}
```

Called when the plugin is stopped before cleanup.

Should return `{:ok, updated_config}` or `{:error, reason}`.
The `updated_config` will be stored in the plugin's configuration.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
