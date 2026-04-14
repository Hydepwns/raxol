# `Raxol.Terminal.Plugin.PluginServer`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/plugin/plugin_server.ex#L1)

Unified plugin system for the Raxol terminal emulator.
Handles themes, scripting, and extensions.

Refactored version with pure functional error handling patterns.
All try/catch blocks have been replaced with with statements and proper error tuples.

# `plugin_id`

```elixir
@type plugin_id() :: String.t()
```

# `plugin_state`

```elixir
@type plugin_state() :: %{
  id: plugin_id(),
  type: plugin_type(),
  name: String.t(),
  version: String.t(),
  description: String.t(),
  author: String.t(),
  dependencies: [String.t()],
  config: map(),
  status: :active | :inactive | :error,
  error: String.t() | nil
}
```

# `plugin_type`

```elixir
@type plugin_type() :: :theme | :script | :extension
```

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `execute_plugin_function`

Executes a plugin function.

# `get_plugin_state`

Gets the state of a plugin.

# `get_plugins`

Gets all loaded plugins.

# `handle_manager_cast`

# `handle_manager_info`

# `load_plugin`

Loads a plugin from a file or directory.

# `reload_plugin`

Reloads a plugin.

# `start_link`

# `unload_plugin`

Unloads a plugin by ID.

# `update_plugin_config`

Updates a plugin's configuration.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
