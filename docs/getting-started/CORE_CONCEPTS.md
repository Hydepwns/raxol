# Core Concepts

Understand the fundamentals of Raxol's architecture and design philosophy.

## Table of Contents

- [What is a Buffer?](#what-is-a-buffer)
- [The Rendering Pipeline](#the-rendering-pipeline)
- [State Management](#state-management)
- [Performance Model](#performance-model)
- [Design Philosophy](#design-philosophy)

---

## What is a Buffer?

A **buffer** is a 2D grid of cells representing terminal content. Think of it like a canvas for text.

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

**Key Points:**

1. **Width x Height** - Dimensions in characters (columns x rows)
2. **Lines** - List of rows, top to bottom
3. **Cells** - Each cell contains:
   - `char` - Single character (grapheme)
   - `style` - Visual styling (colors, bold, etc.)

### Why This Structure?

**Immutable & Functional:**
```elixir
# Each operation returns a NEW buffer
new_buffer = Buffer.write_at(old_buffer, 5, 3, "Text")

# old_buffer is unchanged (functional programming)
```

**Simple & Inspectable:**
```elixir
# You can always see what's in the buffer
IO.inspect(buffer.lines |> Enum.at(3) |> Map.get(:cells) |> Enum.at(5))
# => %{char: "T", style: %{}}
```

**Fast & Efficient:**
- No server processes required
- Pure data structure operations
- Optimal for diffing and caching

### Cell Coordinates

Buffers use **(x, y)** coordinates:

```
(0,0) ─────────────────> x (width)
  │
  │  (5,3) = Column 5, Row 3
  │
  v
  y (height)
```

**Remember:**
- `x` = column (horizontal position)
- `y` = row (vertical position)
- Both are **0-indexed**

```elixir
# Write "Hello" starting at column 10, row 5
buffer = Buffer.write_at(buffer, 10, 5, "Hello")
```

---

## The Rendering Pipeline

Raxol uses a multi-stage rendering pipeline optimized for terminal output.

### Stage 1: Buffer Construction

Build the buffer by combining operations:

```elixir
buffer = Buffer.create_blank_buffer(80, 24)
  |> Box.draw_box(0, 0, 80, 24, :double)
  |> Buffer.write_at(10, 5, "Title", %{bold: true})
  |> Buffer.write_at(10, 7, "Content goes here")
```

**This is pure data transformation.** No I/O, no side effects.

### Stage 2: Diffing (Optional but Recommended)

Calculate minimal changes between frames:

```elixir
old_buffer = # ... previous frame
new_buffer = # ... current frame

# Calculate what changed
diff = Renderer.render_diff(old_buffer, new_buffer)
# => [
#   {:move, 10, 7},
#   {:write, "Updated text"},
#   {:move, 15, 10},
#   {:write, "More changes"}
# ]
```

**Why Diff?**

Without diffing:
```elixir
# Redraw everything (slow, flickery)
IO.write("\e[2J\e[H")  # Clear screen
IO.puts(Buffer.to_string(new_buffer))
```

With diffing:
```elixir
# Only update changed cells (fast, smooth)
Enum.each(diff, &IO.write/1)
```

**Performance Impact:**
- Full render: ~100ms for 80x24 buffer
- Diff render: ~2ms for typical updates (50x faster!)

### Stage 3: Output Generation

Convert buffer data to terminal sequences:

```elixir
# Option 1: Full output (for debugging)
output = Buffer.to_string(buffer)
IO.puts(output)

# Option 2: Diff output (for efficiency)
diff = Renderer.render_diff(old, new)
Enum.each(diff, &IO.write/1)

# Option 3: HTML output (for web)
html = TerminalBridge.buffer_to_html(buffer)
```

### The Complete Pipeline

```
[User Code]
    │
    v
[Create Buffer] ─────> Immutable data structure
    │
    v
[Apply Operations] ──> write_at, draw_box, fill_area
    │
    v
[Calculate Diff] ────> Compare with previous frame
    │
    v
[Generate Output] ───> ANSI codes / HTML / String
    │
    v
[Display] ───────────> Terminal / Browser / File
```

---

## State Management

Raxol supports multiple state management patterns.

### Pattern 1: Pure Functional (Simplest)

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

**When to use:** Scripts, one-off renders, testing

### Pattern 2: Stateful Loop (Classic)

Maintain state in a loop:

```elixir
defmodule StatefulApp do
  def run do
    initial_state = %{count: 0, buffer: create_initial_buffer()}
    loop(initial_state)
  end

  defp loop(state) do
    # Update state
    new_state = handle_input(state)

    # Render new frame
    new_buffer = render(new_state)

    # Diff and output
    diff = Renderer.render_diff(state.buffer, new_buffer)
    Enum.each(diff, &IO.write/1)

    # Continue loop
    loop(%{new_state | buffer: new_buffer})
  end
end
```

**When to use:** Interactive CLIs, games, monitoring tools

### Pattern 3: GenServer (Concurrent)

Use OTP for concurrent state management:

```elixir
defmodule TerminalServer do
  use GenServer
  alias Raxol.Core.{Buffer, Renderer}

  def init(_) do
    state = %{
      buffer: Buffer.create_blank_buffer(80, 24),
      data: %{}
    }
    {:ok, state}
  end

  def handle_call({:update, data}, _from, state) do
    new_buffer = render(data)
    diff = Renderer.render_diff(state.buffer, new_buffer)

    # Send diff to client
    {:reply, diff, %{state | buffer: new_buffer, data: data}}
  end
end
```

**When to use:** Multi-user applications, web servers, distributed systems

### Pattern 4: Phoenix LiveView (Web)

Leverage Phoenix for web-based terminals:

```elixir
defmodule MyAppWeb.TerminalLive do
  use MyAppWeb, :live_view

  def mount(_params, _session, socket) do
    socket = assign(socket,
      buffer: create_initial_buffer(),
      count: 0
    )
    {:ok, socket}
  end

  def handle_event("increment", _, socket) do
    new_count = socket.assigns.count + 1
    new_buffer = update_buffer(socket.assigns.buffer, new_count)

    {:noreply, assign(socket, buffer: new_buffer, count: new_count)}
  end
end
```

**When to use:** Web applications, dashboards, remote terminals

---

## Performance Model

Raxol is designed for high-performance terminal rendering.

### Performance Targets

| Operation | Target | Typical |
|-----------|--------|---------|
| Buffer create | < 1ms | 0.3ms |
| write_at (single) | < 100μs | 50μs |
| draw_box | < 500μs | 240μs |
| render_diff | < 2ms | 1.2ms |
| Full render | < 16ms | 8ms |

**60 FPS = 16ms frame budget**

### Optimization Strategies

#### 1. Minimize Buffer Operations

```elixir
# Bad: Multiple intermediate buffers
buffer = Buffer.create_blank_buffer(80, 24)
buffer = Box.draw_box(buffer, 0, 0, 80, 24, :single)
buffer = Buffer.write_at(buffer, 10, 5, "Line 1")
buffer = Buffer.write_at(buffer, 10, 6, "Line 2")

# Good: Pipeline operations
buffer = Buffer.create_blank_buffer(80, 24)
  |> Box.draw_box(0, 0, 80, 24, :single)
  |> Buffer.write_at(10, 5, "Line 1")
  |> Buffer.write_at(10, 6, "Line 2")
```

**Why?** Elixir optimizes pipelines better than intermediate variables.

#### 2. Use Diff Rendering

```elixir
# Bad: Full redraws every frame
def render_loop(state) do
  new_buffer = create_frame(state)
  IO.write("\e[2J\e[H")  # Clear screen - SLOW!
  IO.puts(Buffer.to_string(new_buffer))
  render_loop(update_state(state))
end

# Good: Diff rendering
def render_loop(state) do
  new_buffer = create_frame(state)
  diff = Renderer.render_diff(state.buffer, new_buffer)
  Enum.each(diff, &IO.write/1)  # FAST!
  render_loop(%{state | buffer: new_buffer})
end
```

**Impact:** 50x faster for typical updates

#### 3. Batch Style Applications

```elixir
# Bad: Create style repeatedly
header_style = %{bold: true, fg_color: :blue}
buffer
|> Buffer.write_at(0, 0, "Title 1", header_style)
|> Buffer.write_at(0, 2, "Title 2", header_style)

# Good: Reuse style reference
header = Style.new(bold: true, fg_color: :blue)
buffer
|> Buffer.write_at(0, 0, "Title 1", header)
|> Buffer.write_at(0, 2, "Title 2", header)
```

**Why?** Avoid allocating duplicate style maps.

#### 4. Choose Appropriate Fill Operations

```elixir
# Bad: Loop with set_cell (slow for large areas)
for y <- 0..23, x <- 0..79, reduce: buffer do
  acc -> Buffer.set_cell(acc, x, y, " ", %{})
end

# Good: Use fill_area (optimized)
Box.fill_area(buffer, 0, 0, 80, 24, " ", %{})
```

**Impact:** 10x faster for area fills

### Memory Management

**Buffer Size:**
- Each cell: ~100 bytes (character + style)
- 80x24 buffer: ~192KB
- 200x50 buffer: ~1MB

**Guidelines:**
- Keep buffers reasonably sized (< 200x50 for most apps)
- Don't create unnecessary intermediate buffers
- Use diff rendering to avoid keeping too many historical buffers

### Profiling Your Application

```elixir
# Measure rendering time
{time, buffer} = :timer.tc(fn ->
  Buffer.create_blank_buffer(80, 24)
  |> Box.draw_box(0, 0, 80, 24, :double)
  # ... more operations
end)

IO.puts("Render time: #{time}μs (#{time / 1000}ms)")

# Check if you're hitting 60fps
if time > 16_000 do
  IO.warn("Rendering too slow for 60fps! (#{time / 1000}ms > 16ms)")
end
```

---

## Design Philosophy

Raxol's architecture is guided by several key principles.

### 1. Functional First

**Immutable Data:**
All buffer operations return new buffers, never mutate.

```elixir
old_buffer = Buffer.create_blank_buffer(10, 10)
new_buffer = Buffer.write_at(old_buffer, 5, 5, "X")

# old_buffer is unchanged
Buffer.get_cell(old_buffer, 5, 5)  # => %{char: " ", style: %{}}
Buffer.get_cell(new_buffer, 5, 5)  # => %{char: "X", style: %{}}
```

**Why?**
- Easier to reason about
- No hidden side effects
- Enables time-travel debugging
- Safe for concurrent access

### 2. Composable Operations

**Building Blocks:**
Complex UIs are compositions of simple operations.

```elixir
def create_dashboard(buffer, data) do
  buffer
  |> draw_header(data.title)
  |> draw_sidebar(data.menu)
  |> draw_content(data.body)
  |> draw_footer(data.status)
end

defp draw_header(buffer, title) do
  buffer
  |> Box.draw_box(0, 0, buffer.width, 3, :double)
  |> Buffer.write_at(5, 1, title, %{bold: true})
end
```

**Why?**
- Encourages code reuse
- Easy to test individual components
- Clear separation of concerns

### 3. Zero Dependencies (Core)

**Raxol.Core has ZERO runtime dependencies.**

```elixir
# mix.exs for raxol_core
def deps, do: []  # Nothing!
```

**Why?**
- Minimal install size (< 100KB)
- No dependency conflicts
- Works everywhere Elixir runs
- Fast compilation

### 4. Incremental Adoption

**Use what you need, when you need it:**

```elixir
# Level 1: Just buffers
{:raxol_core, "~> 2.0"}

# Level 2: Add LiveView
{:raxol_core, "~> 2.0"},
{:raxol_liveview, "~> 2.0"}

# Level 3: Full framework
{:raxol, "~> 2.0"}
```

**Why?**
- No forced complexity
- Learn incrementally
- Pay for what you use

### 5. Performance Budgets

**Every operation has a performance target:**

- Buffer operations: < 1ms
- Rendering: < 16ms (60fps)
- Memory: < 100KB per buffer

**Why?**
- Guarantees smooth UX
- Prevents performance regressions
- Enables real-time applications

---

## Common Questions

### Why buffers instead of direct rendering?

**Buffers enable diffing.** By maintaining the full state, we can calculate minimal updates.

```elixir
# Direct rendering (can't optimize)
IO.puts("\e[10;5HHello")  # Move and write

# Buffer-based (can optimize)
old = %{lines: [...]}
new = Buffer.write_at(old, 5, 10, "Hello")
diff = Renderer.render_diff(old, new)  # Only changed cells!
```

### Why not use ANSI escape codes directly?

**You can!** Buffers are optional:

```elixir
# Direct ANSI (totally fine for simple cases)
IO.write("\e[2J\e[H")  # Clear screen
IO.write("\e[10;5HHello, World!")

# But buffers give you:
# - Automatic diffing
# - State inspection
# - HTML rendering
# - Testing utilities
```

### How does this compare to other TUI frameworks?

| Feature | Raxol | ncurses | blessed |
|---------|-------|---------|---------|
| Language | Elixir | C | Node.js |
| Paradigm | Functional | Imperative | Imperative |
| Web Support | Yes (LiveView) | No | No |
| Dependencies | 0 (core) | System libs | Many |
| Type Safety | Yes (specs) | No | No (JS) |

### Can I mix Raxol with other libraries?

**Yes!** Raxol.Core is just data structures:

```elixir
# Generate buffer with Raxol
buffer = Buffer.create_blank_buffer(80, 24)
  |> Buffer.write_at(10, 5, "Generated by Raxol")

# Render with your own code
output = Buffer.to_string(buffer)
MyCustomRenderer.render(output)

# Or convert to your format
my_format = convert_buffer_to_my_format(buffer)
```

---

## Next Steps

- **[Migration Guide](./MIGRATION_FROM_DIY.md)** - Integrate Raxol with existing code
- **[Cookbook](../cookbook/README.md)** - Practical patterns and recipes
- **[API Reference](../core/BUFFER_API.md)** - Complete function documentation
- **[Architecture](../core/ARCHITECTURE.md)** - Deep dive into implementation details

---

**Questions or feedback?** Open an issue on GitHub!
