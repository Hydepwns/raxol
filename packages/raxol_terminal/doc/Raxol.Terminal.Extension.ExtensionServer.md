# `Raxol.Terminal.Extension.ExtensionServer`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/extension/extension_server.ex#L1)

Unified extension management GenServer that provides a single interface for loading,
unloading, and managing terminal extensions.

# `activate_extension`

```elixir
@spec activate_extension(String.t()) :: :ok | {:error, term()}
```

Activates an extension.

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `configure_extension`

```elixir
@spec configure_extension(String.t(), map()) :: :ok | {:error, term()}
```

Configures an extension.

# `deactivate_extension`

```elixir
@spec deactivate_extension(String.t()) :: :ok | {:error, term()}
```

Deactivates an extension.

# `execute_command`

Executes a command for an extension.

# `execute_command`

```elixir
@spec execute_command(String.t(), String.t(), list()) ::
  {:ok, term()} | {:error, term()}
```

# `export_extension`

```elixir
@spec export_extension(String.t(), String.t()) :: :ok | {:error, term()}
```

Exports an extension to a specified path.

# `get_extension_config`

```elixir
@spec get_extension_config(String.t()) ::
  {:ok, map()} | {:error, :extension_not_found}
```

Gets the configuration of an extension.

# `get_extension_hooks`

```elixir
@spec get_extension_hooks(String.t()) ::
  {:ok, [atom()]} | {:error, :extension_not_found}
```

Gets all hooks for an extension.

# `get_extension_state`

```elixir
@spec get_extension_state(String.t()) :: {:ok, map()} | {:error, :extension_not_found}
```

Gets the state of a specific extension.

# `get_extensions`

```elixir
@spec get_extensions(keyword()) :: {:ok, [map()]}
```

Gets all extensions, optionally filtered.

# `handle_manager_cast`

# `handle_manager_info`

# `import_extension`

```elixir
@spec import_extension(String.t()) :: {:ok, String.t()} | {:error, term()}
```

Imports an extension from a specified path.

# `list_extensions`

```elixir
@spec list_extensions(keyword()) :: {:ok, [map()]}
```

Lists all loaded extensions with optional filters.

# `load_extension`

```elixir
@spec load_extension(String.t(), atom(), map() | keyword()) ::
  {:ok, String.t()} | {:error, term()}
```

Loads an extension from the specified path.

# `register_hook`

```elixir
@spec register_hook(String.t(), atom(), function()) :: :ok | {:error, term()}
```

Registers a hook for an extension.

# `start_extension_manager`

```elixir
@spec start_extension_manager(keyword()) :: GenServer.on_start()
```

Starts the UnifiedExtension server.

# `start_link`

# `trigger_hook`

```elixir
@spec trigger_hook(String.t(), atom(), list()) :: {:ok, term()} | {:error, term()}
```

Triggers a hook for an extension.

# `unload_extension`

```elixir
@spec unload_extension(String.t()) :: :ok | {:error, term()}
```

Unloads an extension by ID.

# `unregister_hook`

```elixir
@spec unregister_hook(String.t(), atom()) :: :ok | {:error, term()}
```

Unregisters a hook for an extension.

# `update_extension_config`

```elixir
@spec update_extension_config(String.t(), map()) :: :ok | {:error, term()}
```

Updates the configuration for an extension.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
