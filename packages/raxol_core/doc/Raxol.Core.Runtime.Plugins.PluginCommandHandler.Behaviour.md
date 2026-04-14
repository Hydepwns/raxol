# `Raxol.Core.Runtime.Plugins.PluginCommandHandler.Behaviour`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/runtime/plugins/plugin_command_handler_behaviour.ex#L1)

Behavior for plugin command handling.

# `handle_command`

```elixir
@callback handle_command(command :: term(), plugin_state :: term()) ::
  {:ok, term()} | {:error, term()}
```

Handles a command for a plugin.

# `list_commands`

```elixir
@callback list_commands(plugin_state :: term()) :: [String.t()]
```

Lists available commands for a plugin.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
