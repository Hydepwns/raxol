#!/usr/bin/env elixir

# Test cache with stateful renderer usage
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

IO.puts("=== Testing Stateful Cache Usage ===")

# Let's test the internal render_with_cache_tracking directly
CachedStyleRenderer.reset_cache_stats()

# Call the internal function that returns both content and updated renderer
{content1, updated_renderer1} =
  CachedStyleRenderer.send(:render_with_cache_tracking, [renderer])

IO.puts("After first render:")
IO.puts("  Cache hits: #{updated_renderer1.cache_hits}")
IO.puts("  Cache misses: #{updated_renderer1.cache_misses}")

# Use the updated renderer for second render
{content2, updated_renderer2} =
  CachedStyleRenderer.send(:render_with_cache_tracking, [updated_renderer1])

IO.puts("After second render:")
IO.puts("  Cache hits: #{updated_renderer2.cache_hits}")
IO.puts("  Cache misses: #{updated_renderer2.cache_misses}")

total = updated_renderer2.cache_hits + updated_renderer2.cache_misses
if total > 0 do
  hit_rate = updated_renderer2.cache_hits / total * 100
  IO.puts("Overall hit rate: #{Float.round(hit_rate, 1)}%")

  if hit_rate > 50 do
    IO.puts("✓ Stateful cache working effectively")
  else
    IO.puts("⚠ Still low hit rate, investigating further...")
  end
end

IO.puts("Results identical: #{content1 == content2}")