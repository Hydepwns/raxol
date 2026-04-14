# `Raxol.Terminal.Extension.ExtensionManager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/extension/extension_manager.ex#L1)

Manages terminal extensions, including loading, unloading, and executing extension commands.

# `extension`

```elixir
@type extension() :: %{
  id: String.t(),
  name: String.t(),
  version: String.t(),
  config: map(),
  commands: map(),
  events: map(),
  state: any()
}
```

# `t`

```elixir
@type t() :: %Raxol.Terminal.Extension.ExtensionManager{
  command_registry: map(),
  commands: term(),
  config: map(),
  event_handlers: map(),
  events: term(),
  extensions: map(),
  metrics: map()
}
```

# `emit_event`

Emits an event to all registered handlers.

# `emit_event`

# `execute_command`

Executes a command from an extension.

# `execute_command`

# `get_extension`

Gets an extension by ID.

# `get_metrics`

Gets current metrics.

# `list_extensions`

Lists all loaded extensions.

# `load_extension`

Loads an extension into the manager.

# `new`

Creates a new extension manager.

# `new`

# `unload_extension`

Unloads an extension from the manager.

# `update_extension_config`

Updates configuration for an extension.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
