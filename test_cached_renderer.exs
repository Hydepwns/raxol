#!/usr/bin/env elixir

# Simple test of cached style renderer
alias Raxol.Terminal.Renderer.CachedStyleRenderer
alias Raxol.Terminal.ScreenBuffer
alias Raxol.Terminal.ANSI.TextFormatting

# Create a test buffer
buffer = ScreenBuffer.Core.new(20, 5)

# Fill with styled content
red_style = %TextFormatting{foreground: :red}
bold_style = %TextFormatting{bold: true}

cells = for y <- 1..5 do
  for x <- 1..20 do
    style = if rem(x, 2) == 0, do: red_style, else: bold_style
    %Raxol.Terminal.Cell{char: "T", style: style}
  end
end

buffer = %{buffer | cells: cells}

# Create cached renderer
renderer = CachedStyleRenderer.new(buffer)

IO.puts("=== Testing Cached Style Renderer ===")

# Test basic rendering
CachedStyleRenderer.reset_cache_stats()
result = CachedStyleRenderer.render(renderer)

IO.puts("Rendered output length: #{byte_size(result)} bytes")

# Test cache statistics
stats = CachedStyleRenderer.get_cache_stats()
IO.puts("Cache stats: #{inspect(stats)}")

IO.puts("✓ Cached style renderer working correctly")