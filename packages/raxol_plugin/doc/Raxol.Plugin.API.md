# `Raxol.Plugin.API`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/plugin/api.ex#L1)

Public API facade for plugin management operations.

Delegates to `Raxol.Core.Runtime.Plugins.PluginManager` with
graceful error handling when the manager process is not running.

## Usage

    Raxol.Plugin.API.load(MyPlugin, %{option: "value"})
    Raxol.Plugin.API.enable(:my_plugin)
    Raxol.Plugin.API.list()

# `plugin_id`

```elixir
@type plugin_id() :: atom() | String.t()
```

# `disable`

```elixir
@spec disable(plugin_id()) :: :ok | {:error, term()}
```

Disables a plugin without unloading it.

# `enable`

```elixir
@spec enable(plugin_id()) :: :ok | {:error, term()}
```

Enables a loaded plugin.

# `get`

```elixir
@spec get(plugin_id()) :: map() | nil | {:error, term()}
```

Gets a plugin entry by ID.

# `get_state`

```elixir
@spec get_state(plugin_id()) :: term() | {:error, term()}
```

Gets the runtime state of a plugin.

# `list`

```elixir
@spec list() :: [map()] | {:error, term()}
```

Lists all registered plugins.

# `load`

```elixir
@spec load(module(), map()) :: :ok | {:error, term()}
```

Loads a plugin module with optional configuration.

# `loaded?`

```elixir
@spec loaded?(plugin_id()) :: boolean() | {:error, term()}
```

Checks whether a plugin is currently loaded.

# `reload`

```elixir
@spec reload(plugin_id()) :: :ok | {:error, term()}
```

Reloads a plugin (unload + load).

# `unload`

```elixir
@spec unload(plugin_id()) :: :ok | {:error, term()}
```

Unloads a plugin by ID.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
