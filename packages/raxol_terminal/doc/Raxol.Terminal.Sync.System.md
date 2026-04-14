# `Raxol.Terminal.Sync.System`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/sync/system.ex#L1)

Unified synchronization system for the terminal emulator.
Handles synchronization between splits, windows, and tabs with different consistency levels.

# `sync_entry`

```elixir
@type sync_entry() :: %{
  key: sync_key(),
  value: sync_value(),
  metadata: sync_metadata()
}
```

# `sync_id`

```elixir
@type sync_id() :: String.t()
```

# `sync_key`

```elixir
@type sync_key() :: String.t()
```

# `sync_metadata`

```elixir
@type sync_metadata() :: %{
  version: non_neg_integer(),
  timestamp: non_neg_integer(),
  source: String.t(),
  consistency: :strong | :eventual | :causal
}
```

# `sync_stats`

```elixir
@type sync_stats() :: %{
  sync_count: non_neg_integer(),
  conflict_count: non_neg_integer(),
  last_sync: non_neg_integer(),
  consistency_levels: %{required(atom()) =&gt; non_neg_integer()}
}
```

# `sync_value`

```elixir
@type sync_value() :: term()
```

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `clear`

# `delete`

# `get`

# `get_all`

# `handle_manager_cast`

# `handle_manager_info`

# `monotonic_time`

```elixir
@spec monotonic_time(:millisecond | :microsecond | :nanosecond) :: integer()
```

Gets the current monotonic time in the specified unit.

# `start_link`

# `stats`

# `sync`

# `system_time`

```elixir
@spec system_time(:millisecond | :microsecond | :nanosecond) :: integer()
```

Gets the current system time in the specified unit.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
