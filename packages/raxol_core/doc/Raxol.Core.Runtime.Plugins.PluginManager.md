# `Raxol.Core.Runtime.Plugins.PluginManager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/runtime/plugins/plugin_manager.ex#L1)

Facade for plugin management operations.

This module provides a unified API that delegates to specialized modules:
- `PluginRegistry` - Fast ETS-backed lookups (no process serialization)
- `PluginLifecycle` - GenServer for coordination (load, enable, state)

## Architecture

Following Rich Hickey's principle of separating data from coordination:

```
PluginManager (Facade)
     |
     +-- PluginRegistry (Pure + ETS)
     |   - Plugin registration
     |   - Metadata storage
     |   - Command lookups
     |   - Fast concurrent reads
     |
     +-- PluginLifecycle (GenServer)
         - Load/unload coordination
         - Enable/disable state
         - Runtime plugin state
         - File watching/hot reload
```

## Migration Note

This module maintains backward compatibility with the old API.
New code should use:
- `PluginRegistry` for lookups (faster, no process call)
- `PluginLifecycle` for lifecycle operations

## Usage

    # Load a plugin
    PluginManager.load_plugin_by_module(MyPlugin, %{config: "value"})

    # List plugins (fast ETS lookup)
    PluginManager.list_plugins()

    # Enable/disable
    PluginManager.enable_plugin(:my_plugin)
    PluginManager.disable_plugin(:my_plugin)

# `plugin_id`

```elixir
@type plugin_id() :: atom() | String.t()
```

# `plugin_metadata`

```elixir
@type plugin_metadata() :: map()
```

# `plugin_state`

```elixir
@type plugin_state() :: map()
```

# `call_hook`

Calls a hook on a plugin.

# `call_hook`

Calls a hook on a plugin (legacy signature with pid).

# `child_spec`

# `disable_plugin`

Disables a plugin.

# `enable_plugin`

Enables a plugin.

# `get_loaded_plugins`

Gets list of loaded plugin IDs.

# `get_loaded_plugins`

Gets list of loaded plugin IDs (legacy signature with pid).

# `get_plugin`

Gets a plugin by ID.

Fast ETS lookup.

# `get_plugin_config`

Gets plugin configuration.

# `get_plugin_config`

Gets plugin configuration (legacy signature with pid).

# `get_plugin_state`

Gets the runtime state of a plugin.

# `initialize`

Initializes the plugin manager.

# `initialize_plugin`

Initializes a specific plugin.

# `initialize_plugin`

Initializes a specific plugin (legacy signature with pid).

# `initialize_with_config`

Initializes with configuration.

# `list_plugins`

Lists all registered plugins.

This is a fast ETS lookup - no GenServer call required.

# `load_plugin`

Loads a plugin by ID.

# `load_plugin`

Loads a plugin with config (legacy signature).

# `load_plugin_by_module`

Loads a plugin by module with optional configuration.

# `plugin_loaded?`

Checks if a plugin is loaded.

# `plugin_loaded?`

Checks if a plugin is loaded (legacy signature with pid).

# `reload_plugin`

Reloads a plugin.

# `set_plugin_state`

Sets the runtime state of a plugin.

# `start_link`

Starts the plugin management system.

Initializes both the registry and lifecycle manager.

# `unload_plugin`

Unloads a plugin.

# `unload_plugin`

Unloads a plugin (legacy signature with pid).

# `update_plugin`

Updates a plugin entry using a function.

# `update_plugin_config`

Updates plugin configuration.

# `update_plugin_config`

Updates plugin configuration (legacy signature with pid).

# `validate_plugin_config`

Validates plugin configuration.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
