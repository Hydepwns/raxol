# `Raxol.Terminal.Sync.SyncServer`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/sync/sync_server.ex#L1)

Unified synchronization system for the Raxol terminal emulator.
This module provides centralized synchronization mechanisms for:
- State synchronization between windows
- Event synchronization
- Resource synchronization

# `sync_config`

```elixir
@type sync_config() :: %{
  consistency: :strong | :eventual,
  conflict_resolution: :last_write_wins | :version_based | :custom,
  timeout: non_neg_integer(),
  retry_count: non_neg_integer()
}
```

# `sync_id`

```elixir
@type sync_id() :: term()
```

# `sync_state`

```elixir
@type sync_state() :: %{
  id: sync_id(),
  type: :state | :event | :resource,
  data: term(),
  version: non_neg_integer(),
  timestamp: integer(),
  metadata: map()
}
```

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `cleanup`

Cleans up a synchronization context.

## Parameters
  * `sync_id` - The synchronization context ID

# `create_sync`

Creates a new synchronization context.

## Parameters
  * `type` - Type of synchronization (:state, :event, or :resource)
  * `opts` - Creation options
    * `:consistency` - Consistency level
    * `:conflict_resolution` - Conflict resolution strategy
    * `:timeout` - Synchronization timeout
    * `:retry_count` - Number of retry attempts

# `get_sync_state`

Gets the current state of a synchronization context.

## Parameters
  * `sync_id` - The synchronization context ID

# `handle_manager_cast`

# `handle_manager_info`

# `resolve_conflicts`

Resolves conflicts between synchronized data.

## Parameters
  * `sync_id` - The synchronization context ID
  * `conflicts` - List of conflicting versions
  * `opts` - Resolution options
    * `:strategy` - Override the default conflict resolution strategy

# `start_link`

# `sync`

Synchronizes data between windows.

## Parameters
  * `sync_id` - The synchronization context ID
  * `data` - The data to synchronize
  * `opts` - Synchronization options
    * `:version` - Current version of the data
    * `:metadata` - Additional metadata

---

*Consult [api-reference.md](api-reference.md) for complete listing*
