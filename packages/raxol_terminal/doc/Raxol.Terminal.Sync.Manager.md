# `Raxol.Terminal.Sync.Manager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/sync/sync_manager.ex#L1)

Manages synchronization between different terminal components (splits, windows, tabs).
Provides a high-level interface for component synchronization and state management.

# `component_id`

```elixir
@type component_id() :: String.t()
```

# `component_type`

```elixir
@type component_type() :: :split | :window | :tab
```

# `sync_state`

```elixir
@type sync_state() :: %{
  component_id: component_id(),
  component_type: component_type(),
  state: term(),
  metadata: %{
    version: non_neg_integer(),
    timestamp: non_neg_integer(),
    source: String.t()
  }
}
```

# `t`

```elixir
@type t() :: %Raxol.Terminal.Sync.Manager{
  components: %{required(String.t()) =&gt; Raxol.Terminal.Sync.Component.t()},
  sync_id: String.t()
}
```

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `do_sync_state`

# `generate_sync_id`

# `get_component_stats`

# `get_state`

# `handle_manager_cast`

# `handle_manager_info`

# `register_component`

Starts the sync manager.

# `start_link`

# `sync_state`

```elixir
@spec sync_state(String.t(), term()) :: :ok
```

Syncs a component's state with default options.

# `sync_state`

```elixir
@spec sync_state(String.t(), String.t(), term(), keyword()) :: :ok
```

Syncs a component's state.

# `unregister_component`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
