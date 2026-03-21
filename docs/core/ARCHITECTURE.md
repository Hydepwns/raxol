# Architecture

Design decisions and implementation details for Raxol.Core.

## Design Philosophy

### Pure Functional Design

All modules use pure functions with immutable data structures. Every function returns a new buffer, never mutates the original.

```elixir
def write_at(buffer, x, y, content, style) do
  # Create new cells, lines, and buffer
  # Original buffer unchanged
end
```

Trade-offs: safety, testability, and concurrency at the cost of memory allocations (mitigated by BEAM optimization).

### Zero Dependencies

Raxol.Core has no runtime dependencies beyond Elixir stdlib. Only uses Enum, List, Map, String. Under 100KB, no version conflicts, fast compilation.

### Performance First

Target < 1ms for all operations on standard buffers. 60fps requires < 16ms frame budget, and we want headroom for user code.

Measured results:
- Buffer operations: 0.001-0.5ms
- Render diff: ~2ms (80x24 buffer)
- Box drawing: 0.04-0.6ms
- Style generation: < 0.1ms

### Fail-Safe Boundaries

Out-of-bounds operations are silently ignored, never crash:

```elixir
def set_cell(buffer, x, y, char, style) do
  cond do
    y >= height or y < 0 -> buffer  # No-op
    x >= width or x < 0 -> buffer   # No-op
    true -> do_update(buffer, x, y, char, style)
  end
end
```

This means less defensive code for users, but silent failures can hide bugs. Use debug mode if that's a concern.

---

## Module Architecture

### Buffer Module

Core data structure and basic operations.

```elixir
%{
  lines: [%{cells: [%{char: "A", style: %{...}}]}],
  width: 80,
  height: 24
}
```

Uses a list of lines, each containing a list of cells. Elixir lists are optimized for sequential access, most rendering is line-by-line, and it maps naturally to terminal output. A flat array with index math was considered but rejected as less idiomatic.

### Renderer Module

Converts buffers to output strings. The key algorithm is diff rendering:

```elixir
def render_diff(old_buffer, new_buffer) do
  old_buffer.lines
  |> Enum.zip(new_buffer.lines)
  |> Enum.with_index()
  |> Enum.filter(fn {{old_line, new_line}, _} -> old_line != new_line end)
  |> Enum.map(fn {{_, new_line}, y} ->
    "\e[#{y + 1};1H" <> line_to_string(new_line)
  end)
end
```

Uses Enum.zip for single-pass comparison. Under 2ms for 80x24 buffers.

### Style Module

Style management and ANSI escape code generation. Supports named colors, 256-color palette, and RGB:

```elixir
defp color_to_ansi(:red, :fg), do: "31"
defp color_to_ansi(n, :fg) when is_integer(n), do: "38;5;#{n}"
defp color_to_ansi({r, g, b}, :fg), do: "38;2;#{r};#{g};#{b}"
```

Style merging uses simple map merge with last-wins semantics.

### Box Module

Higher-level drawing utilities using Unicode box-drawing characters. Builds complex shapes from simple operations:

```elixir
def draw_box(buffer, x, y, width, height, style) do
  chars = box_chars(style)
  buffer
  |> draw_corners(x, y, width, height, chars)
  |> draw_edges(x, y, width, height, chars)
end
```

Character sets: single (---+), double (===+), rounded, heavy, dashed.

---

## Performance Optimizations

**Lazy line updates.** Only modified lines are included in diffs. ~50% reduction in diff size for typical updates.

**Pattern matching guards.** Fast validation at the BEAM level:

```elixir
def set_cell(buffer, x, y, char, style)
    when x >= 0 and y >= 0 and x < buffer.width and y < buffer.height do
  # Hot path - no branching
end

def set_cell(buffer, _, _, _, _), do: buffer
```

**Structural sharing.** Elixir's persistent data structures share unchanged subtrees:

```elixir
new_buffer = %{buffer | lines: updated_lines}
# Shares all unchanged lines with old buffer
```

---

## Memory Management

For an 80x24 buffer: 24 lines x 80 cells x ~100 bytes/cell = ~192KB. Actual usage is typically 50-100KB due to structural sharing and BEAM optimization.

Immutable buffers become garbage when replaced. BEAM GC is per-process and generational, so old buffers are collected quickly if not referenced. Don't hold onto old buffers in history lists unless you need them.

---

## Design Patterns

**Pipeline pattern.** Chain buffer operations with `|>`.

**Builder pattern.** Construct complex UIs from small focused functions (`add_header`, `add_sidebar`, etc.).

**Renderer pattern.** Separate data from presentation -- components take buffer + state and return updated buffer.

---

## Error Handling

Valid operations never throw. Bounds checking returns buffer unchanged, invalid styles use defaults, empty strings are handled gracefully. Types are validated through pattern matching and guards.

---

## Comparison with Alternatives

**vs Raw ANSI** - Raxol adds buffer abstraction, diff rendering, type safety, testability. Raw ANSI gives lower-level control and smaller code size.

**vs ncurses** - Raxol is pure Elixir (no C deps), functional, lightweight, thread-safe. ncurses has more features, decades of optimization, wider platform support.

---

## References

- [Buffer API Reference](./BUFFER_API.md)
- [ANSI Escape Codes](https://en.wikipedia.org/wiki/ANSI_escape_code)
- [Box Drawing Characters](https://en.wikipedia.org/wiki/Box-drawing_character)
