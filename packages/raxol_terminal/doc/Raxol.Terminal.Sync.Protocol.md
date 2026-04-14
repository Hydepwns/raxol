# `Raxol.Terminal.Sync.Protocol`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/sync/protocol.ex#L1)

Defines the synchronization protocol for terminal components.
Handles message formats, versioning, and conflict resolution strategies.

# `sync_message`

```elixir
@type sync_message() :: %{
  type: :sync | :ack | :conflict | :resolve,
  component_id: String.t(),
  component_type: :split | :window | :tab,
  state: term(),
  metadata: %{
    version: non_neg_integer(),
    timestamp: non_neg_integer(),
    source: String.t(),
    consistency: :strong | :eventual | :causal
  }
}
```

# `sync_result`

```elixir
@type sync_result() :: :ok | {:error, :conflict | :version_mismatch | :invalid_state}
```

# `create_ack_message`

# `create_conflict_message`

# `create_resolve_message`

# `create_sync_message`

# `handle_ack_message`

# `handle_conflict_message`

# `handle_resolve_message`

# `handle_sync_message`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
