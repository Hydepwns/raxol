# `Raxol.Core.Config.Store`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/core/config/config_store.ex#L1)

ETS-backed configuration store for fast concurrent reads.

This module provides the runtime storage layer for configuration.
It uses ETS for fast concurrent reads (no process serialization)
and a minimal GenServer only for initialization and file persistence.

## Design

- ETS for all reads: No mailbox serialization, multiple readers can access concurrently
- GenServer only for: Initialization, file I/O, auto-save timer
- Pure functions from `Raxol.Core.Config` for all data transformations

## Usage

    # Start the store (usually in supervision tree)
    {:ok, _pid} = Config.Store.start_link([])

    # Read (fast ETS lookup, no process call)
    width = Config.Store.get(:terminal, :width)
    terminal = Config.Store.get_namespace(:terminal)

    # Write (goes through GenServer for consistency)
    Config.Store.put(:terminal, :width, 120)

    # File operations
    Config.Store.load_from_file()
    Config.Store.save_to_file()

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `get`

```elixir
@spec get(
  Raxol.Core.Config.namespace(),
  Raxol.Core.Config.key(),
  Raxol.Core.Config.value()
) ::
  Raxol.Core.Config.value()
```

Gets a config value. This is a direct ETS read - no process serialization.

## Examples

    Config.Store.get(:terminal, :width)
    Config.Store.get(:terminal, :missing, 0)

# `get_all`

```elixir
@spec get_all() :: Raxol.Core.Config.t()
```

Gets the entire config. Direct ETS read.

# `get_namespace`

```elixir
@spec get_namespace(Raxol.Core.Config.namespace()) :: map()
```

Gets an entire namespace. Direct ETS read.

## Examples

    Config.Store.get_namespace(:terminal)

# `load_from_file`

```elixir
@spec load_from_file() :: :ok | {:error, any()}
```

Loads config from file, merging with current config.

# `put`

```elixir
@spec put(
  Raxol.Core.Config.namespace(),
  Raxol.Core.Config.key(),
  Raxol.Core.Config.value()
) ::
  :ok | {:error, String.t()}
```

Sets a config value.

## Examples

    Config.Store.put(:terminal, :width, 120)

# `put_namespace`

```elixir
@spec put_namespace(Raxol.Core.Config.namespace(), map()) :: :ok
```

Sets an entire namespace.

## Examples

    Config.Store.put_namespace(:terminal, %{width: 120, height: 40})

# `reset_namespace`

```elixir
@spec reset_namespace(Raxol.Core.Config.namespace()) :: :ok
```

Resets a namespace to default values.

# `save_to_file`

```elixir
@spec save_to_file() :: :ok | {:error, any()}
```

Saves current config to file.

# `start_link`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
