# `Raxol.Sensor.Feed`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/sensor/feed.ex#L1)

GenServer managing a single sensor's polling lifecycle.

Connects to a sensor module, polls at the configured sample rate,
buffers readings in a CircularBuffer, and forwards each reading
to the fusion process.

# `status`

```elixir
@type status() :: :connecting | :running | :error | :stopped
```

# `t`

```elixir
@type t() :: %Raxol.Sensor.Feed{
  backoff_ref: reference() | nil,
  buffer: CircularBuffer.t(),
  buffer_size: pos_integer(),
  connect_opts: keyword(),
  error_count: non_neg_integer(),
  fusion_pid: pid() | nil,
  max_errors: pos_integer(),
  module: module(),
  poll_ref: reference() | nil,
  sample_rate_ms: pos_integer(),
  sensor_id: atom(),
  sensor_state: term(),
  status: status()
}
```

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `get_history`

```elixir
@spec get_history(GenServer.server(), pos_integer()) :: [map()]
```

# `get_latest`

```elixir
@spec get_latest(GenServer.server()) :: {:ok, map()} | {:error, :empty}
```

# `get_status`

```elixir
@spec get_status(GenServer.server()) :: status()
```

# `reconnect`

```elixir
@spec reconnect(GenServer.server()) :: :ok
```

# `start_link`

```elixir
@spec start_link(keyword()) :: GenServer.on_start()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
