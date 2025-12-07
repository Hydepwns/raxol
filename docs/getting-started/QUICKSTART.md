# Quickstart Guide

> [Documentation](../README.md) > [Getting Started](CORE_CONCEPTS.md) > Quickstart

Get started with Raxol in 5, 10, or 15 minutes. Choose your path.

## What is Raxol?

Raxol is a terminal UI framework for Elixir that scales from simple buffers to full applications.

### Packages

- **Raxol.Core** - Pure functional buffer primitives (< 100KB, zero deps, < 1ms ops)
  - Perfect for: CLI tools, LiveView components, incremental adoption
- **Raxol.LiveView** - Phoenix LiveView integration
- **Raxol.Plugin** - Extensible plugin system
- **Raxol** (full) - Complete framework with enterprise features

Start small, add features as needed. See [Package Guide](PACKAGES.md) for detailed comparison.

---

## 5-Minute Tutorial: Your First Buffer

Just want to draw boxes and text? Use Raxol.Core.

### Installation

```elixir
# mix.exs
def deps do
  [
    {:raxol, "~> 2.0"}  # Or {:raxol_core, "~> 2.0"} for minimal install
  ]
end
```

```bash
mix deps.get
```

### Hello Buffer

Create a file `hello.exs`:

```elixir
alias Raxol.Core.{Buffer, Box}

# Create a 40x10 buffer
buffer = Buffer.create_blank_buffer(40, 10)

# Draw a double-line box
buffer = Box.draw_box(buffer, 0, 0, 40, 10, :double)

# Write some text
buffer = Buffer.write_at(buffer, 5, 4, "Hello, Raxol!")

# Render it
IO.puts(Buffer.to_string(buffer))
```

Run it:

```bash
elixir hello.exs
```

Output:
```
╔══════════════════════════════════════╗
║                                      ║
║                                      ║
║                                      ║
║     Hello, Raxol!                    ║
║                                      ║
║                                      ║
║                                      ║
║                                      ║
╚══════════════════════════════════════╝
```

**That's it!** Pure functional, no servers, no complexity.

### Key Concepts (5 min version)

1. **Create** - `Buffer.create_blank_buffer(width, height)`
2. **Draw** - `Box.draw_box()`, `Box.fill_area()`, etc.
3. **Write** - `Buffer.write_at(buffer, x, y, text)`
4. **Render** - `Buffer.to_string(buffer)` for output

Buffers are just data structures. No magic.

---

## 10-Minute Tutorial: LiveView Integration

Want to show a terminal in your Phoenix app? Add LiveView integration.

### Add Dependency

```elixir
# mix.exs
def deps do
  [
    {:raxol_core, "~> 2.0"},
    {:raxol_liveview, "~> 2.0"},
    {:phoenix_live_view, "~> 0.20 or ~> 1.0"}
  ]
end
```

### Create a LiveView

```elixir
# lib/my_app_web/live/terminal_live.ex
defmodule MyAppWeb.TerminalLive do
  use MyAppWeb, :live_view
  alias Raxol.Core.{Buffer, Box}

  def mount(_params, _session, socket) do
    # Create initial buffer
    buffer = Buffer.create_blank_buffer(80, 24)
    buffer = Box.draw_box(buffer, 0, 0, 80, 24, :rounded)
    buffer = Buffer.write_at(buffer, 10, 10, "Hello from LiveView!", %{})

    # Schedule periodic updates (optional)
    if connected?(socket), do: Process.send_after(self(), :tick, 1000)

    {:ok, assign(socket, buffer: buffer, count: 0)}
  end

  def render(assigns) do
    ~H"""
    <div>
      <h1>Live Terminal</h1>
      <.live_component
        module={Raxol.LiveView.TerminalComponent}
        id="terminal"
        buffer={@buffer}
        theme={:nord}
        on_keypress={&handle_keypress/1}
        on_click={&handle_click/1}
      />
    </div>
    """
  end

  def handle_info(:tick, socket) do
    # Update buffer every second
    count = socket.assigns.count + 1
    buffer = Buffer.write_at(
      socket.assigns.buffer,
      10, 12,
      "Ticks: #{count}",
      %{fg_color: :cyan}
    )

    Process.send_after(self(), :tick, 1000)
    {:noreply, assign(socket, buffer: buffer, count: count)}
  end

  def handle_keypress(key) do
    IO.puts("Key pressed: #{key}")
  end

  def handle_click({x, y}) do
    IO.puts("Clicked at: #{x}, #{y}")
  end
end
```

### Add Route

```elixir
# lib/my_app_web/router.ex
scope "/", MyAppWeb do
  pipe_through :browser

  live "/terminal", TerminalLive
end
```

### Include CSS

```elixir
# lib/my_app_web/components/layouts/root.html.heex
<link rel="stylesheet" href={~p"/assets/raxol_terminal.css"} />
```

### Start Server

```bash
mix phx.server
# Visit http://localhost:4000/terminal
```

**You now have a live terminal in your web app!** Updates in real-time, handles keyboard/mouse events.

### Available Themes

Choose from built-in themes:
- `:nord` - Nord color scheme
- `:dracula` - Dracula theme
- `:solarized_dark` - Solarized Dark
- `:solarized_light` - Solarized Light
- `:monokai` - Monokai

---

## 15-Minute Tutorial: Interactive Terminal

Build a fully interactive REPL-style terminal.

### The Plan

We'll create:
1. Command input at the bottom
2. Scrollable output area
3. Command history (up/down arrows)
4. Real-time updates

### Full Implementation

```elixir
defmodule MyAppWeb.InteractiveTerminalLive do
  use MyAppWeb, :live_view
  alias Raxol.Core.{Buffer, Box, Renderer}

  @width 80
  @height 24
  @output_height 22
  @input_height 2

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(
        buffer: create_initial_buffer(),
        output_lines: ["Welcome to Interactive Terminal!", "Type 'help' for commands"],
        input: "",
        history: [],
        history_index: 0
      )
      |> update_display()

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="interactive-terminal">
      <.live_component
        module={Raxol.LiveView.TerminalComponent}
        id="terminal"
        buffer={@buffer}
        theme={:nord}
        on_keypress={fn key -> send(self(), {:key, key}) end}
      />
    </div>
    """
  end

  def handle_info({:key, key}, socket) do
    socket =
      case key do
        "Enter" ->
          socket
          |> execute_command()
          |> clear_input()

        "Backspace" ->
          update(socket, :input, fn input ->
            String.slice(input, 0..-2//1)
          end)

        "ArrowUp" ->
          navigate_history(socket, :up)

        "ArrowDown" ->
          navigate_history(socket, :down)

        char when byte_size(char) == 1 ->
          update(socket, :input, fn input -> input <> char end)

        _ ->
          socket
      end
      |> update_display()

    {:noreply, socket}
  end

  defp create_initial_buffer do
    Buffer.create_blank_buffer(@width, @height)
    |> Box.draw_box(0, 0, @width, @height, :double)
    |> Box.draw_horizontal_line(0, @output_height, @width, "=")
  end

  defp update_display(socket) do
    buffer = create_initial_buffer()

    # Render output lines (last N lines that fit)
    output_lines = Enum.take(socket.assigns.output_lines, -(@output_height - 2))
    buffer =
      output_lines
      |> Enum.with_index()
      |> Enum.reduce(buffer, fn {line, idx}, buf ->
        Buffer.write_at(buf, 2, idx + 1, line, %{})
      end)

    # Render input line
    buffer =
      Buffer.write_at(
        buffer,
        2, @output_height + 1,
        "> #{socket.assigns.input}",
        %{fg_color: :cyan}
      )

    assign(socket, buffer: buffer)
  end

  defp execute_command(socket) do
    input = String.trim(socket.assigns.input)

    if input != "" do
      output = process_command(input)

      socket
      |> update(:output_lines, fn lines ->
        lines ++ ["> #{input}"] ++ output
      end)
      |> update(:history, fn hist -> [input | hist] end)
      |> assign(history_index: 0)
    else
      socket
    end
  end

  defp process_command("help") do
    [
      "Available commands:",
      "  help      - Show this help",
      "  clear     - Clear output",
      "  echo TEXT - Echo back text",
      "  time      - Show current time",
      "  exit      - Close terminal"
    ]
  end

  defp process_command("clear") do
    # Clear handled separately
    []
  end

  defp process_command("echo " <> text) do
    [text]
  end

  defp process_command("time") do
    [DateTime.utc_now() |> to_string()]
  end

  defp process_command("exit") do
    ["Goodbye!"]
  end

  defp process_command(cmd) do
    ["Unknown command: #{cmd}. Type 'help' for available commands."]
  end

  defp clear_input(socket) do
    assign(socket, input: "")
  end

  defp navigate_history(socket, direction) do
    history = socket.assigns.history
    index = socket.assigns.history_index

    new_index =
      case direction do
        :up -> min(index + 1, length(history))
        :down -> max(index - 1, 0)
      end

    input =
      if new_index > 0 and new_index <= length(history) do
        Enum.at(history, new_index - 1)
      else
        ""
      end

    socket
    |> assign(input: input)
    |> assign(history_index: new_index)
  end
end
```

### What You've Built

- **Command input** - Type commands at the bottom
- **Command history** - Up/Down arrows navigate history
- **Scrollable output** - Shows last 20 lines
- **Real-time rendering** - Instant visual updates
- **Themed UI** - Professional Nord theme

### Try It

```bash
mix phx.server
# Visit http://localhost:4000/terminal
# Type: help
# Type: echo Hello World
# Type: time
# Press up arrow to recall commands
```

---

## What's Next?

### Add More Features

**Syntax highlighting:**
```elixir
# Use Style module
style = Raxol.Core.Style.new(fg_color: :green, bold: true)
buffer = Buffer.write_at(buffer, x, y, "def function", style)
```

**Progress bars:**
```elixir
# Draw a progress bar
progress = 0.75  # 75%
width = 40
filled = round(width * progress)

buffer = Box.fill_area(buffer, 2, 10, filled, 1, "█", %{fg_color: :green})
buffer = Box.fill_area(buffer, 2 + filled, 10, width - filled, 1, "░", %{fg_color: :gray})
```

**Multiple panels:**
```elixir
# Split screen layout
buffer = Box.draw_box(buffer, 0, 0, 40, 24, :single)      # Left panel
buffer = Box.draw_box(buffer, 40, 0, 40, 24, :single)     # Right panel
```

### Explore More

- **[Core Concepts](./CORE_CONCEPTS.md)** - Deep dive into buffers and rendering
- **[Migration Guide](./MIGRATION_FROM_DIY.md)** - Already have a terminal renderer?
- **[Cookbook](../cookbook/README.md)** - Practical patterns and recipes
- **[API Reference](../core/BUFFER_API.md)** - Complete function documentation

### Examples Directory

Check out working examples:
```bash
# Run examples
mix run examples/core/01_hello_buffer.exs
mix run examples/core/02_box_drawing.exs
mix run examples/liveview/01_simple_terminal/
```

### Performance Targets

Raxol.Core is built for speed:
- **Buffer operations**: < 1ms for 80x24 grids
- **Rendering**: < 16ms (60fps capable)
- **Memory**: < 100KB per buffer
- **Dependencies**: Zero runtime dependencies

### Get Help

- **GitHub Issues**: https://github.com/Hydepwns/raxol/issues
- **Documentation**: Browse `docs/` directory
- **Examples**: Working code in `examples/`

---

## Frequently Asked Questions

### Do I need the full Raxol framework?

No! Start with `raxol_core` for just buffers, add `raxol_liveview` for web integration, or use `raxol` for everything.

### Can I use this with my existing Phoenix app?

Yes! Raxol.LiveView integrates seamlessly with Phoenix LiveView.

### Does this work in production?

Yes. Raxol is production-ready with 99%+ test coverage and performance benchmarks.

### Can I customize the themes?

Yes! Either use built-in themes or create custom CSS. See [Theming Cookbook](../cookbook/THEMING.md).

### What about mobile browsers?

Yes! The LiveView component is responsive and works on mobile (though keyboard input is limited to mobile keyboards).

---

## Quick Reference

### Buffer Operations

```elixir
# Create
buffer = Buffer.create_blank_buffer(80, 24)

# Write
buffer = Buffer.write_at(buffer, x, y, "text", style)

# Read
cell = Buffer.get_cell(buffer, x, y)

# Clear
buffer = Buffer.clear(buffer)

# Resize
buffer = Buffer.resize(buffer, new_width, new_height)

# Render
output = Buffer.to_string(buffer)
diff = Renderer.render_diff(old_buffer, new_buffer)
```

### Box Drawing

```elixir
# Styles: :single, :double, :rounded, :heavy, :dashed
buffer = Box.draw_box(buffer, x, y, width, height, :double)

# Lines
buffer = Box.draw_horizontal_line(buffer, x, y, length, "-")
buffer = Box.draw_vertical_line(buffer, x, y, length, "|")

# Fill
buffer = Box.fill_area(buffer, x, y, width, height, " ", style)
```

### Styles

```elixir
# Create style
style = Style.new(
  fg_color: :cyan,
  bg_color: :black,
  bold: true,
  italic: false,
  underline: false
)

# Merge styles
new_style = Style.merge(base_style, %{bold: true})

# Colors: :black, :red, :green, :yellow, :blue, :magenta, :cyan, :white
# Or RGB: {255, 128, 0}
# Or 256-color: 42
```

---

**Ready to build?** Pick a tutorial above and start coding!
