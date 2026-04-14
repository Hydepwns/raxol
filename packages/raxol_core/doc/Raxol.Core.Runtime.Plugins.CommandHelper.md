# `Raxol.Core.Runtime.Plugins.CommandHelper`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/runtime/plugins/command_helper.ex#L1)

Handles plugin command registration and dispatch for the Plugin Manager.

# `find_plugin_for_command`

```elixir
@spec find_plugin_for_command(
  map(),
  atom() | String.t(),
  module() | nil,
  non_neg_integer()
) :: {:ok, {module(), atom(), non_neg_integer()}} | :not_found
```

Finds a command handler in the command table, normalizing the command name.

# `find_plugin_id_by_module`

```elixir
@spec find_plugin_id_by_module(map(), module()) :: String.t() | nil
```

Finds the plugin ID for a given module in the plugins map.

# `handle_command`

```elixir
@spec handle_command(map(), String.t(), module() | nil, list() | nil, map()) ::
  {:ok, map()} | {:error, atom()} | {:error, atom(), map()}
```

Dispatches a command, looking it up in the table and executing the handler.

# `register_plugin_commands`

```elixir
@spec register_plugin_commands(module(), map(), map()) :: map()
```

Registers commands from a plugin module's `get_commands/0` callback.
Returns the updated command table.

# `unregister_plugin_commands`

```elixir
@spec unregister_plugin_commands(map(), module()) :: map()
```

Removes all commands for a module from the command table.

# `validate_command_args`

```elixir
@spec validate_command_args(term()) :: :ok | {:error, :invalid_args}
```

Validates that command arguments are a list of strings or numbers.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
