# Raxol Core

Terminal buffer primitives. Zero dependencies, < 100KB.

## Install

```elixir
{:raxol_core, "~> 2.0"}
```

## Quick Start

```elixir
alias Raxol.Core.{Buffer, Box}

buffer = Buffer.create_blank_buffer(40, 10)
buffer = Box.draw_box(buffer, 0, 0, 40, 10, :double)
buffer = Buffer.write_at(buffer, 5, 4, "Hello!")
IO.puts(Buffer.to_string(buffer))
```

## Core APIs

### Buffer
- `create_blank_buffer(width, height)` - Create buffer
- `write_at(buffer, x, y, text)` - Write text
- `get_cell(buffer, x, y)` - Read cell
- `set_cell(buffer, x, y, char, style)` - Write cell
- `to_string(buffer)` - Render to string

### Renderer
- `render(buffer)` - Convert to ANSI output

### Box
- `draw_box(buffer, x, y, width, height, style)` - Draw box
- Styles: `:single`, `:double`, `:rounded`, `:bold`

### Style
- `apply_style(buffer, x, y, style)` - Apply styling
- Properties: `fg_color`, `bg_color`, `bold`, `italic`, `underline`

## Performance

- Buffer operations: < 1ms
- Render: ~264μs average
- Memory: < 100KB compiled

See [main docs](../../README.md) for examples and guides.
