# `StateManager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/runtime/plugins/state_manager.ex#L1)

Plugin state management utilities with full functionality.

Provides state management for the plugin system, including initialization,
updates, persistence, and cleanup. Integrates with the unified state manager
for consistency and performance.

# `plugin_config`

```elixir
@type plugin_config() :: map()
```

# `plugin_id`

```elixir
@type plugin_id() :: String.t()
```

# `plugin_module`

```elixir
@type plugin_module() :: module()
```

# `plugin_state`

```elixir
@type plugin_state() :: term()
```

# `cleanup`

```elixir
@spec cleanup() :: :ok
```

Cleans up all plugin states.

# `get_plugin_metadata`

```elixir
@spec get_plugin_metadata(plugin_id()) :: {:ok, map()} | {:error, :not_found}
```

Gets plugin metadata.

# `get_plugin_state`

```elixir
@spec get_plugin_state(plugin_id()) :: {:ok, plugin_state()} | {:error, :not_found}
```

Gets plugin state by plugin ID.

# `initialize`

```elixir
@spec initialize(term()) :: {:ok, term()}
```

Initializes the plugin state manager subsystem.

# `initialize_plugin_state`

```elixir
@spec initialize_plugin_state(plugin_module(), plugin_config()) ::
  {:ok, plugin_state()}
```

Initializes plugin state for a given plugin module.

Creates initial state based on the plugin's configuration and stores it
in the unified state management system under the plugins namespace.

# `list_plugin_states`

```elixir
@spec list_plugin_states() :: [{plugin_id(), plugin_state()}]
```

Lists all plugin states.

# `remove_plugin`

```elixir
@spec remove_plugin(plugin_id()) :: :ok
```

Removes plugin state and metadata.

# `set_plugin_state`

```elixir
@spec set_plugin_state(plugin_id(), plugin_state()) :: :ok
```

Sets plugin state directly.

# `update_plugin_state`

```elixir
@spec update_plugin_state(plugin_id(), (plugin_state() -&gt; plugin_state())) ::
  {:ok, plugin_state()}
```

Updates plugin state using an update function.

# `update_plugin_state_legacy`

```elixir
@spec update_plugin_state_legacy(plugin_id(), plugin_state(), plugin_config()) ::
  {:ok, plugin_state()}
```

Updates plugin state using legacy interface for backward compatibility.

Maintains state in the unified state manager and supports both
functional and imperative update patterns.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
