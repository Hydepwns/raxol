# Migration Guide: DIY to Raxol

Already built your own terminal rendering? This guide shows how to integrate or migrate to Raxol.

## Table of Contents

- [Why Migrate?](#why-migrate)
- [Migration Strategies](#migration-strategies)
- [Adapting Your Buffer Format](#adapting-your-buffer-format)
- [Incremental Migration](#incremental-migration)
- [Feature Parity Checklist](#feature-parity-checklist)
- [Case Study: droodotfoo](#case-study-droodotfoo)

---

## Why Migrate?

You've built a working terminal renderer. Why consider Raxol?

### What Raxol Adds

**1. Phoenix LiveView Integration**

If you're rendering terminals in web apps, Raxol.LiveView handles:
- Buffer → HTML conversion
- CSS theming (5 built-in themes)
- Event handling (keyboard, mouse, paste)
- 60fps rendering optimizations

**2. Testing Utilities**

```elixir
# Your current testing (probably):
output = render_buffer(buffer)
assert output =~ "expected text"  # Fragile string matching

# With Raxol:
buffer = Buffer.write_at(buffer, 5, 3, "expected text")
cell = Buffer.get_cell(buffer, 5, 3)
assert cell.char == "e"  # Test actual data structure
```

**3. Performance Optimizations**

- Diff rendering (50x faster updates)
- Benchmarking suite
- Memory profiling
- Automated performance regression detection

**4. Documentation & Examples**

- Comprehensive API docs
- Cookbook recipes
- Working examples
- Active community

### What You Keep

**Your code.** Raxol is designed for incremental adoption:

```elixir
# Keep your existing code
MyApp.TerminalRenderer.render(your_buffer)

# Add Raxol for specific features
html = Raxol.LiveView.TerminalBridge.buffer_to_html(your_buffer)
```

---

## Migration Strategies

Choose the approach that fits your needs.

### Strategy 1: Side-by-Side (Lowest Risk)

Run both implementations, compare outputs:

```elixir
defmodule MyApp.Renderer do
  def render(data) do
    # Your implementation
    your_buffer = YourRenderer.create_buffer(data)
    your_output = YourRenderer.render(your_buffer)

    # Raxol implementation (parallel)
    raxol_buffer = RaxolAdapter.from_your_format(your_buffer)
    raxol_output = Raxol.Core.Buffer.to_string(raxol_buffer)

    # Compare (in dev/test)
    if Mix.env() != :prod do
      compare_outputs(your_output, raxol_output)
    end

    # Use your implementation (for now)
    your_output
  end
end
```

**Pros:**
- Zero risk to production
- Validate Raxol behavior
- Identify edge cases

**Cons:**
- Doubled rendering cost (dev/test only)
- Maintenance overhead

**When to use:** Validating migration, finding gaps

### Strategy 2: Feature Flagging

Gradually roll out Raxol to users:

```elixir
defmodule MyApp.Renderer do
  def render(data, opts \\ []) do
    use_raxol? = Keyword.get(opts, :use_raxol, false) ||
                 Application.get_env(:my_app, :raxol_enabled, false)

    if use_raxol? do
      render_with_raxol(data)
    else
      render_with_your_code(data)
    end
  end
end

# config/config.exs
config :my_app,
  raxol_enabled: System.get_env("RAXOL_ENABLED") == "true"
```

**Pros:**
- Gradual rollout (1% → 10% → 100%)
- Easy rollback
- A/B testing possible

**Cons:**
- Maintain both paths
- Feature flag complexity

**When to use:** Production migration with safety net

### Strategy 3: Module Replacement

Replace your module with Raxol adapter:

```elixir
# Before:
defmodule MyApp.Buffer do
  def create(width, height), do: # your code
  def write_at(buffer, x, y, text), do: # your code
end

# After:
defmodule MyApp.Buffer do
  # Delegate to Raxol
  defdelegate create(width, height), to: Raxol.Core.Buffer, as: :create_blank_buffer
  defdelegate write_at(buffer, x, y, text), to: Raxol.Core.Buffer
  defdelegate write_at(buffer, x, y, text, style), to: Raxol.Core.Buffer

  # Keep custom functions
  def your_special_function(buffer), do: # your code
end
```

**Pros:**
- Minimal code changes
- Keep existing API
- Gradual internal migration

**Cons:**
- API compatibility required
- May hide Raxol features

**When to use:** Drop-in replacement, minimal changes

### Strategy 4: Clean Break

Rewrite using Raxol from scratch:

```elixir
# Old code (delete):
defmodule MyApp.OldRenderer do
  # 500 lines of custom buffer code
end

# New code:
defmodule MyApp.Renderer do
  alias Raxol.Core.{Buffer, Box, Renderer}

  def render(data) do
    Buffer.create_blank_buffer(80, 24)
    |> Box.draw_box(0, 0, 80, 24, :single)
    |> Buffer.write_at(10, 5, data.title)
  end
end
```

**Pros:**
- Simplest long-term
- Full Raxol feature access
- No legacy code

**Cons:**
- Highest risk
- Requires comprehensive testing
- All-or-nothing

**When to use:** Small codebases, greenfield projects

---

## Adapting Your Buffer Format

Most DIY implementations use similar structures. Here's how to adapt.

### Common DIY Format

```elixir
# Your buffer (typical structure)
%{
  width: 80,
  height: 24,
  cells: [
    # Flat array of cells
    %{x: 0, y: 0, char: "H", fg: :cyan},
    %{x: 1, y: 0, char: "e", fg: :cyan},
    # ...
  ]
}
```

### Raxol Format

```elixir
# Raxol buffer (nested structure)
%{
  width: 80,
  height: 24,
  lines: [
    # Array of lines
    %{cells: [
      # Each line has cells
      %{char: "H", style: %{fg_color: :cyan}},
      %{char: "e", style: %{fg_color: :cyan}},
      # ...
    ]},
    # ...
  ]
}
```

### Adapter: Your Format → Raxol

```elixir
defmodule MyApp.BufferAdapter do
  @doc "Convert your buffer format to Raxol format"
  def to_raxol(your_buffer) do
    # Create blank Raxol buffer
    raxol_buffer = Raxol.Core.Buffer.create_blank_buffer(
      your_buffer.width,
      your_buffer.height
    )

    # Transfer cells
    Enum.reduce(your_buffer.cells, raxol_buffer, fn cell, buf ->
      style = convert_style(cell)
      Raxol.Core.Buffer.set_cell(buf, cell.x, cell.y, cell.char, style)
    end)
  end

  @doc "Convert your style format to Raxol style"
  defp convert_style(cell) do
    %{
      fg_color: cell.fg,
      bg_color: Map.get(cell, :bg),
      bold: Map.get(cell, :bold, false),
      italic: Map.get(cell, :italic, false),
      underline: Map.get(cell, :underline, false)
    }
  end
end
```

### Adapter: Raxol → Your Format

```elixir
defmodule MyApp.BufferAdapter do
  @doc "Convert Raxol buffer to your format (if needed)"
  def from_raxol(raxol_buffer) do
    cells =
      for {line, y} <- Enum.with_index(raxol_buffer.lines),
          {cell, x} <- Enum.with_index(line.cells) do
        %{
          x: x,
          y: y,
          char: cell.char,
          fg: cell.style[:fg_color],
          bg: cell.style[:bg_color],
          bold: cell.style[:bold] || false
        }
      end

    %{
      width: raxol_buffer.width,
      height: raxol_buffer.height,
      cells: cells
    }
  end
end
```

### Performance Consideration

**Adapters add overhead.** Benchmark both approaches:

```elixir
# Benchmark: Direct Raxol
{time_raxol, _} = :timer.tc(fn ->
  Raxol.Core.Buffer.create_blank_buffer(80, 24)
  |> Raxol.Core.Buffer.write_at(10, 5, "Test")
end)

# Benchmark: Adapter path
{time_adapter, _} = :timer.tc(fn ->
  your_buffer = YourRenderer.create_buffer(80, 24)
  raxol_buffer = BufferAdapter.to_raxol(your_buffer)
end)

IO.puts("Direct: #{time_raxol}μs, Adapter: #{time_adapter}μs")
# If adapter is > 2x slower, consider Strategy 3 or 4
```

---

## Incremental Migration

Step-by-step migration plan.

### Phase 1: Add Raxol Dependency (Week 1)

```elixir
# mix.exs
def deps do
  [
    {:raxol_core, "~> 2.0"},  # Start with just core
    # ... your other deps
  ]
end
```

Run tests, ensure no conflicts.

### Phase 2: Create Adapters (Week 1-2)

```elixir
# test/support/buffer_adapter_test.exs
defmodule MyApp.BufferAdapterTest do
  use ExUnit.Case

  test "converts your buffer to Raxol" do
    your_buffer = YourRenderer.create_buffer(10, 5)
    your_buffer = YourRenderer.write_at(your_buffer, 2, 3, "Hi")

    raxol_buffer = BufferAdapter.to_raxol(your_buffer)

    cell = Raxol.Core.Buffer.get_cell(raxol_buffer, 2, 3)
    assert cell.char == "H"
  end

  test "round-trip conversion preserves data" do
    original = YourRenderer.create_buffer(10, 5)
    original = YourRenderer.write_at(original, 2, 3, "Test")

    raxol = BufferAdapter.to_raxol(original)
    back = BufferAdapter.from_raxol(raxol)

    assert buffer_equal?(original, back)
  end
end
```

### Phase 3: Add LiveView Support (Week 2-3)

If you're using Phoenix:

```elixir
# mix.exs
def deps do
  [
    {:raxol_core, "~> 2.0"},
    {:raxol_liveview, "~> 2.0"},  # Add LiveView support
    # ...
  ]
end
```

```elixir
# lib/my_app_web/live/terminal_live.ex
defmodule MyAppWeb.TerminalLive do
  use MyAppWeb, :live_view

  def render(assigns) do
    ~H"""
    <.live_component
      module={Raxol.LiveView.TerminalComponent}
      id="terminal"
      buffer={@raxol_buffer}
      theme={:nord}
    />
    """
  end

  def handle_info(:update, socket) do
    # Your existing logic
    your_buffer = YourRenderer.update(socket.assigns.your_buffer)

    # Convert to Raxol for rendering
    raxol_buffer = BufferAdapter.to_raxol(your_buffer)

    {:noreply, assign(socket,
      your_buffer: your_buffer,
      raxol_buffer: raxol_buffer
    )}
  end
end
```

### Phase 4: Replace Components (Week 3-6)

Gradually replace custom components:

```elixir
# Week 3: Replace box drawing
# Before:
your_buffer = YourRenderer.draw_box(buffer, 0, 0, 10, 5)

# After:
raxol_buffer = Raxol.Core.Box.draw_box(buffer, 0, 0, 10, 5, :single)

# Week 4: Replace text rendering
# Before:
your_buffer = YourRenderer.write_colored(buffer, 5, 3, "Text", :cyan)

# After:
raxol_buffer = Raxol.Core.Buffer.write_at(buffer, 5, 3, "Text", %{fg_color: :cyan})

# Week 5: Replace diffing
# Before:
diff = YourRenderer.calculate_diff(old, new)

# After:
diff = Raxol.Core.Renderer.render_diff(old, new)
```

### Phase 5: Remove Old Code (Week 6+)

Once confidence is high:

```bash
# Archive old code (don't delete yet)
git mv lib/my_app/old_renderer.ex lib/my_app/archived/

# Update imports throughout codebase
# YourRenderer -> Raxol.Core.Buffer
# YourRenderer.Box -> Raxol.Core.Box

# Remove adapters (no longer needed)
git rm lib/my_app/buffer_adapter.ex
```

### Phase 6: Monitor & Optimize (Ongoing)

```elixir
# Add performance tracking
defmodule MyApp.RenderMetrics do
  def track_render(fun) do
    {time, result} = :timer.tc(fun)

    MyApp.Metrics.histogram("terminal.render_time_us", time)

    if time > 16_000 do
      Logger.warn("Slow render: #{time}μs")
    end

    result
  end
end
```

---

## Feature Parity Checklist

Ensure Raxol can do everything your code does.

### Buffer Operations

- [ ] Create buffer with dimensions
- [ ] Write text at coordinates
- [ ] Read cell at coordinates
- [ ] Clear buffer
- [ ] Resize buffer
- [ ] Fill rectangular area
- [ ] Copy region to another buffer

### Styling

- [ ] Foreground colors (16 basic)
- [ ] Background colors (16 basic)
- [ ] 256-color palette support
- [ ] RGB true color support
- [ ] Bold text
- [ ] Italic text
- [ ] Underline
- [ ] Strikethrough
- [ ] Reverse video
- [ ] Custom attributes

### Box Drawing

- [ ] Single-line boxes
- [ ] Double-line boxes
- [ ] Rounded corners
- [ ] Horizontal lines
- [ ] Vertical lines
- [ ] Custom line characters

### Rendering

- [ ] Full buffer render to string
- [ ] Diff rendering (only changed cells)
- [ ] ANSI escape code generation
- [ ] HTML output (for web)
- [ ] Cursor positioning

### Advanced Features

- [ ] Unicode support (grapheme clusters)
- [ ] Wide characters (CJK)
- [ ] Zero-width characters (combining diacritics)
- [ ] Emoji support
- [ ] Sixel graphics (if applicable)
- [ ] Custom rendering backends

### Performance

- [ ] < 1ms buffer operations
- [ ] < 16ms full renders (60fps)
- [ ] Memory efficient (< 100KB per buffer)
- [ ] Diff calculation < 2ms

**If any features are missing:** Open a GitHub issue! We'll add them or help you extend Raxol.

---

## Case Study: droodotfoo

Real-world example of DIY → Raxol migration.

### Their Setup (Before)

```elixir
# lib/droodotfoo/terminal_bridge.ex
defmodule Droodotfoo.TerminalBridge do
  use GenServer

  # Custom buffer format
  defstruct [:width, :height, :cells, :cache]

  # Custom HTML rendering
  def buffer_to_html(buffer) do
    # ~300 lines of conversion logic
  end

  # Custom diffing
  def calculate_diff(old, new) do
    # ~100 lines of diff algorithm
  end
end
```

### Pain Points

1. **Maintenance burden** - 500+ lines of buffer code to maintain
2. **No testing utilities** - Hard to test rendering logic
3. **Performance unknowns** - No benchmarking infrastructure
4. **Missing features** - Wanted more themes, better diffing

### Migration Approach (Recommended)

**Phase 1: LiveView Integration Only**

```elixir
# mix.exs
def deps do
  [
    {:raxol_liveview, "~> 2.0"},  # Just for HTML rendering
    # Keep their buffer code for now
  ]
end
```

**Phase 2: Adapter**

```elixir
defmodule Droodotfoo.RaxolAdapter do
  def to_raxol(droodotfoo_buffer) do
    # Convert their format to Raxol
    Raxol.Core.Buffer.create_blank_buffer(
      droodotfoo_buffer.width,
      droodotfoo_buffer.height
    )
    |> populate_from_droodotfoo(droodotfoo_buffer)
  end

  defp populate_from_droodotfoo(raxol_buffer, droodotfoo_buffer) do
    Enum.reduce(droodotfoo_buffer.cells, raxol_buffer, fn {coord, cell}, buf ->
      {x, y} = coord
      style = %{
        fg_color: cell.fg_color,
        bg_color: cell.bg_color,
        bold: cell.bold
      }
      Raxol.Core.Buffer.set_cell(buf, x, y, cell.char, style)
    end)
  end
end
```

**Phase 3: Replace HTML Rendering**

```elixir
# Before: 300 lines of custom code
Droodotfoo.TerminalBridge.buffer_to_html(buffer)

# After: One line
buffer
|> Droodotfoo.RaxolAdapter.to_raxol()
|> Raxol.LiveView.TerminalBridge.buffer_to_html()
```

**Result:**
- 300 lines deleted
- 5 built-in themes (vs 1 custom)
- Better performance (1.2ms vs 8ms avg)
- Easier testing

**Phase 4: (Optional) Full Migration**

Replace buffer implementation:

```elixir
# Delete custom buffer code (~200 lines)
# Use Raxol.Core.Buffer directly
buffer = Raxol.Core.Buffer.create_blank_buffer(80, 24)
```

### Lessons Learned

1. **Start with LiveView** - Biggest immediate value
2. **Keep adapters simple** - Don't optimize prematurely
3. **Measure everything** - Benchmark before/after
4. **Gradual rollout** - Feature flags in production
5. **Document differences** - Note any behavior changes

---

## Getting Help

### Common Questions

**Q: Will this break my existing code?**

A: No. Raxol can run alongside your code. Use adapters for gradual migration.

**Q: What if Raxol is missing a feature I need?**

A: Three options:
1. Keep that part of your code (use Raxol for other parts)
2. Extend Raxol with a plugin
3. Open a GitHub issue (we'll help add it)

**Q: How long does migration typically take?**

A: Depends on strategy:
- LiveView only: 1-2 days
- Partial migration: 2-4 weeks
- Full migration: 4-8 weeks

**Q: Can I contribute my adapter back to Raxol?**

A: Yes! We'd love to see it. Open a PR with your adapter in `lib/raxol/adapters/`.

### Resources

- **[Quickstart](./QUICKSTART.md)** - Get started quickly
- **[Core Concepts](./CORE_CONCEPTS.md)** - Understand architecture
- **[API Reference](../core/BUFFER_API.md)** - Complete function docs
- **[Cookbook](../cookbook/)** - Practical recipes
- **GitHub Issues** - Ask questions, request features

### Community Support

- Post in GitHub Discussions
- Join our Discord (coming soon)
- Tag @Hydepwns on Twitter/X

---

**Ready to migrate?** Start with Strategy 1 (side-by-side) to validate, then choose your path.

Good luck! We're here to help.
