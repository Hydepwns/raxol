# `Raxol.Sensor.Fusion`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/sensor/fusion.ex#L1)

Batches sensor readings and produces fused state.

Receives `{:sensor_reading, reading}` messages from Feed processes,
accumulates them in a batch, and on a configurable timer flushes
the batch through a pure fusion function. Subscribers receive
`{:fused_update, fused_state}` on each flush.

# `t`

```elixir
@type t() :: %Raxol.Sensor.Fusion{
  batch: [Raxol.Sensor.Reading.t()],
  batch_ref: reference() | nil,
  batch_window_ms: pos_integer(),
  feeds: %{required(atom()) =&gt; pid()},
  fused_state: map(),
  subscribers: MapSet.t(pid()),
  thresholds: map()
}
```

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `get_fused_state`

```elixir
@spec get_fused_state(GenServer.server()) :: map()
```

# `register_feed`

```elixir
@spec register_feed(GenServer.server(), atom(), pid()) :: :ok
```

# `start_link`

```elixir
@spec start_link(keyword()) :: GenServer.on_start()
```

# `subscribe`

```elixir
@spec subscribe(GenServer.server()) :: :ok
```

# `unregister_feed`

```elixir
@spec unregister_feed(GenServer.server(), atom()) :: :ok
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
