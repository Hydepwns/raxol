# `Raxol.Core.Runtime.Plugins.PluginRegistry`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/runtime/plugins/plugin_registry.ex#L1)

Pure functional plugin registry backed by ETS for fast concurrent lookups.

Separates plugin registration/discovery from lifecycle management.
All read operations are direct ETS lookups - no process serialization.

## Design

Following Rich Hickey's principle of separating data from coordination:
- Registry is data (what plugins exist, their metadata)
- Lifecycle is coordination (loading, enabling, state management)

## Usage

    # Initialize registry (usually in application start)
    PluginRegistry.init()

    # Register a plugin
    PluginRegistry.register(:my_plugin, MyPlugin, %{version: "1.0"})

    # Fast lookups (direct ETS, no GenServer)
    PluginRegistry.get(:my_plugin)
    PluginRegistry.list()
    PluginRegistry.find_by_command(:help)

    # Check if registered
    PluginRegistry.registered?(:my_plugin)

# `metadata`

```elixir
@type metadata() :: map()
```

# `plugin_entry`

```elixir
@type plugin_entry() :: %{
  id: plugin_id(),
  module: plugin_module(),
  metadata: metadata(),
  registered_at: DateTime.t()
}
```

# `plugin_id`

```elixir
@type plugin_id() :: atom() | String.t()
```

# `plugin_module`

```elixir
@type plugin_module() :: module()
```

# `count`

```elixir
@spec count() :: non_neg_integer()
```

Returns the count of registered plugins.

# `filter`

```elixir
@spec filter((plugin_entry() -&gt; boolean())) :: [plugin_entry()]
```

Filters plugins by metadata criteria.

## Examples

    # Find all plugins with version "1.0"
    PluginRegistry.filter(fn entry ->
      entry.metadata[:version] == "1.0"
    end)

# `find_by_command`

```elixir
@spec find_by_command(atom()) :: [plugin_id()]
```

Finds plugins that provide a specific command.

## Examples

    PluginRegistry.find_by_command(:help)
    # => [:help_plugin, :docs_plugin]

# `find_by_metadata`

```elixir
@spec find_by_metadata(atom(), term()) :: [plugin_entry()]
```

Finds plugins by metadata key-value match.

## Examples

    PluginRegistry.find_by_metadata(:category, :ui)

# `get`

```elixir
@spec get(plugin_id()) :: {:ok, plugin_entry()} | :error
```

Gets a plugin entry by ID. Direct ETS lookup.

## Examples

    case PluginRegistry.get(:clipboard) do
      {:ok, entry} -> entry.module
      :error -> nil
    end

# `get_commands`

```elixir
@spec get_commands(plugin_id()) :: [atom()]
```

Gets all commands provided by a plugin.

# `get_module`

```elixir
@spec get_module(plugin_id()) :: module() | nil
```

Gets a plugin module by ID.

# `init`

```elixir
@spec init() :: :ok
```

Initializes the plugin registry ETS tables.

Call this once during application startup.

# `initialized?`

```elixir
@spec initialized?() :: boolean()
```

Checks if the registry has been initialized.

# `list`

```elixir
@spec list(keyword()) :: [plugin_entry()] | [plugin_id()]
```

Lists all registered plugins.

## Options

  * `:ids_only` - Return only plugin IDs (default: false)

# `list_commands`

```elixir
@spec list_commands() :: [{atom(), plugin_id()}]
```

Lists all registered commands with their provider plugins.

# `register`

```elixir
@spec register(plugin_id(), plugin_module(), metadata()) ::
  :ok | {:error, :already_registered}
```

Registers a plugin in the registry.

## Examples

    PluginRegistry.register(:clipboard, Raxol.Plugins.Clipboard, %{
      version: "1.0.0",
      description: "Clipboard integration"
    })

# `registered?`

```elixir
@spec registered?(plugin_id()) :: boolean()
```

Checks if a plugin is registered.

# `unregister`

```elixir
@spec unregister(plugin_id()) :: :ok
```

Unregisters a plugin from the registry.

# `update_metadata`

```elixir
@spec update_metadata(plugin_id(), metadata()) :: :ok | {:error, :not_found}
```

Updates a plugin's metadata.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
