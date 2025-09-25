#!/usr/bin/env elixir

# Performance comparison between original and cached renderers
alias Raxol.Terminal.Renderer
alias Raxol.Terminal.Renderer.CachedStyleRenderer
alias Raxol.Terminal.ScreenBuffer
alias Raxol.Terminal.ANSI.TextFormatting

IO.puts("=== Phase 2 Render Performance Test ===")
IO.puts("Comparing original vs cached style renderer\n")

# Create test buffer with mixed styles
buffer = ScreenBuffer.Core.new(40, 10)

styles = [
  %TextFormatting{},                              # default - template hit
  %TextFormatting{foreground: :red},              # red_fg - template hit
  %TextFormatting{bold: true},                    # bold - template hit
  %TextFormatting{bold: true, foreground: :blue}, # cache miss, but reusable
  %TextFormatting{italic: true, foreground: :green} # cache miss, but reusable
]

cells = for y <- 1..10 do
  for x <- 1..40 do
    style = Enum.at(styles, rem(x, length(styles)))
    %Raxol.Terminal.Cell{char: Integer.to_string(rem(x, 10)), style: style}
  end
end

buffer = %{buffer | cells: cells}

# Create renderers
original_renderer = Renderer.new(buffer, %{}, %{}, false)
cached_renderer = CachedStyleRenderer.new(buffer)

IO.puts("Test buffer: 40x10 = 400 cells with 5 different styles")

# Benchmark original renderer
IO.puts("\nTesting Original Renderer...")
{original_time, _result} = :timer.tc(fn ->
  Enum.each(1..100, fn _ ->
    Renderer.render(original_renderer)
  end)
end)

original_avg = original_time / 100
IO.puts("Original renderer: #{Float.round(original_avg, 1)} μs/render")

# Benchmark cached renderer
IO.puts("\nTesting Cached Style Renderer...")
CachedStyleRenderer.reset_cache_stats()

{cached_time, _result} = :timer.tc(fn ->
  Enum.each(1..100, fn _ ->
    CachedStyleRenderer.render(cached_renderer)
  end)
end)

cached_avg = cached_time / 100
stats = CachedStyleRenderer.get_cache_stats()

IO.puts("Cached renderer: #{Float.round(cached_avg, 1)} μs/render")
IO.puts("Cache hit rate: #{stats.hit_rate_percent}%")

# Calculate improvement
improvement = (original_avg - cached_avg) / original_avg * 100
target_met = cached_avg < 500

IO.puts("\n=== Results ===")
IO.puts("Performance improvement: #{if improvement > 0, do: "+", else: ""}#{Float.round(improvement, 1)}%")
IO.puts("Target <500μs: #{if target_met, do: "✓ ACHIEVED", else: "✗ Need #{Float.round(cached_avg - 500, 1)}μs more improvement"}")

if improvement > 20 do
  IO.puts("Status: Significant improvement - deploy cached renderer")
elsif improvement > 0 do
  IO.puts("Status: Modest improvement - consider deployment")
else
  IO.puts("Status: No improvement - investigate bottlenecks")
end