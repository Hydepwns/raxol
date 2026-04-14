# `Raxol.Sensor.HUD`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/sensor/hud.ex#L1)

Pure functional HUD rendering for sensor data.

All functions take a region `{x, y, w, h}`, data, and options,
and return a list of `{x, y, char, fg, bg, attrs}` cell tuples.

# `cell`

```elixir
@type cell() ::
  {non_neg_integer(), non_neg_integer(), String.t(), atom(), atom(), map()}
```

# `region`

```elixir
@type region() :: {non_neg_integer(), non_neg_integer(), pos_integer(), pos_integer()}
```

# `render_gauge`

```elixir
@spec render_gauge(region(), number(), keyword()) :: [cell()]
```

Renders a horizontal gauge bar.

Options:
- `label` -- prefix label (default: "")
- `min` -- minimum value (default: 0.0)
- `max` -- maximum value (default: 100.0)
- `thresholds` -- `{warn, crit}` percentages (default: `{0.6, 0.85}`)

# `render_minimap`

```elixir
@spec render_minimap(region(), [map()], keyword()) :: [cell()]
```

Renders a minimap using braille dot patterns.

Entities: `[%{x: 0.0..1.0, y: 0.0..1.0, char: "x"}]`
Maps normalized coordinates into a braille grid (2 dots wide x 4 dots tall per character).

Options:
- `border` -- draw border (default: true)

# `render_sparkline`

```elixir
@spec render_sparkline(region(), [number()], keyword()) :: [cell()]
```

Renders a sparkline from a list of numeric values.

Options:
- `label` -- prefix label (default: "")
- `min` -- explicit minimum (default: auto from data)
- `max` -- explicit maximum (default: auto from data)

# `render_threat`

```elixir
@spec render_threat(region(), atom(), number(), keyword()) :: [cell()]
```

Renders a threat indicator with level and bearing.

Options:
- `label` -- prefix (default: "THREAT")

Levels: `:none`, `:low`, `:medium`, `:high`, `:critical`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
