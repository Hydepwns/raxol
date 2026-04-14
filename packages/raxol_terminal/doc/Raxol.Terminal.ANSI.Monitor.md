# `Raxol.Terminal.ANSI.Monitor`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/ansi/monitor.ex#L1)

Provides monitoring capabilities for the ANSI handling system.
Tracks performance metrics, errors, and sequence statistics.

# `metrics`

```elixir
@type metrics() :: %{
  total_sequences: non_neg_integer(),
  total_bytes: non_neg_integer(),
  sequence_types: %{required(atom()) =&gt; non_neg_integer()},
  errors: [{DateTime.t(), String.t(), map()}],
  performance: %{
    parse_time_ms: float(),
    process_time_ms: float(),
    total_time_ms: float()
  }
}
```

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `get_metrics`

```elixir
@spec get_metrics() :: metrics()
```

Gets the current metrics.

# `handle_manager_info`

# `record_error`

```elixir
@spec record_error(String.t(), String.t(), map()) :: :ok
```

Records an error in ANSI sequence processing.

# `record_sequence`

```elixir
@spec record_sequence(String.t()) :: :ok
```

Records the processing of an ANSI sequence.

# `reset_metrics`

```elixir
@spec reset_metrics() :: :ok
```

Resets the metrics.

# `start_link`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
