# `Raxol.Terminal.ScreenBuffer.Manager`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/terminal/screen_buffer/manager.ex#L1)

Manages buffer lifecycle, memory tracking, damage regions, and buffer switching.
Consolidates: Manager, UnifiedManager, SafeManager, EnhancedManager, DamageTracker.

# `t`

```elixir
@type t() :: %Raxol.Terminal.ScreenBuffer.Manager{
  active_buffer_type: :main | :alternate,
  alternate_buffer: Raxol.Terminal.ScreenBuffer.Core.t(),
  main_buffer: Raxol.Terminal.ScreenBuffer.Core.t(),
  memory_limit: non_neg_integer(),
  memory_usage: non_neg_integer(),
  metrics: map()
}
```

# `add_damage`

```elixir
@spec add_damage(
  t(),
  non_neg_integer(),
  non_neg_integer(),
  non_neg_integer(),
  non_neg_integer()
) :: t()
```

Adds a damage region to the active buffer.

# `clear`

```elixir
@spec clear(t()) :: t()
```

Clears the active buffer.

# `clear_damage`

```elixir
@spec clear_damage(t()) :: t()
```

Clears damage regions (stub).

# `clear_damage_regions`

```elixir
@spec clear_damage_regions(t()) :: t()
```

Clears all damage regions from the active buffer.

# `constrain_position`

```elixir
@spec constrain_position(t(), integer(), integer()) :: {integer(), integer()}
```

Constrains a position to buffer bounds (stub).

# `get_active_buffer`

```elixir
@spec get_active_buffer(t()) :: Raxol.Terminal.ScreenBuffer.Core.t()
```

Gets the currently active buffer.

# `get_damage_regions`

```elixir
@spec get_damage_regions(t()) :: [tuple()]
```

Gets all damage regions from the active buffer.

# `get_memory_stats`

```elixir
@spec get_memory_stats(t()) :: map()
```

Gets memory usage statistics.

# `get_memory_usage`

```elixir
@spec get_memory_usage(t()) :: non_neg_integer()
```

Gets current memory usage in bytes.

# `get_metrics`

```elixir
@spec get_metrics(t()) :: map()
```

Gets all metrics.

# `get_position`

```elixir
@spec get_position(t()) :: {integer(), integer()}
```

Gets current cursor position (stub).

# `get_total_lines`

```elixir
@spec get_total_lines(t()) :: non_neg_integer()
```

Gets total lines in buffer including scrollback (stub).

# `get_visible_content`

```elixir
@spec get_visible_content(t()) :: String.t()
```

Gets visible content as string (stub).

# `get_visible_lines`

```elixir
@spec get_visible_lines(t()) :: non_neg_integer()
```

Gets visible lines count (stub).

# `initialize_buffers`

```elixir
@spec initialize_buffers(
  non_neg_integer(),
  non_neg_integer(),
  non_neg_integer()
) :: t()
```

Initializes buffers (stub for test compatibility).

# `mark_all_damaged`

```elixir
@spec mark_all_damaged(t()) :: t()
```

Marks the entire buffer as damaged.

# `move_to`

```elixir
@spec move_to(t(), integer(), integer()) :: t()
```

Moves cursor to position (stub).

# `new`

```elixir
@spec new(non_neg_integer(), non_neg_integer(), keyword()) :: t()
```

Creates a new buffer manager with main and alternate buffers.

# `read`

```elixir
@spec read(
  t(),
  keyword()
) :: binary()
```

Reads data from the active buffer (stub for test compatibility).

# `record_clear`

```elixir
@spec record_clear(t()) :: t()
```

Increments a clear operation metric.

# `record_scroll`

```elixir
@spec record_scroll(t()) :: t()
```

Increments a scroll operation metric.

# `record_write`

```elixir
@spec record_write(t()) :: t()
```

Increments a write operation metric.

# `reset_metrics`

```elixir
@spec reset_metrics(t()) :: t()
```

Resets metrics.

# `reset_position`

```elixir
@spec reset_position(t()) :: t()
```

Resets cursor position to origin (stub).

# `resize`

```elixir
@spec resize(t(), non_neg_integer(), non_neg_integer()) :: t()
```

Resizes both buffers.

# `start_link`

```elixir
@spec start_link(keyword()) :: {:ok, pid()} | {:error, term()}
```

Starts a GenServer for the manager (stub for test compatibility).

# `switch_buffer`

```elixir
@spec switch_buffer(t(), :main | :alternate) :: t()
```

Switches between main and alternate buffers.

# `switch_to_alternate`

```elixir
@spec switch_to_alternate(t()) :: t()
```

Switches to alternate buffer (convenience function).

# `switch_to_main`

```elixir
@spec switch_to_main(t()) :: t()
```

Switches to main buffer (convenience function).

# `toggle_buffer`

```elixir
@spec toggle_buffer(t()) :: t()
```

Toggles between main and alternate buffers.

# `trim_if_needed`

```elixir
@spec trim_if_needed(t()) :: t()
```

Trims scrollback if exceeding memory limits.

# `update_active_buffer`

```elixir
@spec update_active_buffer(t(), (Raxol.Terminal.ScreenBuffer.Core.t() -&gt;
                             Raxol.Terminal.ScreenBuffer.Core.t())) :: t()
@spec update_active_buffer(t(), Raxol.Terminal.ScreenBuffer.Core.t()) :: t()
```

Updates the active buffer.

Can accept either:
- A function that transforms the current buffer
- A new buffer to replace the current one

# `update_memory_usage`

```elixir
@spec update_memory_usage(t()) :: t()
```

Updates memory usage calculation.

# `update_position`

```elixir
@spec update_position(
  t(),
  {integer(), integer()}
) :: t()
```

Updates cursor position with delta (stub).

# `update_visible_region`

```elixir
@spec update_visible_region(t(), non_neg_integer()) :: t()
```

Updates visible region for scrolling (stub).

# `within_memory_limits?`

```elixir
@spec within_memory_limits?(t()) :: boolean()
```

Checks if within memory limits.

# `write`

```elixir
@spec write(t(), binary(), keyword()) :: {:ok, t()} | t()
```

Writes data to the active buffer (stub for test compatibility).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
