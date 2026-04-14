# `Raxol.Sensor.MockSensor`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/sensor/mock_sensor.ex#L1)

Configurable test/demo sensor.

Options:
- `sensor_id` -- atom identifier (default: `:mock`)
- `sample_rate` -- poll interval in ms (default: 100)
- `generator_fn` -- `(tick :: integer()) -> map()` producing values
- `fail_after` -- fail read after N ticks (for error testing)

# `t`

```elixir
@type t() :: %Raxol.Sensor.MockSensor{
  fail_after: non_neg_integer() | nil,
  generator_fn: (integer() -&gt; map()),
  sample_rate: pos_integer(),
  sensor_id: atom(),
  tick: non_neg_integer()
}
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
