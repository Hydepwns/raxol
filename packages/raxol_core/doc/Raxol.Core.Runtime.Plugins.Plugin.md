# `Raxol.Core.Runtime.Plugins.Plugin`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/runtime/plugins/plugin.ex#L1)

Defines the behaviour for Raxol plugins.

Plugins must implement this behaviour to be loaded and managed by the plugin manager.

# `command`

```elixir
@type command() :: atom() | tuple()
```

# `config`

```elixir
@type config() :: map()
```

# `event`

```elixir
@type event() :: term()
```

# `state`

```elixir
@type state() :: map()
```

# `disable`

```elixir
@callback disable(state :: state()) :: {:ok, state()} | {:error, any()}
```

Called when the plugin is disabled.

Should return `{:ok, new_state}` or `{:error, reason}`.

# `enable`

```elixir
@callback enable(state :: state()) :: {:ok, state()} | {:error, any()}
```

Called when the plugin is enabled after being disabled.

Should return `{:ok, new_state}` or `{:error, reason}`.

# `filter_event`

```elixir
@callback filter_event(event :: event(), state :: state()) ::
  {:ok, event()} | :halt | any()
```

Optional callback to filter or react to system events before they reach the application.

Return `{:ok, event}` to pass the event through (potentially modified).
Return `:halt` to stop the event from propagating further.
Return any other value to indicate an error.

# `get_commands`

```elixir
@callback get_commands() :: [{atom(), atom(), non_neg_integer()}]
```

Optional callback to declare commands provided by the plugin.

This callback allows plugins to register their commands with the command registry.
Each command is specified as a tuple containing:
- The command name as an atom
- The function to handle the command
- The arity of the handler function

## Returns

  * List of command specifications in the format `[{name_atom, function_atom, arity_integer}]`

## Examples

    def get_commands do
      [
        {:do_something, :handle_do_something_command, 2},
        {:process_data, :handle_process_data_command, 1}
      ]
    end

## Notes

  * The command name will be converted to a string when registered
  * The plugin module itself will be used as the namespace
  * Commands will be registered in the CommandRegistry via CommandHelper

# `handle_command`

```elixir
@callback handle_command(
  command :: command(),
  args :: list(),
  state :: state()
) :: {:ok, state(), any()} | {:error, any(), state()}
```

Optional callback to handle commands delegated by the plugin manager.

Should return `{:ok, new_state, result}` or `{:error, reason, new_state}`.
The `result` can be sent back to the original command requester if needed.

# `init`

```elixir
@callback init(config :: config()) :: {:ok, state()} | {:error, any()}
```

Called when the plugin is first initialized.

Should return `{:ok, initial_state}` or `{:error, reason}`.
The `initial_state` will be managed by the plugin manager.

# `terminate`

```elixir
@callback terminate(reason :: any(), state :: state()) :: any()
```

Called when the plugin is terminated (e.g., during shutdown or unload).

Allows the plugin to perform cleanup. The return value is ignored.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
