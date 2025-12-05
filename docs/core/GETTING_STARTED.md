# Getting Started with Raxol.Core

Quick start guide for using Raxol's lightweight buffer primitives.

## What is Raxol.Core?

Raxol.Core is a standalone package providing pure functional terminal buffer operations with:

- **Zero dependencies** - No external runtime requirements
- **< 100KB compiled** - Minimal footprint
- **< 1ms operations** - High performance
- **Pure functional** - No GenServers, no state, thread-safe

Perfect for:
- Adding terminal rendering to existing Elixir apps
- Building custom terminal UIs
- LiveView terminal components
- CLI tools and scripts
- Incremental adoption (use just what you need)

## 5-Minute Tutorial: Your First Buffer

```elixir
# 1. Create a buffer
alias Raxol.Core.{Buffer, Box}

buffer = Buffer.create_blank_buffer(40, 10)
# => %{lines: [...], width: 40, height: 10}

# 2. Write some text
buffer = Buffer.write_at(buffer, 5, 3, "Hello, Raxol!")

# 3. Draw a box around it
buffer = Box.draw_box(buffer, 0, 0, 40, 10, :double)

# 4. Render to terminal
IO.puts(Buffer.to_string(buffer))
```

Output:
```
╔══════════════════════════════════════╗
║                                      ║
║                                      ║
║     Hello, Raxol!                    ║
║                                      ║
║                                      ║
║                                      ║
║                                      ║
║                                      ║
╚══════════════════════════════════════╝
```

That's it! You've created your first terminal UI.

## 10-Minute Tutorial: Interactive Buffer

Let's build a simple interactive display that updates.

```elixir
defmodule SimpleCounter do
  alias Raxol.Core.{Buffer, Box, Renderer}

  def run do
    # Initial state
    buffer = Buffer.create_blank_buffer(30, 8)

    # Draw static UI
    buffer = Box.draw_box(buffer, 0, 0, 30, 8, :single)
    buffer = Buffer.write_at(buffer, 2, 1, "Counter Demo", %{})
    buffer = Box.draw_horizontal_line(buffer, 1, 2, 28, "-")

    # Render initial state
    IO.write("\e[2J\e[H")  # Clear screen
    IO.puts(Buffer.to_string(buffer))

    # Update loop
    loop(buffer, 0)
  end

  defp loop(old_buffer, count) do
    # Update counter display
    new_buffer = Buffer.write_at(old_buffer, 2, 4, "Count: #{count}    ", %{})

    # Only render what changed
    diff = Renderer.render_diff(old_buffer, new_buffer)
    Enum.each(diff, &IO.write/1)

    # Wait and continue
    Process.sleep(1000)
    loop(new_buffer, count + 1)
  end
end

SimpleCounter.run()
```

Key concepts demonstrated:
1. **Persistent UI** - Draw boxes and labels once
2. **Efficient updates** - Only redraw changed parts
3. **Diff rendering** - `render_diff/2` calculates minimal updates

## 15-Minute Tutorial: Styled Components

Add colors and styles to make it look professional.

```elixir
defmodule StyledDashboard do
  alias Raxol.Core.{Buffer, Box, Style}

  def create_dashboard do
    buffer = Buffer.create_blank_buffer(60, 20)

    # Title bar with style
    title_style = Style.new(bold: true, fg_color: :white, bg_color: :blue)
    buffer = Box.fill_area(buffer, 0, 0, 60, 1, " ", title_style)
    buffer = Buffer.write_at(buffer, 2, 0, "System Dashboard", title_style)

    # Status panel (green)
    buffer = draw_panel(buffer, 2, 2, 26, 8, "System Status", :green)
    buffer = Buffer.write_at(buffer, 4, 4, "CPU: 45%", %{})
    buffer = Buffer.write_at(buffer, 4, 5, "Memory: 2.1GB", %{})
    buffer = Buffer.write_at(buffer, 4, 6, "Disk: 450GB free", %{})

    # Alerts panel (yellow)
    buffer = draw_panel(buffer, 32, 2, 26, 8, "Alerts", :yellow)
    buffer = Buffer.write_at(buffer, 34, 4, "3 warnings", %{fg_color: :yellow})
    buffer = Buffer.write_at(buffer, 34, 5, "0 errors", %{fg_color: :green})

    # Log panel
    buffer = draw_panel(buffer, 2, 11, 56, 8, "Recent Logs", :cyan)
    buffer = Buffer.write_at(buffer, 4, 13, "[INFO] Server started", %{})
    buffer = Buffer.write_at(buffer, 4, 14, "[WARN] High memory usage", %{fg_color: :yellow})
    buffer = Buffer.write_at(buffer, 4, 15, "[INFO] Request processed", %{})

    buffer
  end

  defp draw_panel(buffer, x, y, width, height, title, color) do
    header_style = Style.new(bold: true, fg_color: color)

    buffer
    |> Box.draw_box(x, y, width, height, :single)
    |> Buffer.write_at(x + 2, y, " #{title} ", header_style)
  end
end

# Render the dashboard
buffer = StyledDashboard.create_dashboard()
IO.puts(Buffer.to_string(buffer))
```

Concepts:
1. **Style composition** - Build reusable style maps
2. **Color coding** - Visual hierarchy with colors
3. **Component patterns** - Reusable `draw_panel/6` function
4. **Layout** - Multi-panel grid layout

## Common Patterns

### Pattern 1: Double Buffering

Prevent flicker by rendering off-screen:

```elixir
defmodule DoubleBuffer do
  def render_frame(old_buffer, new_content) do
    # Build new frame completely
    new_buffer = Buffer.create_blank_buffer(80, 24)
    new_buffer = draw_ui(new_buffer, new_content)

    # Calculate diff and render
    diff = Renderer.render_diff(old_buffer, new_buffer)
    Enum.each(diff, &IO.write/1)

    new_buffer  # Return for next frame
  end

  defp draw_ui(buffer, content) do
    buffer
    |> Box.draw_box(0, 0, 80, 24, :double)
    |> Buffer.write_at(5, 5, content, %{})
  end
end
```

### Pattern 2: Partial Updates

Update specific regions efficiently:

```elixir
def update_status_line(buffer, status) do
  # Clear the line first
  buffer = Box.fill_area(buffer, 0, 23, 80, 1, " ", %{})

  # Write new status
  Buffer.write_at(buffer, 2, 23, status, %{fg_color: :cyan})
end
```

### Pattern 3: Grid Layouts

Create responsive grid layouts:

```elixir
defmodule GridLayout do
  def create_grid(buffer, cols, rows) do
    {width, height} = {buffer.width, buffer.height}
    cell_width = div(width, cols)
    cell_height = div(height, rows)

    for row <- 0..(rows - 1),
        col <- 0..(cols - 1),
        reduce: buffer do
      acc ->
        x = col * cell_width
        y = row * cell_height
        Box.draw_box(acc, x, y, cell_width, cell_height, :single)
    end
  end
end
```

### Pattern 4: Text Centering

Center text in a region:

```elixir
def center_text(buffer, x, y, width, text) do
  padding = div(width - String.length(text), 2)
  Buffer.write_at(buffer, x + padding, y, text, %{})
end
```

## Performance Tips

### 1. Minimize Buffer Operations

```elixir
# Good - Chain operations
buffer
|> Buffer.write_at(0, 0, "Line 1")
|> Buffer.write_at(0, 1, "Line 2")
|> Buffer.write_at(0, 2, "Line 3")

# Avoid - Intermediate variables
buffer = Buffer.write_at(buffer, 0, 0, "Line 1")
buffer = Buffer.write_at(buffer, 0, 1, "Line 2")
buffer = Buffer.write_at(buffer, 0, 2, "Line 3")
```

### 2. Use Diff Rendering

```elixir
# Good - Only update what changed
diff = Renderer.render_diff(old, new)
Enum.each(diff, &IO.write/1)

# Avoid - Full redraws
IO.write("\e[2J\e[H")  # Clear screen
IO.puts(Buffer.to_string(new))
```

### 3. Batch Style Applications

```elixir
# Good - Reuse style maps
header_style = Style.new(bold: true, fg_color: :blue)
buffer
|> Buffer.write_at(0, 0, "Title 1", header_style)
|> Buffer.write_at(0, 2, "Title 2", header_style)

# Avoid - Creating styles repeatedly
buffer
|> Buffer.write_at(0, 0, "Title 1", %{bold: true, fg_color: :blue})
|> Buffer.write_at(0, 2, "Title 2", %{bold: true, fg_color: :blue})
```

### 4. Choose Appropriate Fill Operations

```elixir
# Good - Use fill_area for large regions
buffer = Box.fill_area(buffer, 0, 0, 80, 24, " ", %{bg_color: :black})

# Avoid - Loop with set_cell
for y <- 0..23, x <- 0..79, reduce: buffer do
  acc -> Buffer.set_cell(acc, x, y, " ", %{bg_color: :black})
end
```

## Debugging Tips

### 1. Print Buffer State

```elixir
# Quick debug output
IO.puts("\n--- Buffer Debug ---")
IO.puts(Buffer.to_string(buffer))
IO.puts("--------------------\n")
```

### 2. Inspect Specific Cells

```elixir
# Check what's at a position
cell = Buffer.get_cell(buffer, 5, 3)
IO.inspect(cell, label: "Cell at (5,3)")
# Cell at (5,3): %{char: "H", style: %{bold: true}}
```

### 3. Validate Buffer Dimensions

```elixir
# Ensure buffer size is correct
IO.puts("Buffer: #{buffer.width}x#{buffer.height}")
IO.puts("Lines: #{length(buffer.lines)}")
IO.puts("Cells per line: #{length(hd(buffer.lines).cells)}")
```

## Integration Examples

### CLI Script

```elixir
#!/usr/bin/env elixir
Mix.install([{:raxol, "~> 2.0"}])

alias Raxol.Core.{Buffer, Box}

buffer = Buffer.create_blank_buffer(50, 10)
buffer = Box.draw_box(buffer, 0, 0, 50, 10, :double)
buffer = Buffer.write_at(buffer, 10, 4, "Hello from Raxol!", %{})

IO.puts(Buffer.to_string(buffer))
```

### Phoenix LiveView Component

```elixir
defmodule MyAppWeb.TerminalLive do
  use MyAppWeb, :live_view
  alias Raxol.Core.{Buffer, Box}

  def mount(_params, _session, socket) do
    buffer = Buffer.create_blank_buffer(80, 24)
    buffer = Box.draw_box(buffer, 0, 0, 80, 24, :single)

    {:ok, assign(socket, buffer: buffer, output: Buffer.to_string(buffer))}
  end

  def render(assigns) do
    ~H"""
    <pre class="terminal"><%= @output %></pre>
    """
  end

  def handle_event("update", %{"text" => text}, socket) do
    buffer = Buffer.write_at(socket.assigns.buffer, 2, 2, text, %{})
    {:noreply, assign(socket, buffer: buffer, output: Buffer.to_string(buffer))}
  end
end
```

### Mix Task

```elixir
defmodule Mix.Tasks.MyApp.Dashboard do
  use Mix.Task
  alias Raxol.Core.{Buffer, Box}

  def run(_args) do
    buffer = create_dashboard()
    IO.puts(Buffer.to_string(buffer))
  end

  defp create_dashboard do
    Buffer.create_blank_buffer(60, 20)
    |> Box.draw_box(0, 0, 60, 20, :double)
    |> Buffer.write_at(20, 1, "My Dashboard", %{bold: true})
  end
end
```

## Common Pitfalls

### 1. Coordinate System

Remember: coordinates are (x, y) where x=column, y=row, both 0-indexed.

```elixir
# Correct
Buffer.write_at(buffer, 5, 3, "Text")  # Column 5, Row 3

# Common mistake - mixing up x/y
Buffer.write_at(buffer, 3, 5, "Text")  # Different position!
```

### 2. Buffer Boundaries

Out-of-bounds writes are silently ignored:

```elixir
buffer = Buffer.create_blank_buffer(10, 5)
buffer = Buffer.write_at(buffer, 100, 100, "Lost!")  # No error, no effect

# Always validate coordinates if needed
if x < buffer.width and y < buffer.height do
  buffer = Buffer.write_at(buffer, x, y, text)
end
```

### 3. Style Immutability

Styles are maps, not merged automatically:

```elixir
# Wrong - second write loses style
buffer
|> Buffer.write_at(0, 0, "Bold", %{bold: true})
|> Buffer.write_at(0, 0, "Blue Bold", %{fg_color: :blue})  # Lost bold!

# Correct - merge styles
base_style = %{bold: true}
new_style = Style.merge(base_style, %{fg_color: :blue})
buffer = Buffer.write_at(buffer, 0, 0, "Blue Bold", new_style)
```

### 4. String Length vs Grapheme Count

Use grapheme-aware functions:

```elixir
# Wrong - byte length
text = "Hello 👋"
length = byte_size(text)  # 10 (includes emoji bytes)

# Correct - grapheme count
length = String.length(text)  # 7 (visual characters)
```

## Next Steps

- **API Reference**: See [BUFFER_API.md](./BUFFER_API.md) for complete function documentation
- **Architecture**: Read [ARCHITECTURE.md](./ARCHITECTURE.md) to understand design decisions
- **Examples**: Explore [examples/core/README.md](../../examples/core/README.md) for more patterns
- **Benchmarks**: Check [benchmarks](../../docs/bench/README.md) for performance data

## Getting Help

- GitHub Issues: Report bugs or request features
- Documentation: Browse the docs directory
- Examples: Working code in the examples directory

Happy terminal hacking!
