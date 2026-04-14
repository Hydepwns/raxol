# `Raxol.Sensor.Behaviour`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/sensor/behaviour.ex#L22)

Behaviour for sensor implementations.

Sensors produce readings at a configurable sample rate. Each reading
contains timestamped values with a quality indicator.

# `connect`

```elixir
@callback connect(opts :: keyword()) :: {:ok, term()} | {:error, term()}
```

# `disconnect`

```elixir
@callback disconnect(state :: term()) :: :ok
```

# `read`

```elixir
@callback read(state :: term()) ::
  {:ok, Raxol.Sensor.Reading.t(), term()} | {:error, term()}
```

# `sample_rate`
*optional* 

```elixir
@callback sample_rate() :: pos_integer()
```

Sample rate in milliseconds. Defaults to 100ms.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
