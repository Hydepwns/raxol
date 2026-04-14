# `Raxol.Core.GlobalRegistry`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/global_registry.ex#L1)

Unified registry interface consolidating different registry patterns across Raxol.

This module provides a single interface for:
- Terminal session registry
- Plugin registry
- Component registry
- Theme/palette registry
- Command registry

## Usage

### Terminal Sessions
    UnifiedRegistry.register(:sessions, session_id, session_data)
    sessions = UnifiedRegistry.list(:sessions)

### Plugins
    UnifiedRegistry.register(:plugins, plugin_id, plugin_metadata)
    plugins = UnifiedRegistry.list(:plugins)

### Commands
    UnifiedRegistry.register(:commands, command_name, command_handler)
    commands = UnifiedRegistry.search(:commands, pattern)

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

# `bulk_register`

Bulk operations for efficiency.

# `bulk_unregister`

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `count`

Counts entries in the specified registry.

# `filter`

Filters entries by a custom function.

# `handle_manager_cast`

# `handle_manager_info`

# `list`

Lists all entries in the specified registry.

# `list_commands`

# `list_plugins`

# `list_sessions`

# `lookup`

Looks up an entry in the specified registry.

# `lookup_command`

# `lookup_plugin`

# `lookup_session`

# `register`

Registers an entry in the specified registry.

# `register_command`

Command registry operations.

# `register_plugin`

Plugin registry operations.

# `register_session`

Session registry operations.

# `search`

Searches for entries matching a pattern in the specified registry.

# `search_commands`

# `start_link`

# `stats`

Gets registry statistics.

# `unregister`

Unregisters an entry from the specified registry.

# `unregister_command`

# `unregister_plugin`

# `unregister_session`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
