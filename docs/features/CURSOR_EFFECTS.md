# Cursor Effects

Visual cursor trails and glow effects.

## Usage

```elixir
alias Raxol.Effects.CursorTrail

trail = CursorTrail.new()
trail = CursorTrail.update(trail, {10, 5})
trail = CursorTrail.update(trail, {11, 5})
buffer = CursorTrail.apply(trail, buffer)
```

## Configuration

```elixir
trail = CursorTrail.new(%{
  max_length: 20,
  decay_rate: 0.15,
  colors: [:cyan, :blue],
  chars: ["*", "+", "."],
  min_opacity: 0.1
})
```

## Presets

```elixir
trail = CursorTrail.rainbow()  # Rainbow colors, 24 points
trail = CursorTrail.minimal()  # Simple white dots, 5 points
trail = CursorTrail.comet()    # Long fading tail, 30 points
```

## Operations

```elixir
# Update with position
trail = CursorTrail.update(trail, {x, y})

# Clear trail
trail = CursorTrail.clear(trail)

# Enable/disable
trail = CursorTrail.set_enabled(trail, false)

# Update config
trail = CursorTrail.update_config(trail, %{colors: [:red]})

# Statistics
stats = CursorTrail.stats(trail)
```

## Advanced

```elixir
# Smooth interpolation
trail = CursorTrail.interpolate(trail, {5, 10}, {15, 10})

# Multi-cursor
positions = [{10, 5}, {20, 10}, {30, 15}]
trail = CursorTrail.multi_cursor(positions)

# Glow effect
buffer = CursorTrail.apply_glow(buffer, {x, y}, :cyan)
```

## Integration

```elixir
def render(state, cursor) do
  trail = CursorTrail.update(state.trail, cursor)
  buffer = CursorTrail.apply(trail, state.buffer)
  %{state | trail: trail, buffer: buffer}
end
```

Performance: ~7μs per update + apply
