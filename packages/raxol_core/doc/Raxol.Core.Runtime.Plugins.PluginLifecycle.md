# `Raxol.Core.Runtime.Plugins.PluginLifecycle`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/runtime/plugins/plugin_lifecycle.ex#L1)

GenServer for plugin lifecycle coordination.

Handles stateful plugin operations that require coordination:
- Loading and unloading plugins
- Enabling and disabling plugins
- Managing plugin runtime state
- File watching for hot reload
- Timer-based operations

## Design

This module is the "coordination layer" - it's a GenServer because it needs to:
- Coordinate concurrent plugin operations
- Manage timers for debounced reloads
- Track per-plugin runtime state

Read-only operations should use `PluginRegistry` directly for better performance.

## Usage

    # Start lifecycle manager
    {:ok, _pid} = PluginLifecycle.start_link([])

    # Load a plugin
    PluginLifecycle.load(:my_plugin, MyPlugin, %{config: "value"})

    # Enable/disable
    PluginLifecycle.enable(:my_plugin)
    PluginLifecycle.disable(:my_plugin)

    # Get runtime state
    PluginLifecycle.get_state(:my_plugin)

# `plugin_id`

```elixir
@type plugin_id() :: atom() | String.t()
```

# `plugin_state`

```elixir
@type plugin_state() :: term()
```

# `plugin_status`

```elixir
@type plugin_status() :: :loaded | :enabled | :disabled | :error
```

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `disable`

```elixir
@spec disable(plugin_id()) :: :ok | {:error, term()}
```

Disables a plugin without unloading it.

# `disable_file_watching`

```elixir
@spec disable_file_watching() :: :ok
```

Disables file watching.

# `enable`

```elixir
@spec enable(plugin_id()) :: :ok | {:error, term()}
```

Enables a loaded plugin.

# `enable_file_watching`

```elixir
@spec enable_file_watching([String.t()]) :: :ok
```

Enables file watching for plugin hot reload.

# `get_config`

```elixir
@spec get_config(plugin_id()) :: map()
```

Gets the configuration of a plugin.

# `get_state`

```elixir
@spec get_state(plugin_id()) :: {:ok, plugin_state()} | {:error, :not_found}
```

Gets the runtime state of a plugin.

# `get_status`

```elixir
@spec get_status(plugin_id()) :: plugin_status() | nil
```

Gets the status of a plugin.

# `list_with_status`

```elixir
@spec list_with_status() :: [{plugin_id(), plugin_status()}]
```

Lists all plugins with their status.

# `load`

```elixir
@spec load(plugin_id(), module(), map()) :: :ok | {:error, term()}
```

Loads a plugin module with optional configuration.

Registers in PluginRegistry and initializes lifecycle state.

# `reload`

```elixir
@spec reload(plugin_id()) :: :ok | {:error, term()}
```

Reloads a plugin (unload + load).

# `schedule_reload`

```elixir
@spec schedule_reload(plugin_id(), non_neg_integer()) :: :ok
```

Schedules a debounced reload for a plugin.

Useful for file-watching scenarios where multiple changes
should trigger only one reload.

# `set_state`

```elixir
@spec set_state(plugin_id(), plugin_state()) :: :ok | {:error, :not_found}
```

Updates the runtime state of a plugin.

# `start_link`

# `unload`

```elixir
@spec unload(plugin_id()) :: :ok | {:error, term()}
```

Unloads a plugin, cleaning up state and unregistering.

# `update_config`

```elixir
@spec update_config(plugin_id(), map()) :: :ok
```

Updates plugin configuration.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
