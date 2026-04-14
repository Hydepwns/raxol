# `Raxol.Core.Runtime.Plugins.Loader`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/runtime/plugins/loader.ex#L1)

Manages plugin loading operations.

# `t`

```elixir
@type t() :: %Raxol.Core.Runtime.Plugins.Loader{
  loaded_plugins: map(),
  plugin_configs: map(),
  plugin_metadata: map()
}
```

# `behaviour_implemented?`

Checks if a module implements the given behaviour.

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `discover_plugins`

Discovers plugins in the given directories.
Returns a list of discovered plugin paths.

# `extract_metadata`

# `get_loaded_plugins`

Gets the list of loaded plugins.

# `handle_manager_cast`

# `handle_manager_info`

# `initialize_plugin`

# `load_code`

Loads code for a plugin by its ID.

# `load_plugin`

Loads a plugin from the given path.

# `plugin_loaded?`

Checks if a plugin is loaded.

# `reload_plugin`

Reloads a plugin.

# `start_link`

# `unload_plugin`

Unloads a plugin.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
