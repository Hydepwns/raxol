# `Raxol.Sensor.Supervisor`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/sensor/supervisor.ex#L1)

Supervisor for the sensor fusion subsystem.

Start order (rest_for_one):
1. Registry -- name lookup for feeds
2. DynamicSupervisor -- hosts Feed processes
3. Fusion -- batches readings from all feeds

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `start_feed`

```elixir
@spec start_feed(
  keyword(),
  GenServer.server()
) :: DynamicSupervisor.on_start_child()
```

# `start_link`

```elixir
@spec start_link(keyword()) :: Supervisor.on_start()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
