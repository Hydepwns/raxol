# Buffer API Reference

> [Documentation](../README.md) > [Core](../README.md#core-library) > Buffer API

Complete API documentation for the Raxol.Core buffer primitives.

## Overview

The Raxol.Core package provides lightweight, zero-dependency terminal buffer operations designed for standalone use or as a foundation for higher-level abstractions.

## Modules

### Raxol.Core.Buffer

Pure functional buffer operations for terminal rendering.

#### Types

```elixir
@type cell :: %{
  char: String.t(),
  style: map()
}

@type line :: %{cells: list(cell())}

@type t :: %{
  lines: list(line()),
  width: non_neg_integer(),
  height: non_neg_integer()
}
```

#### Functions

##### create_blank_buffer/2

```elixir
@spec create_blank_buffer(non_neg_integer(), non_neg_integer()) :: t()
```

Creates a blank buffer with the specified dimensions.

**Parameters:**
- `width` - Width of the buffer in characters
- `height` - Height of the buffer in lines

**Returns:** A new buffer with all cells initialized to blank spaces

**Example:**
```elixir
buffer = Raxol.Core.Buffer.create_blank_buffer(80, 24)
# => %{lines: [...], width: 80, height: 24}
```

**Performance:** < 1ms for standard 80x24 buffer

---

##### write_at/5

```elixir
@spec write_at(t(), non_neg_integer(), non_neg_integer(), String.t(), map()) :: t()
```

Writes text at the specified coordinates with optional styling.

**Parameters:**
- `buffer` - The buffer to write to
- `x` - X coordinate (column, 0-indexed)
- `y` - Y coordinate (row, 0-indexed)
- `content` - Text to write (will be split into graphemes)
- `style` - Optional style map (default: %{})

**Returns:** Updated buffer with text written

**Example:**
```elixir
buffer = Raxol.Core.Buffer.create_blank_buffer(80, 24)
buffer = Raxol.Core.Buffer.write_at(buffer, 5, 3, "Hello, World!")
buffer = Raxol.Core.Buffer.write_at(buffer, 5, 4, "Styled text", %{bold: true, fg_color: :blue})
```

**Notes:**
- Text wraps character-by-character, no automatic line breaks
- Out-of-bounds writes are silently ignored
- Unicode graphemes are supported

**Performance:** < 1ms for typical strings

---

##### get_cell/3

```elixir
@spec get_cell(t(), non_neg_integer(), non_neg_integer()) :: cell() | nil
```

Retrieves the cell at the specified coordinates.

**Parameters:**
- `buffer` - The buffer to read from
- `x` - X coordinate (column)
- `y` - Y coordinate (row)

**Returns:** Cell at position, or `nil` if out of bounds

**Example:**
```elixir
buffer = Raxol.Core.Buffer.write_at(buffer, 5, 3, "A")
cell = Raxol.Core.Buffer.get_cell(buffer, 5, 3)
# => %{char: "A", style: %{}}

cell = Raxol.Core.Buffer.get_cell(buffer, 1000, 1000)
# => nil
```

**Performance:** O(1) access time

---

##### set_cell/5

```elixir
@spec set_cell(t(), non_neg_integer(), non_neg_integer(), String.t(), map()) :: t()
```

Updates a single cell at the specified coordinates.

**Parameters:**
- `buffer` - The buffer to update
- `x` - X coordinate (column)
- `y` - Y coordinate (row)
- `char` - Character to set (single grapheme)
- `style` - Style to apply

**Returns:** Updated buffer

**Example:**
```elixir
buffer = Raxol.Core.Buffer.set_cell(buffer, 10, 5, "█", %{bg_color: :red})
```

**Notes:**
- Out-of-bounds updates are silently ignored
- More efficient than `write_at` for single characters

**Performance:** < 100μs

---

##### clear/1

```elixir
@spec clear(t()) :: t()
```

Clears the buffer, resetting all cells to blank.

**Parameters:**
- `buffer` - The buffer to clear

**Returns:** New buffer with same dimensions, all cells blank

**Example:**
```elixir
buffer = Raxol.Core.Buffer.clear(buffer)
```

**Performance:** Same as `create_blank_buffer/2`

---

##### resize/3

```elixir
@spec resize(t(), non_neg_integer(), non_neg_integer()) :: t()
```

Resizes the buffer to new dimensions.

**Parameters:**
- `buffer` - The buffer to resize
- `width` - New width
- `height` - New height

**Returns:** Resized buffer

**Example:**
```elixir
# Expand buffer
buffer = Raxol.Core.Buffer.resize(buffer, 120, 40)

# Shrink buffer (content is cropped)
buffer = Raxol.Core.Buffer.resize(buffer, 40, 20)
```

**Behavior:**
- Expanding: New cells are filled with blank spaces
- Shrinking: Content is cropped from bottom and right
- Existing content is preserved where it fits

**Performance:** < 2ms for standard sizes

---

##### to_string/1

```elixir
@spec to_string(t()) :: String.t()
```

Converts the buffer to a string representation for debugging.

**Parameters:**
- `buffer` - The buffer to convert

**Returns:** Multi-line string showing buffer contents

**Example:**
```elixir
buffer = Raxol.Core.Buffer.create_blank_buffer(10, 3)
buffer = Raxol.Core.Buffer.write_at(buffer, 0, 0, "Hello")
buffer = Raxol.Core.Buffer.write_at(buffer, 0, 1, "World")

IO.puts(Raxol.Core.Buffer.to_string(buffer))
# Output:
# Hello
# World
#
```

**Notes:**
- Styles are not rendered (use Raxol.Core.Renderer for styled output)
- Useful for testing and debugging
- Each line ends with a newline

**Performance:** < 1ms for standard buffers

---

### Raxol.Core.Renderer

Pure functional rendering and diffing operations.

#### Functions

##### render_to_string/1

```elixir
@spec render_to_string(Buffer.t()) :: String.t()
```

Renders buffer to plain ASCII string (no ANSI codes).

**Parameters:**
- `buffer` - The buffer to render

**Returns:** String representation

**Example:**
```elixir
output = Raxol.Core.Renderer.render_to_string(buffer)
IO.puts(output)
```

**Performance:** < 1ms for 80x24 buffer

---

##### render_diff/2

```elixir
@spec render_diff(Buffer.t(), Buffer.t()) :: list(String.t())
```

Calculates minimal updates between two buffers.

**Parameters:**
- `old_buffer` - Previous buffer state
- `new_buffer` - New buffer state

**Returns:** List of ANSI cursor positioning and update sequences

**Example:**
```elixir
old_buffer = Raxol.Core.Buffer.create_blank_buffer(80, 24)
new_buffer = Raxol.Core.Buffer.write_at(old_buffer, 5, 3, "Changed!")

diff = Raxol.Core.Renderer.render_diff(old_buffer, new_buffer)
# => ["\e[4;6HChanged!"]  # Only updates changed cells
```

**Optimization:**
- Only generates updates for changed lines
- Uses efficient Enum.zip for line comparison
- Minimal ANSI escape sequences

**Performance:** < 2ms for 80x24 buffer (target met in benchmarks)

---

### Raxol.Core.Style

Style management and ANSI escape code generation.

#### Functions

##### new/1

```elixir
@spec new(keyword()) :: map()
```

Creates a new style map with validation.

**Parameters:**
- `opts` - Keyword list of style options

**Returns:** Validated style map

**Options:**
- `:bold` - Boolean
- `:italic` - Boolean
- `:underline` - Boolean
- `:fg_color` - Foreground color (atom, RGB tuple, or integer)
- `:bg_color` - Background color (atom, RGB tuple, or integer)

**Example:**
```elixir
style = Raxol.Core.Style.new(bold: true, fg_color: :blue)
# => %{bold: true, fg_color: :blue}
```

---

##### merge/2

```elixir
@spec merge(map(), map()) :: map()
```

Merges two style maps (second overrides first).

**Example:**
```elixir
base = Raxol.Core.Style.new(bold: true, fg_color: :blue)
override = Raxol.Core.Style.new(fg_color: :red)
result = Raxol.Core.Style.merge(base, override)
# => %{bold: true, fg_color: :red}
```

---

##### rgb/3

```elixir
@spec rgb(0..255, 0..255, 0..255) :: {non_neg_integer(), non_neg_integer(), non_neg_integer()}
```

Creates an RGB color tuple.

**Example:**
```elixir
color = Raxol.Core.Style.rgb(255, 100, 50)
style = Raxol.Core.Style.new(fg_color: color)
```

---

##### color_256/1

```elixir
@spec color_256(0..255) :: non_neg_integer()
```

Creates a 256-color palette index.

**Example:**
```elixir
color = Raxol.Core.Style.color_256(196)  # Bright red
style = Raxol.Core.Style.new(bg_color: color)
```

---

##### named_color/1

```elixir
@spec named_color(atom()) :: atom()
```

Validates named colors.

**Supported Colors:**
`:black`, `:red`, `:green`, `:yellow`, `:blue`, `:magenta`, `:cyan`, `:white`

**Example:**
```elixir
color = Raxol.Core.Style.named_color(:blue)
```

---

##### to_ansi/1

```elixir
@spec to_ansi(map()) :: String.t()
```

Converts style to ANSI escape codes.

**Example:**
```elixir
style = Raxol.Core.Style.new(bold: true, fg_color: :blue)
ansi = Raxol.Core.Style.to_ansi(style)
# => "\e[1;34m"
```

---

### Raxol.Core.Box

Box drawing and area fill utilities.

#### Types

```elixir
@type box_style :: :single | :double | :rounded | :heavy | :dashed
```

#### Functions

##### draw_box/6

```elixir
@spec draw_box(Buffer.t(), non_neg_integer(), non_neg_integer(),
               non_neg_integer(), non_neg_integer(), box_style()) :: Buffer.t()
```

Draws a box at the specified coordinates.

**Parameters:**
- `buffer` - The buffer to draw on
- `x` - X coordinate (left edge)
- `y` - Y coordinate (top edge)
- `width` - Width of the box
- `height` - Height of the box
- `style` - Box style (default: `:single`)

**Box Styles:**
- `:single` - Single line (─│┌┐└┘)
- `:double` - Double line (═║╔╗╚╝)
- `:rounded` - Rounded corners (─│╭╮╰╯)
- `:heavy` - Heavy/bold lines (━┃┏┓┗┛)
- `:dashed` - Dashed lines (╌╎┌┐└┘)

**Example:**
```elixir
buffer = Raxol.Core.Box.draw_box(buffer, 5, 3, 30, 10, :double)
```

**Performance:** 38-588μs depending on size and style

---

##### draw_horizontal_line/5

```elixir
@spec draw_horizontal_line(Buffer.t(), non_neg_integer(), non_neg_integer(),
                           non_neg_integer(), String.t()) :: Buffer.t()
```

Draws a horizontal line.

**Parameters:**
- `buffer` - The buffer to draw on
- `x` - Starting X coordinate
- `y` - Y coordinate (row)
- `length` - Length of the line
- `char` - Character to use (default: "-")

**Example:**
```elixir
buffer = Raxol.Core.Box.draw_horizontal_line(buffer, 0, 0, 80, "=")
```

**Performance:** ~10μs for 20 characters

---

##### draw_vertical_line/5

```elixir
@spec draw_vertical_line(Buffer.t(), non_neg_integer(), non_neg_integer(),
                         non_neg_integer(), String.t()) :: Buffer.t()
```

Draws a vertical line.

**Parameters:**
- `buffer` - The buffer to draw on
- `x` - X coordinate (column)
- `y` - Starting Y coordinate
- `length` - Length of the line
- `char` - Character to use (default: "|")

**Example:**
```elixir
buffer = Raxol.Core.Box.draw_vertical_line(buffer, 40, 0, 24, "║")
```

**Performance:** ~8μs for 10 characters

---

##### fill_area/7

```elixir
@spec fill_area(Buffer.t(), non_neg_integer(), non_neg_integer(),
                non_neg_integer(), non_neg_integer(), String.t(), map()) :: Buffer.t()
```

Fills a rectangular area with a character and style.

**Parameters:**
- `buffer` - The buffer to draw on
- `x` - X coordinate (left edge)
- `y` - Y coordinate (top edge)
- `width` - Width of the area
- `height` - Height of the area
- `char` - Character to fill with
- `style` - Style to apply (default: %{})

**Example:**
```elixir
# Fill with background color
buffer = Raxol.Core.Box.fill_area(buffer, 10, 5, 20, 10, " ", %{bg_color: :blue})

# Fill with pattern
buffer = Raxol.Core.Box.fill_area(buffer, 10, 5, 20, 10, "░", %{})
```

**Performance:** ~44μs for 10x10 area, ~1.3ms for full 80x24 buffer

---

## Performance Targets

All operations designed to complete in < 1ms for standard 80x24 buffers:

| Operation | Target | Actual (avg) | Status |
|-----------|--------|--------------|--------|
| create_blank_buffer | < 1ms | ~0.5ms | ✅ |
| write_at (short string) | < 1ms | ~0.1ms | ✅ |
| get_cell | < 1ms | ~0.001ms | ✅ |
| set_cell | < 1ms | ~0.1ms | ✅ |
| clear | < 1ms | ~0.5ms | ✅ |
| resize | < 2ms | ~1ms | ✅ |
| to_string | < 1ms | ~0.5ms | ✅ |
| render_diff | < 2ms | ~2ms | ✅ |
| draw_box | < 1ms | 0.04-0.6ms | ✅ |
| draw_line | < 1ms | 0.01ms | ✅ |
| fill_area (small) | < 1ms | 0.04ms | ✅ |

See `bench/core/` for detailed benchmarks.

## Error Handling

All functions use defensive programming:
- Out-of-bounds coordinates are silently ignored
- Invalid dimensions default to minimum viable values
- No exceptions thrown for normal usage
- Pattern matching validates input types at compile time

## Thread Safety

All modules are pure functional - no shared state:
- Safe for concurrent use
- No GenServers or processes
- Immutable data structures throughout
- Can be used in any context (LiveView, Phoenix, CLI, scripts)

## See Also

- [Getting Started Guide](./GETTING_STARTED.md)
- [Architecture Documentation](./ARCHITECTURE.md)
- [Examples](../../examples/core/README.md)
- [Benchmarks](../../docs/bench/README.md)
