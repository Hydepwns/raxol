# `Raxol.Sensor.Reading`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/sensor/behaviour.ex#L1)

A timestamped sensor reading with quality indicator.

# `t`

```elixir
@type t() :: %Raxol.Sensor.Reading{
  metadata: map(),
  quality: float(),
  sensor_id: atom(),
  timestamp: integer(),
  values: map()
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
