#!/usr/bin/env elixir

# Test cache with proper stateful API
alias Raxol.Terminal.Renderer.CachedStyleRenderer
alias Raxol.Terminal.ScreenBuffer
alias Raxol.Terminal.ANSI.TextFormatting

# Create a test buffer with repeating styles
buffer = ScreenBuffer.Core.new(20, 5)

# Create just 2 different styles to test caching
red_style = %TextFormatting{foreground: :red}
bold_style = %TextFormatting{bold: true}

cells = for y <- 1..5 do
  for x <- 1..20 do
    style = if rem(x, 2) == 0, do: red_style, else: bold_style
    %Raxol.Terminal.Cell{char: "T", style: style}
  end
end

buffer = %{buffer | cells: cells}
renderer = CachedStyleRenderer.new(buffer)

IO.puts("=== Testing Proper Stateful Cache API ===")

CachedStyleRenderer.reset_cache_stats()

# First render - cache cold
{content1, renderer1} = CachedStyleRenderer.render_with_state(renderer)
IO.puts("After first render:")
IO.puts("  Cache size: #{map_size(renderer1.style_cache)}")
IO.puts("  Cache hits: #{renderer1.cache_hits}")
IO.puts("  Cache misses: #{renderer1.cache_misses}")

# Second render - should have cache hits
{content2, renderer2} = CachedStyleRenderer.render_with_state(renderer1)
IO.puts("After second render:")
IO.puts("  Cache size: #{map_size(renderer2.style_cache)}")
IO.puts("  Cache hits: #{renderer2.cache_hits}")
IO.puts("  Cache misses: #{renderer2.cache_misses}")

# Calculate overall statistics
total = renderer2.cache_hits + renderer2.cache_misses
if total > 0 do
  hit_rate = renderer2.cache_hits / total * 100
  IO.puts("Overall cache hit rate: #{Float.round(hit_rate, 1)}%")

  if hit_rate > 50 do
    IO.puts("✓ Cache working effectively! Hit rate: #{Float.round(hit_rate, 1)}%")
  else
    IO.puts("⚠ Cache hit rate still low: #{Float.round(hit_rate, 1)}%")
    IO.puts("Debug: Only #{renderer2.cache_hits} hits vs #{renderer2.cache_misses} misses")
  end
else
  IO.puts("⚠ No cache activity detected")
end

IO.puts("Results identical: #{content1 == content2}")
IO.puts("Cache preserved: #{map_size(renderer2.style_cache) > 0}")