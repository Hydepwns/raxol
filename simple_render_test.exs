alias Raxol.Terminal.Renderer
alias Raxol.Terminal.Renderer.CachedStyleRenderer
alias Raxol.Terminal.ScreenBuffer
alias Raxol.Terminal.ANSI.TextFormatting

IO.puts("=== Simple Render Performance Test ===")

# Create test buffer
buffer = ScreenBuffer.Core.new(10, 3)
red_style = %TextFormatting{foreground: :red}

cells = for _y <- 1..3 do
  for _x <- 1..10 do
    %Raxol.Terminal.Cell{char: "A", style: red_style}
  end
end

buffer = %{buffer | cells: cells}

# Test original renderer
original_renderer = Renderer.new(buffer, %{}, %{}, false)
{orig_time, _} = :timer.tc(fn ->
  Enum.each(1..50, fn _ -> Renderer.render(original_renderer) end)
end)
orig_avg = orig_time / 50

# Test cached renderer
cached_renderer = CachedStyleRenderer.new(buffer)
CachedStyleRenderer.reset_cache_stats()
{cached_time, _} = :timer.tc(fn ->
  Enum.each(1..50, fn _ -> CachedStyleRenderer.render(cached_renderer) end)
end)
cached_avg = cached_time / 50

stats = CachedStyleRenderer.get_cache_stats()
improvement = (orig_avg - cached_avg) / orig_avg * 100

IO.puts("Original: #{Float.round(orig_avg, 1)} μs")
IO.puts("Cached: #{Float.round(cached_avg, 1)} μs")
IO.puts("Improvement: #{Float.round(improvement, 1)}%")
IO.puts("Hit rate: #{stats.hit_rate_percent}%")
IO.puts("Target <500μs: #{if cached_avg < 500, do: "✓", else: "✗"}")