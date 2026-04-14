# `Raxol.Core.Config.ConfigServer`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/config/config_server.ex#L1)

Backward-compatible configuration server.

This module maintains the original API but delegates to the pure functional
`Raxol.Core.Config` module and ETS-backed `Raxol.Core.Config.Store`.

## Migration Note

This module is retained for backward compatibility. New code should use:
- `Raxol.Core.Config` for pure functional operations on config data
- `Raxol.Core.Config.Store` for runtime config access with ETS backing

## Architecture Change

Previous: All operations serialized through GenServer mailbox
Current: Reads go directly to ETS, writes coordinate through GenServer

This change improves:
- Read performance (no mailbox serialization)
- Concurrent access (ETS read_concurrency)
- Code clarity (pure functions separated from process management)

# `config_key`

```elixir
@type config_key() :: Raxol.Core.Config.key()
```

# `config_namespace`

```elixir
@type config_namespace() :: Raxol.Core.Config.namespace()
```

# `config_value`

```elixir
@type config_value() :: Raxol.Core.Config.value()
```

# `child_spec`

# `get`

```elixir
@spec get(GenServer.server(), config_namespace(), config_key(), any()) :: any()
```

Gets configuration value from specified namespace and key.

This is now a direct ETS read - fast and concurrent.

# `get_namespace`

```elixir
@spec get_namespace(GenServer.server(), config_namespace()) :: map()
```

Gets entire namespace configuration.

Direct ETS read - fast and concurrent.

# `load_from_file`

```elixir
@spec load_from_file(GenServer.server()) :: :ok | {:error, any()}
```

Loads configuration from file system.

# `reset_namespace`

```elixir
@spec reset_namespace(GenServer.server(), config_namespace()) :: :ok
```

Resets namespace to default configuration.

# `save_to_file`

```elixir
@spec save_to_file(GenServer.server()) :: :ok | {:error, any()}
```

Saves configuration to file system.

# `set`

```elixir
@spec set(
  GenServer.server(),
  config_namespace(),
  config_key(),
  config_value()
) :: :ok | {:error, any()}
```

Sets configuration value in specified namespace and key.

# `set_namespace`

```elixir
@spec set_namespace(GenServer.server(), config_namespace(), map()) :: :ok
```

Sets entire namespace configuration.

# `start_link`

Starts the configuration store.

Kept for backward compatibility - delegates to Config.Store.

# `validate`

```elixir
@spec validate(GenServer.server(), config_namespace()) :: :ok | {:error, [String.t()]}
```

Validates configuration for specified namespace.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
