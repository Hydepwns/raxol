# Core Concepts

The fundamentals of Raxol's architecture.

## What is a Buffer?

A buffer is a 2D grid of cells representing terminal content -- a canvas for text.

### Buffer Structure

```elixir
%{
  width: 80,
  height: 24,
  lines: [
    %{cells: [
      %{char: "H", style: %{fg_color: :cyan, bold: true}},
      %{char: "e", style: %{}},
      %{char: "l", style: %{}},
      # ... more cells
    ]},
    # ... more lines
  ]
}
```

Each buffer has width x height dimensions in characters. Lines are rows top to bottom. Each cell contains a `char` (single grapheme) and a `style` map (colors, bold, etc.).

### Immutable & Functional

```elixir
# Each operation returns a NEW buffer
new_buffer = Buffer.write_at(old_buffer, 5, 3, "Text")
# old_buffer is unchanged
```

No server processes required. Pure data structure operations. Optimal for diffing and caching.

### Cell Coordinates

Buffers use **(x, y)** coordinates, both 0-indexed:

```
(0,0) ────────────────> x (width)
  |
  |  (5,3) = Column 5, Row 3
  |
  v
  y (height)
```

```elixir
# Write "Hello" starting at column 10, row 5
buffer = Buffer.write_at(buffer, 10, 5, "Hello")
```

---

## The Rendering Pipeline

### Stage 1: Buffer Construction

Build the buffer by combining operations:

```elixir
buffer = Buffer.create_blank_buffer(80, 24)
  |> Box.draw_box(0, 0, 80, 24, :double)
  |> Buffer.write_at(10, 5, "Title", %{bold: true})
  |> Buffer.write_at(10, 7, "Content goes here")
```

Pure data transformation. No I/O, no side effects.

### Stage 2: Diffing

Calculate minimal changes between frames:

```elixir
diff = Renderer.render_diff(old_buffer, new_buffer)
# => [
#   {:move, 10, 7},
#   {:write, "Updated text", %{}},
# ]
```

Without diffing you'd clear and redraw everything (~100ms for 80x24). With diffing, you only update changed cells (~2ms for typical updates). That's 50x faster.

### Stage 3: Output Generation

```elixir
# Full output (for debugging)
IO.puts(Buffer.to_string(buffer))

# Diff output (for efficiency)
IO.write(Renderer.apply_diff(diff))

# HTML output (for web)
html = TerminalBridge.buffer_to_html(buffer)
```

### The Complete Pipeline

```
[User Code]
    |
    v
[Create Buffer] ────> Immutable data structure
    |
    v
[Apply Operations] ──> write_at, draw_box, fill_area
    |
    v
[Calculate Diff] ────> Compare with previous frame
    |
    v
[Generate Output] ───> ANSI codes / HTML / String
    |
    v
[Display] ───────────> Terminal / Browser / File
```

---

## State Management

Raxol supports multiple patterns depending on your needs.

### Pure Functional (simplest)

No state, just transformations:

```elixir
defmodule SimpleRender do
  alias Raxol.Core.{Buffer, Box}

  def render(data) do
    Buffer.create_blank_buffer(80, 24)
    |> Box.draw_box(0, 0, 80, 24, :single)
    |> Buffer.write_at(10, 5, "Count: #{data.count}")
    |> Buffer.to_string()
  end
end
```

Good for scripts, one-off renders, testing.

### Stateful Loop

Maintain state in a loop:

```elixir
defmodule StatefulApp do
  def run do
    initial_state = %{count: 0, buffer: create_initial_buffer()}
    loop(initial_state)
  end

  defp loop(state) do
    new_state = handle_input(state)
    new_buffer = render(new_state)
    diff = Renderer.render_diff(state.buffer, new_buffer)
    IO.write(Renderer.apply_diff(diff))
    loop(%{new_state | buffer: new_buffer})
  end
end
```

Good for interactive CLIs, games, monitoring tools.

### GenServer

OTP for concurrent state management:

```elixir
defmodule TerminalServer do
  use GenServer
  alias Raxol.Core.{Buffer, Renderer}

  def init(_) do
    {:ok, %{buffer: Buffer.create_blank_buffer(80, 24), data: %{}}}
  end

  def handle_call({:update, data}, _from, state) do
    new_buffer = render(data)
    diff = Renderer.render_diff(state.buffer, new_buffer)
    {:reply, diff, %{state | buffer: new_buffer, data: data}}
  end
end
```

Good for multi-user applications, web servers, distributed systems.

### Phoenix LiveView

```elixir
defmodule MyAppWeb.TerminalLive do
  use MyAppWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, buffer: create_initial_buffer(), count: 0)}
  end

  def handle_event("increment", _, socket) do
    new_count = socket.assigns.count + 1
    new_buffer = update_buffer(socket.assigns.buffer, new_count)
    {:noreply, assign(socket, buffer: new_buffer, count: new_count)}
  end
end
```

Good for web applications, dashboards, remote terminals.

---

## Performance Model

### Targets

| Operation | Target | Typical |
|-----------|--------|---------|
| Buffer create | < 1ms | 0.3ms |
| write_at (single) | < 100us | 50us |
| draw_box | < 500us | 240us |
| render_diff | < 2ms | 1.2ms |
| Full render | < 16ms | 8ms |

60 FPS = 16ms frame budget.

### Optimization Tips

**Pipeline operations** instead of intermediate variables -- Elixir optimizes pipelines better.

**Use diff rendering** -- 50x faster for typical updates.

**Reuse style references** -- avoid allocating duplicate style maps.

**Use `fill_area`** instead of looping `set_cell` -- 10x faster for area fills.

### Memory

- Each cell: ~100 bytes (character + style)
- 80x24 buffer: ~192KB
- 200x50 buffer: ~1MB

Keep buffers reasonably sized. Don't hold references to old buffers you no longer need.

---

## Design Philosophy

**Functional first.** All buffer operations return new buffers, never mutate. Easier to reason about, no hidden side effects, safe for concurrent access.

**Composable.** Complex UIs are compositions of simple operations:

```elixir
def create_dashboard(buffer, data) do
  buffer
  |> draw_header(data.title)
  |> draw_sidebar(data.menu)
  |> draw_content(data.body)
  |> draw_footer(data.status)
end
```

**Zero dependencies (core).** Raxol.Core has no runtime dependencies. Minimal install size, no conflicts, works everywhere Elixir runs.

**Incremental adoption.** Use what you need -- `raxol_core` for buffers, add `raxol_liveview` for web, or `raxol` for the full framework.

---

## Common Questions

### Why buffers instead of direct rendering?

Buffers enable diffing. By maintaining the full state, we can calculate minimal updates instead of redrawing everything.

### Why not use ANSI escape codes directly?

You can! Buffers are optional. But they give you automatic diffing, state inspection, HTML rendering, and testing utilities.

### How does this compare to other TUI frameworks?

| Feature | Raxol | ncurses | blessed |
|---------|-------|---------|---------|
| Language | Elixir | C | Node.js |
| Paradigm | Functional | Imperative | Imperative |
| Web Support | Yes (LiveView) | No | No |
| Dependencies | 0 (core) | System libs | Many |

### Can I mix Raxol with other libraries?

Yes. Raxol.Core is just data structures:

```elixir
buffer = Buffer.create_blank_buffer(80, 24)
  |> Buffer.write_at(10, 5, "Generated by Raxol")

output = Buffer.to_string(buffer)
MyCustomRenderer.render(output)
```

---

## Next Steps

- [Migration Guide](./MIGRATION_FROM_DIY.md) - Integrate Raxol with existing code
- [Cookbook](../cookbook/README.md) - Practical patterns and recipes
- [API Reference](../core/BUFFER_API.md) - Complete function documentation
- [Architecture](../core/ARCHITECTURE.md) - Implementation details
