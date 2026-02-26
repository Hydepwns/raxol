# Performance Optimization

> [Documentation](../README.md) > [Cookbook](README.md) > Performance Optimization

Techniques for achieving 60fps terminal rendering.

## Table of Contents

- [Performance Targets](#performance-targets)
- [Buffer Diffing](#buffer-diffing)
- [Caching Strategies](#caching-strategies)
- [Lazy Rendering](#lazy-rendering)
- [60fps Checklist](#60fps-checklist)
- [Profiling Tools](#profiling-tools)

---

## Performance Targets

Target latencies for smooth UX:

| Operation | Budget | Typical | Excellent |
|-----------|--------|---------|-----------|
| Buffer create | < 1ms | 0.3ms | 0.1ms |
| write_at (single) | < 100μs | 50μs | 20μs |
| draw_box | < 500μs | 240μs | 150μs |
| render_diff | < 2ms | 1.2ms | 0.5ms |
| Full render | < 16ms | 8ms | 4ms |
| LiveView update | < 16ms | 5ms | 2ms |

**Golden Rule:** 16ms per frame = 60fps

---

## Buffer Diffing

Only update what changed.

### Recipe: Basic Diffing

```elixir
defmodule PerformantRenderer do
  alias Raxol.Core.{Buffer, Renderer}

  def render_loop(state) do
    # Create new frame
    new_buffer = create_frame(state)

    # Calculate minimal updates
    diff = Renderer.render_diff(state.buffer, new_buffer)

    # Apply only changed cells
    IO.write(Renderer.apply_diff(diff))

    # Continue with new buffer
    Process.sleep(16)  # ~60fps
    render_loop(%{state | buffer: new_buffer})
  end
end
```

**Performance Impact:**

```elixir
# Without diffing (BAD)
{time, _} = :timer.tc(fn ->
  IO.write("\e[2J\e[H")  # Clear screen
  IO.puts(Buffer.to_string(buffer))
end)
# => ~15,000μs (15ms) for 80x24 buffer

# With diffing (GOOD)
{time, _} = :timer.tc(fn ->
  diff = Renderer.render_diff(old_buffer, new_buffer)
  IO.write(Renderer.apply_diff(diff))
end)
# => ~300μs (0.3ms) for typical updates
# 50x faster!
```

### Recipe: Smart Diffing

Only diff when needed.

```elixir
defmodule SmartDiffing do
  def render_frame(state, force_full \\ false) do
    new_buffer = create_frame(state)

    if force_full or major_change?(state, new_buffer) do
      # Full render for major changes
      IO.write("\e[2J\e[H")
      IO.puts(Buffer.to_string(new_buffer))
    else
      # Diff for incremental updates
      diff = Renderer.render_diff(state.buffer, new_buffer)
      IO.write(Renderer.apply_diff(diff))
    end

    %{state | buffer: new_buffer}
  end

  defp major_change?(state, new_buffer) do
    # Example: Full render every 60 frames
    rem(state.frame_count, 60) == 0 or
    # Or if buffer size changed
    state.buffer.width != new_buffer.width or
    state.buffer.height != new_buffer.height
  end
end
```

---

## Caching Strategies

Cache expensive operations.

### Recipe: Style Caching

Reuse style maps.

```elixir
defmodule CachedStyles do
  alias Raxol.Core.Style

  # Module attributes for common styles (compile-time)
  @header_style Style.new(bold: true, fg_color: :cyan)
  @error_style Style.new(bold: true, fg_color: :red)
  @success_style Style.new(bold: true, fg_color: :green)

  def render_dashboard(buffer, data) do
    buffer
    |> Buffer.write_at(5, 1, "Dashboard", @header_style)  # Reuse
    |> Buffer.write_at(5, 3, data.message, message_style(data.status))
  end

  defp message_style(:ok), do: @success_style
  defp message_style(:error), do: @error_style
  defp message_style(_), do: %{}
end
```

**Impact:** 10-20% faster rendering by avoiding style allocation.

### Recipe: Buffer Caching

Cache static parts of the UI.

```elixir
defmodule BufferCache do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def get_or_create(key, create_fn) do
    GenServer.call(__MODULE__, {:get_or_create, key, create_fn})
  end

  # Server callbacks

  def init(_) do
    {:ok, %{cache: %{}}}
  end

  def handle_call({:get_or_create, key, create_fn}, _from, state) do
    case Map.get(state.cache, key) do
      nil ->
        buffer = create_fn.()
        new_cache = Map.put(state.cache, key, buffer)
        {:reply, buffer, %{state | cache: new_cache}}

      cached ->
        {:reply, cached, state}
    end
  end
end

# Usage
defmodule MyApp do
  alias Raxol.Core.{Buffer, Box}

  def render_with_cache do
    # Cache the static frame
    frame = BufferCache.get_or_create(:main_frame, fn ->
      Buffer.create_blank_buffer(80, 24)
      |> Box.draw_box(0, 0, 80, 24, :double)
      |> Buffer.write_at(10, 1, "My Application", %{bold: true})
    end)

    # Only update dynamic content
    frame
    |> Buffer.write_at(10, 10, "Time: #{Time.utc_now()}")
  end
end
```

### Recipe: Memoization

Memoize expensive calculations.

```elixir
defmodule Memoized do
  use Agent

  def start_link(_) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def memoize(key, fun) do
    Agent.get_and_update(__MODULE__, fn cache ->
      case Map.get(cache, key) do
        nil ->
          result = fun.()
          {result, Map.put(cache, key, result)}

        cached ->
          {cached, cache}
      end
    end)
  end
end

# Usage
defmodule ExpensiveCalculation do
  def calculate_layout(width, height) do
    # Cache layout calculations
    Memoized.memoize({:layout, width, height}, fn ->
      # Expensive layout algorithm
      calculate_grid(width, height)
    end)
  end
end
```

---

## Lazy Rendering

Only render visible content.

### Recipe: Viewport Rendering

Only render what's on screen.

```elixir
defmodule ViewportRenderer do
  alias Raxol.Core.Buffer

  def render_viewport(data, viewport) do
    # Create buffer for visible area only
    buffer = Buffer.create_blank_buffer(
      viewport.width,
      viewport.height
    )

    # Only process visible items
    data
    |> filter_visible(viewport)
    |> Enum.reduce(buffer, fn item, buf ->
      # Adjust coordinates for viewport offset
      x = item.x - viewport.offset_x
      y = item.y - viewport.offset_y

      if in_viewport?(x, y, viewport) do
        Buffer.write_at(buf, x, y, item.text, item.style)
      else
        buf
      end
    end)
  end

  defp filter_visible(items, viewport) do
    Enum.filter(items, fn item ->
      item.x >= viewport.offset_x and
      item.x < viewport.offset_x + viewport.width and
      item.y >= viewport.offset_y and
      item.y < viewport.offset_y + viewport.height
    end)
  end

  defp in_viewport?(x, y, viewport) do
    x >= 0 and x < viewport.width and
    y >= 0 and y < viewport.height
  end
end
```

**Impact:** 100x faster for large datasets (only render 24 rows instead of 1000+)

### Recipe: Virtual Scrolling

Render only visible rows in scrollable lists.

```elixir
defmodule VirtualScrolling do
  alias Raxol.Core.{Buffer, Box}

  def render_list(buffer, items, scroll_offset, visible_rows) do
    # Calculate visible range
    start_idx = scroll_offset
    end_idx = min(scroll_offset + visible_rows, length(items))

    # Get visible items
    visible_items = Enum.slice(items, start_idx, visible_rows)

    # Render only visible rows
    visible_items
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {item, idx}, buf ->
      y = idx + 2  # Offset for header
      Buffer.write_at(buf, 2, y, format_item(item))
    end)
    |> add_scrollbar(scroll_offset, length(items), visible_rows)
  end

  defp add_scrollbar(buffer, offset, total, visible) do
    # Calculate scrollbar position
    max_offset = max(total - visible, 0)
    scrollbar_pos = if max_offset > 0 do
      div(offset * (visible - 2), max_offset) + 2
    else
      2
    end

    # Draw scrollbar
    buffer
    |> Box.draw_vertical_line(78, 2, visible, "│")
    |> Buffer.write_at(78, scrollbar_pos, "█", %{fg_color: :cyan})
  end

  defp format_item(item) do
    String.pad_trailing(to_string(item), 75)
  end
end
```

---

## 60fps Checklist

Ensure your app hits 60fps.

### Checklist

- [ ] **Use diff rendering** - Don't redraw everything
- [ ] **Cache static content** - Reuse unchanged buffers
- [ ] **Minimize allocations** - Reuse style maps
- [ ] **Batch updates** - Group operations
- [ ] **Lazy render** - Only render visible content
- [ ] **Profile regularly** - Measure before optimizing
- [ ] **Set frame budget** - Warn if > 16ms
- [ ] **Test on slow hardware** - Don't just test on dev machine

### Recipe: Frame Budget Monitor

Automatically warn when exceeding 16ms.

```elixir
defmodule FrameBudget do
  @fps_60_budget_us 16_000  # 16ms in microseconds

  def render_with_budget(render_fn) do
    {time_us, result} = :timer.tc(render_fn)

    if time_us > @fps_60_budget_us do
      Logger.warn("Slow render: #{time_us}μs (> #{@fps_60_budget_us}μs)")
      log_performance_metrics(time_us)
    end

    result
  end

  defp log_performance_metrics(time_us) do
    # Send to metrics system
    MyApp.Metrics.histogram("terminal.render_time_us", time_us)

    # Calculate FPS
    fps = 1_000_000 / time_us
    Logger.debug("Actual FPS: #{Float.round(fps, 2)}")
  end
end

# Usage
FrameBudget.render_with_budget(fn ->
  create_frame(state)
end)
```

---

## Profiling Tools

Identify bottlenecks.

### Recipe: Manual Profiling

```elixir
defmodule ManualProfiler do
  def profile(label, fun) do
    {time, result} = :timer.tc(fun)
    IO.puts("#{label}: #{time}μs (#{time / 1000}ms)")
    result
  end
end

# Usage
ManualProfiler.profile("Create buffer", fn ->
  Buffer.create_blank_buffer(80, 24)
end)
# => Create buffer: 300μs (0.3ms)

ManualProfiler.profile("Draw box", fn ->
  Box.draw_box(buffer, 0, 0, 80, 24, :double)
end)
# => Draw box: 240μs (0.24ms)

ManualProfiler.profile("Full render", fn ->
  create_complex_frame(state)
end)
# => Full render: 8500μs (8.5ms)
```

### Recipe: Benchmarking with Benchee

```elixir
# bench/rendering_benchmark.exs
alias Raxol.Core.{Buffer, Box, Renderer}

buffer = Buffer.create_blank_buffer(80, 24)

Benchee.run(%{
  "create_buffer" => fn ->
    Buffer.create_blank_buffer(80, 24)
  end,
  "draw_box" => fn ->
    Box.draw_box(buffer, 0, 0, 80, 24, :double)
  end,
  "write_at" => fn ->
    Buffer.write_at(buffer, 10, 10, "Hello World")
  end,
  "full_render" => fn ->
    Buffer.to_string(buffer)
  end,
  "diff_render_no_changes" => fn ->
    Renderer.render_diff(buffer, buffer)
  end,
  "diff_render_one_cell" => fn ->
    new = Buffer.write_at(buffer, 40, 12, "X")
    Renderer.render_diff(buffer, new)
  end
}, time: 5, memory_time: 2)
```

Run with:
```bash
mix run bench/rendering_benchmark.exs
```

### Recipe: Production Profiling

```elixir
defmodule ProductionProfiler do
  @moduledoc """
  Lightweight profiler for production use.
  Tracks average times without overhead.
  """

  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def track(operation, time_us) do
    GenServer.cast(__MODULE__, {:track, operation, time_us})
  end

  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  # Server

  def init(_) do
    {:ok, %{stats: %{}}}
  end

  def handle_cast({:track, operation, time_us}, state) do
    stats = Map.update(state.stats, operation,
      %{count: 1, total: time_us, avg: time_us},
      fn s ->
        new_count = s.count + 1
        new_total = s.total + time_us
        %{count: new_count, total: new_total, avg: new_total / new_count}
      end
    )

    {:noreply, %{state | stats: stats}}
  end

  def handle_call(:get_stats, _from, state) do
    {:reply, state.stats, state}
  end
end

# Usage
{time, result} = :timer.tc(fn -> render_frame() end)
ProductionProfiler.track(:render_frame, time)

# Later, check stats
ProductionProfiler.get_stats()
# => %{
#   render_frame: %{count: 1000, total: 8_500_000, avg: 8500}
# }
```

---

## Common Performance Pitfalls

### Pitfall 1: Creating Styles Repeatedly

**Bad:**
```elixir
# Creates new style map each iteration
Enum.each(lines, fn line ->
  Buffer.write_at(buffer, 0, line, "Text", %{fg_color: :cyan})
end)
```

**Good:**
```elixir
# Reuse style
style = %{fg_color: :cyan}
Enum.reduce(lines, buffer, fn line, buf ->
  Buffer.write_at(buf, 0, line, "Text", style)
end)
```

**Impact:** 30% faster for 100+ writes

### Pitfall 2: Full Redraws

**Bad:**
```elixir
# Clear and redraw everything
def update_counter(state) do
  IO.write("\e[2J\e[H")
  buffer = create_full_ui(state.count)
  IO.puts(Buffer.to_string(buffer))
end
```

**Good:**
```elixir
# Only update changed cell
def update_counter(state) do
  old_buffer = state.buffer
  new_buffer = Buffer.write_at(old_buffer, 20, 5, "#{state.count}")
  diff = Renderer.render_diff(old_buffer, new_buffer)
  IO.write(Renderer.apply_diff(diff))
  %{state | buffer: new_buffer}
end
```

**Impact:** 50x faster

### Pitfall 3: Synchronous Operations

**Bad:**
```elixir
# Blocking external API call in render loop
def render_loop(state) do
  data = HTTPClient.get("/api/stats")  # BLOCKS!
  buffer = create_frame(data)
  # ...
end
```

**Good:**
```elixir
# Async data fetching
def render_loop(state) do
  # Use cached data, update async
  buffer = create_frame(state.cached_data)
  # ...
end

def handle_info(:fetch_data, state) do
  # Async fetch in separate process
  Task.start(fn ->
    data = HTTPClient.get("/api/stats")
    send(self(), {:data_ready, data})
  end)
  {:noreply, state}
end
```

---

## Performance Testing

### Recipe: Automated Performance Tests

```elixir
# test/performance/rendering_test.exs
defmodule RenderingPerformanceTest do
  use ExUnit.Case
  alias Raxol.Core.{Buffer, Box, Renderer}

  @fps_60_budget 16_000  # 16ms in μs

  test "buffer creation is fast" do
    {time, _} = :timer.tc(fn ->
      Buffer.create_blank_buffer(80, 24)
    end)

    assert time < 1000, "Buffer creation too slow: #{time}μs"
  end

  test "box drawing is fast" do
    buffer = Buffer.create_blank_buffer(80, 24)

    {time, _} = :timer.tc(fn ->
      Box.draw_box(buffer, 0, 0, 80, 24, :double)
    end)

    assert time < 500, "Box drawing too slow: #{time}μs"
  end

  test "full frame render meets 60fps budget" do
    buffer = create_complex_frame()

    {time, _} = :timer.tc(fn ->
      Buffer.to_string(buffer)
    end)

    assert time < @fps_60_budget,
      "Full render too slow: #{time}μs (> #{@fps_60_budget}μs)"
  end

  defp create_complex_frame do
    Buffer.create_blank_buffer(80, 24)
    |> Box.draw_box(0, 0, 80, 24, :double)
    |> add_multiple_elements()
  end

  defp add_multiple_elements(buffer) do
    # Simulate complex UI with many elements
    Enum.reduce(1..100, buffer, fn i, buf ->
      x = rem(i * 7, 70) + 5
      y = rem(i * 3, 20) + 2
      Buffer.write_at(buf, x, y, "#{i}")
    end)
  end
end
```

---

## Next Steps

- **[LiveView Cookbook](./LIVEVIEW_INTEGRATION.md)** - Web integration patterns
- **[Theming Cookbook](./THEMING.md)** - Custom themes
- **[API Reference](../core/BUFFER_API.md)** - Complete function docs

---

**Remember:** Profile before optimizing. Measure, don't guess!
