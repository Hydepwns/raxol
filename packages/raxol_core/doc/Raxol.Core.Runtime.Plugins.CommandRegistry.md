# `Raxol.Core.Runtime.Plugins.CommandRegistry`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/runtime/plugins/command_registry.ex#L1)

Manages command registration and execution for plugins.

Commands are stored in a plain map keyed by namespace (module) with lists of
`{name, {module, function, arity}, metadata}` tuples as values.

# `command_entry`

```elixir
@type command_entry() ::
  {command_name(), {module(), atom(), non_neg_integer()}, command_metadata()}
```

# `command_handler`

```elixir
@type command_handler() :: (list(), map() -&gt; term())
```

# `command_metadata`

```elixir
@type command_metadata() :: %{
  optional(:description) =&gt; String.t(),
  optional(:usage) =&gt; String.t(),
  optional(:aliases) =&gt; [String.t()],
  optional(:timeout) =&gt; pos_integer()
}
```

# `command_name`

```elixir
@type command_name() :: String.t()
```

# `command_table`

```elixir
@type command_table() :: %{optional(module()) =&gt; [command_entry()]}
```

# `execute_command`

```elixir
@spec execute_command(String.t(), list(), command_table()) ::
  term() | {:error, term()}
```

Finds and executes a command by name with timeout support.

# `find_command`

```elixir
@spec find_command(String.t(), command_table()) ::
  {:ok, {term(), command_metadata()}} | {:error, :not_found}
```

Searches all namespaces for a command by name.

# `lookup_command`

```elixir
@spec lookup_command(command_table() | term(), module(), String.t()) ::
  {:ok, {module(), command_handler(), non_neg_integer()}}
  | {:error, :not_found | :invalid_table}
```

Looks up a command by namespace and name. Returns a handler function
wrapping `apply(module, function, ...)`.

# `new`

```elixir
@spec new() :: atom()
```

Returns the default table name atom for ETS-backed registries.

# `register_command`

```elixir
@spec register_command(
  command_table() | term(),
  module(),
  String.t(),
  module(),
  atom(),
  non_neg_integer()
) :: command_table() | {:error, :invalid_table}
```

Registers a command under a namespace in the command table.

Returns the updated table map, or `{:error, :invalid_table}` if
`table` is not a map.

# `register_plugin_commands`

```elixir
@spec register_plugin_commands(module(), map(), command_table()) ::
  {:ok, command_table()} | {:error, term()}
```

Registers commands from a plugin module's `commands/0` callback.

Validates handlers and metadata, checks for name conflicts against
existing commands in the table.

# `unregister_command`

```elixir
@spec unregister_command(command_table() | term(), module(), String.t()) ::
  command_table() | term()
```

Removes a single command from a namespace. Returns the updated table,
or the input unchanged if `table` is not a map.

# `unregister_commands_by_module`

```elixir
@spec unregister_commands_by_module(command_table() | term(), module()) ::
  command_table() | term()
```

Removes all commands for a module from the table.

# `unregister_plugin_commands`

```elixir
@spec unregister_plugin_commands(module(), command_table()) ::
  {:ok, command_table()} | :ok
```

Unregisters all commands for a plugin module.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
