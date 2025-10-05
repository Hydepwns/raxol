# Raxol Core

[![Hex.pm](https://img.shields.io/hexpm/v/raxol_core.svg)](https://hex.pm/packages/raxol_core)
[![Documentation](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://hexdocs.pm/raxol_core)

Lightweight terminal buffer primitives for Elixir. Pure functional buffer operations with **zero runtime dependencies**.

## Features

- **Pure Functional** - Immutable buffer operations, no side effects
- **Zero Dependencies** - No external runtime dependencies
- **Lightweight** - < 100KB compiled
- **Fast** - Sub-millisecond operations for 80x24 buffers
- **Flexible** - Use with any rendering backend

## Installation

Add `raxol_core` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:raxol_core, "~> 2.0"}
  ]
end
```

## Quick Start

### Create a Buffer

```elixir
alias Raxol.Core.Buffer

# Create a blank buffer
buffer = Buffer.create_blank_buffer(80, 24)

# Write text at position
buffer = Buffer.write_at(buffer, 0, 0, "Hello, World!")

# Convert to string for display
IO.puts Buffer.to_string(buffer)
```

### Draw Boxes

```elixir
alias Raxol.Core.{Buffer, Box}

buffer = Buffer.create_blank_buffer(40, 10)

# Draw a double-line box
buffer = Box.draw_box(buffer, 0, 0, 40, 10, :double)

# Add a title
buffer = Buffer.write_at(buffer, 2, 0, " My Box ", %{bold: true})

IO.puts Buffer.to_string(buffer)
```

### Apply Styles

```elixir
alias Raxol.Core.{Buffer, Style}

buffer = Buffer.create_blank_buffer(80, 24)

# Create styled text
style = %{
  fg_color: :cyan,
  bg_color: :black,
  bold: true,
  underline: true
}

buffer = Buffer.write_at(buffer, 0, 0, "Styled Text", style)

# Render with ANSI codes
ansi_output = Raxol.Core.Renderer.buffer_to_ansi(buffer)
IO.puts ansi_output
```

## Core Modules

### `Raxol.Core.Buffer`

Immutable 2D character buffer with styling support.

**Key functions:**
- `create_blank_buffer(width, height)` - Create new buffer
- `write_at(buffer, x, y, text, style \\ %{})` - Write text at position
- `get_cell(buffer, x, y)` - Get cell at position
- `to_string(buffer)` - Convert to plain string
- `merge(buffer1, buffer2, x, y)` - Merge buffers

### `Raxol.Core.Renderer`

Convert buffers to various output formats.

**Renderers:**
- `buffer_to_ansi(buffer)` - ANSI terminal codes
- `buffer_to_html(buffer)` - HTML with inline styles
- `buffer_to_diff(old, new)` - Efficient diff-based updates

### `Raxol.Core.Style`

Text styling and color management.

**Styles:**
- Colors: `:black`, `:red`, `:green`, `:yellow`, `:blue`, `:magenta`, `:cyan`, `:white`
- Attributes: `:bold`, `:italic`, `:underline`, `:reverse`, `:strikethrough`
- True color: `{:rgb, r, g, b}`

### `Raxol.Core.Box`

ASCII/Unicode box drawing.

**Box types:**
- `:single` - Single-line box
- `:double` - Double-line box
- `:rounded` - Rounded corners
- `:heavy` - Heavy/bold lines
- `:ascii` - ASCII-only (`+`, `-`, `|`)

## Use Cases

### Terminal UIs

```elixir
buffer = Buffer.create_blank_buffer(80, 24)
buffer = Box.draw_box(buffer, 0, 0, 80, 24, :double)
buffer = Buffer.write_at(buffer, 2, 1, "Terminal UI", %{bold: true})

IO.write("\e[2J\e[H")  # Clear screen
IO.puts Renderer.buffer_to_ansi(buffer)
```

### CLI Progress Bars

```elixir
defmodule ProgressBar do
  alias Raxol.Core.Buffer

  def render(progress, width) do
    buffer = Buffer.create_blank_buffer(width, 1)
    filled = trunc(width * progress)
    bar = String.duplicate("=", filled) <> String.duplicate(" ", width - filled)
    Buffer.write_at(buffer, 0, 0, "[#{bar}]")
  end
end
```

### Custom Renderers

```elixir
# Use buffers with your own rendering pipeline
buffer = Buffer.create_blank_buffer(80, 24)
buffer = Buffer.write_at(buffer, 0, 0, "Hello")

# Your custom renderer
def my_renderer(buffer) do
  # Convert buffer to your format
  # SVG, PDF, canvas, etc.
end
```

### Web Integration

```elixir
# Phoenix LiveView
buffer = Buffer.create_blank_buffer(80, 24)
html = Renderer.buffer_to_html(buffer)

# Use in template
<div class="terminal">
  <%= raw html %>
</div>
```

## Architecture

Raxol Core is designed as a **pure functional layer** with no dependencies:

```
┌─────────────────────────────┐
│     Your Application        │
│  (Phoenix, CLI, Custom)     │
└────────────┬────────────────┘
             │
             ▼
┌─────────────────────────────┐
│       Raxol Core            │
│  (Buffer, Renderer, Style)  │
│                             │
│  - Pure functions           │
│  - Zero dependencies        │
│  - Immutable data           │
└─────────────────────────────┘
```

### Design Principles

1. **Functional Core, Imperative Shell** - Core is pure functional, I/O happens at edges
2. **Zero Dependencies** - No external libraries, just Elixir stdlib
3. **Composable** - Small, focused functions that compose well
4. **Flexible** - Works with any rendering backend

## Performance

Benchmarks on 2021 MacBook Pro (M1):

- Buffer creation (80x24): ~15μs
- Write operations: ~0.5μs
- Full render to ANSI: ~280μs
- Diff-based update: ~50μs

Target: All operations < 16ms for 60fps rendering.

## Package Ecosystem

Raxol Core is part of the modular Raxol framework:

- **raxol_core** (this package) - Buffer primitives
- **raxol_liveview** - Phoenix LiveView integration
- **raxol_plugin** - Plugin system
- **raxol** - Full framework (includes all packages)

### When to Use What

**Use `raxol_core` if you want:**
- Lightweight buffer operations only
- Custom rendering pipeline
- No framework dependencies
- DIY terminal integration

**Use `raxol_liveview` if you want:**
- Phoenix LiveView terminals
- Web-based terminal UIs
- Real-time updates

**Use `raxol` if you want:**
- Full terminal framework
- All features included
- Enterprise capabilities

## Examples

See the [examples directory](../../examples/core/) for:
- 01_hello_buffer - Basic buffer operations
- 02_box_drawing - Box drawing and styling
- 03_styled_text - Text styling
- 04_custom_renderer - Custom rendering

## Documentation

- [Buffer API](../../docs/core/BUFFER_API.md)
- [Getting Started](../../docs/getting-started/QUICKSTART.md)
- [Core Concepts](../../docs/getting-started/CORE_CONCEPTS.md)

## License

MIT License - See [LICENSE](../../LICENSE) for details

## Contributing

Contributions welcome! See [CONTRIBUTING.md](../../CONTRIBUTING.md)

## Credits

Built by [axol.io](https://axol.io) for [raxol.io](https://raxol.io)
