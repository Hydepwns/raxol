# `Raxol.Sensor.HUDOverlay`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/sensor/hud_overlay.ex#L1)

Glue layer: subscribes to Fusion updates, renders HUD widgets,
writes cells to a buffer.

# `layout_entry`

```elixir
@type layout_entry() :: %{
  widget: :gauge | :sparkline | :threat | :minimap,
  region: Raxol.Sensor.HUD.region(),
  sensor_id: atom(),
  opts: keyword()
}
```

# `t`

```elixir
@type t() :: %Raxol.Sensor.HUDOverlay{
  buffer_pid: pid() | nil,
  fusion_pid: pid() | nil,
  last_fused_state: map(),
  layout: [layout_entry()]
}
```

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `start_link`

```elixir
@spec start_link(keyword()) :: GenServer.on_start()
```

---

*Consult [api-reference.md](api-reference.md) for complete listing*
