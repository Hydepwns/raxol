# `Raxol.Core.Runtime.Plugins.PluginCommandManager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/runtime/plugins/plugin_command_manager.ex#L1)

Manages plugin command registration and dispatch.
Coordinates between plugins and the command system.

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `dispatch_command`

```elixir
@spec dispatch_command(atom(), list()) :: {:ok, term()} | {:error, term()}
```

Dispatch a command to the appropriate plugin.

# `get_commands`

```elixir
@spec get_commands() :: map()
```

Get all registered commands.

# `get_plugin_commands`

```elixir
@spec get_plugin_commands(atom()) :: list()
```

Get commands for a specific plugin.

# `handle_manager_cast`

# `handle_manager_info`

# `initialize_command_table`

```elixir
@spec initialize_command_table(map(), map() | list()) :: map()
```

Initialize command table with initial plugins.

# `register_commands`

```elixir
@spec register_commands(atom(), list(), map()) :: :ok | {:error, term()}
```

Register commands for a plugin.

# `start_link`

# `unregister_commands`

```elixir
@spec unregister_commands(atom()) :: :ok
```

Unregister all commands for a plugin.

# `update_command_table`

```elixir
@spec update_command_table(map(), map()) :: map()
```

Update command table with plugin commands.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
