#!/usr/bin/env elixir

# Test cache effectiveness with multiple renders
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
    # Alternate between just 2 styles so we get cache hits
    style = if rem(x, 2) == 0, do: red_style, else: bold_style
    %Raxol.Terminal.Cell{char: "T", style: style}
  end
end

buffer = %{buffer | cells: cells}
renderer = CachedStyleRenderer.new(buffer)

IO.puts("=== Testing Cache Effectiveness ===")

# Reset and do first render
CachedStyleRenderer.reset_cache_stats()
result1 = CachedStyleRenderer.render(renderer)
stats1 = CachedStyleRenderer.get_cache_stats()

IO.puts("First render stats: #{inspect(stats1)}")
IO.puts("Expected: All misses (cache cold)")

# Second render - should have cache hits
result2 = CachedStyleRenderer.render(renderer)
stats2 = CachedStyleRenderer.get_cache_stats()

IO.puts("Second render stats: #{inspect(stats2)}")
IO.puts("Expected: Many cache hits")

# Calculate hit rate improvement
total_requests = stats2.cache_hits + stats2.cache_misses
if total_requests > 0 do
  hit_rate = stats2.cache_hits / total_requests * 100
  IO.puts("Overall cache hit rate: #{Float.round(hit_rate, 1)}%")

  if hit_rate > 50 do
    IO.puts("✓ Cache working effectively (#{hit_rate}% hit rate)")
  else
    IO.puts("⚠ Cache hit rate lower than expected: #{hit_rate}%")
  end
else
  IO.puts("⚠ No cache requests detected")
end

IO.puts("Results identical: #{result1 == result2}")