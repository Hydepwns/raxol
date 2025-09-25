#!/usr/bin/env elixir

# Cached Style Renderer Benchmark
# Test the performance improvements from style string caching

defmodule CachedStyleRendererBenchmark do
  alias Raxol.Terminal.Renderer
  alias Raxol.Terminal.Renderer.CachedStyleRenderer
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.ANSI.TextFormatting

  def run do
    IO.puts("=== Cached Style Renderer Benchmark ===")
    IO.puts("Testing style string caching optimization (44.9% of render time)\n")

    # Test different scenarios
    test_cache_effectiveness()
    test_template_coverage()
    test_performance_comparison()
    generate_optimization_report()
  end

  defp test_cache_effectiveness do
    IO.puts("=== Cache Effectiveness Analysis ===")

    # Test scenarios with different cache hit patterns
    test_scenarios = [
      {"repeated_styles", create_repeated_styles_buffer()},
      {"mixed_styles", create_mixed_styles_buffer()},
      {"unique_styles", create_unique_styles_buffer()},
      {"template_styles", create_template_styles_buffer()}
    ]

    IO.puts("Scenario       | Cache Hit Rate | Templates Used | Performance Gain")
    IO.puts("---------------|----------------|----------------|------------------")

    Enum.each(test_scenarios, fn {name, buffer} ->
      CachedStyleRenderer.reset_cache_stats()

      # Render multiple times to see caching effect
      cached_renderer = CachedStyleRenderer.new(buffer)
      Enum.each(1..10, fn _ -> CachedStyleRenderer.render(cached_renderer) end)

      stats = CachedStyleRenderer.get_cache_stats()

      # Performance comparison
      performance_gain = measure_performance_gain(buffer)

      IO.puts("#{String.pad_trailing(name, 14)} | #{String.pad_leading(stats.hit_rate_percent |> to_string, 14)}% | #{String.pad_leading(stats.templates_available |> to_string, 14)} | #{performance_gain}")
    end)
  end

  defp test_template_coverage do
    IO.puts("\n=== Template Coverage Analysis ===")

    # Test how many common styles are covered by templates
    common_styles = [
      {"default", %TextFormatting{}},
      {"red_text", %TextFormatting{foreground: :red}},
      {"bold_text", %TextFormatting{bold: true}},
      {"bold_red", %TextFormatting{bold: true, foreground: :red}},
      {"underline_red", %TextFormatting{underline: true, foreground: :red}},
      {"complex_rgb", %TextFormatting{foreground: %{r: 255, g: 128, b: 64}}},
      {"full_sgr", %TextFormatting{bold: true, italic: true, underline: true, foreground: :blue, background: :yellow}}
    ]

    IO.puts("Style Type     | Template Hit | Render Time (μs) | Efficiency")
    IO.puts("---------------|--------------|------------------|------------")

    Enum.each(common_styles, fn {name, style} ->
      buffer = create_single_style_buffer(style)
      CachedStyleRenderer.reset_cache_stats()

      # Measure rendering time
      cached_renderer = CachedStyleRenderer.new(buffer)

      {time, _result} = :timer.tc(fn ->
        Enum.each(1..100, fn _ ->
          CachedStyleRenderer.render(cached_renderer)
        end)
      end)

      avg_time = time / 100
      stats = CachedStyleRenderer.get_cache_stats()

      template_hit = if stats.hit_rate_percent > 80, do: "✓", else: "✗"
      efficiency = if avg_time < 100, do: "HIGH", else: if avg_time < 500, do: "MEDIUM", else: "LOW"

      IO.puts("#{String.pad_trailing(name, 14)} | #{String.pad_leading(template_hit, 12)} | #{String.pad_leading(Float.round(avg_time, 1) |> to_string, 16)} | #{efficiency}")
    end)
  end

  defp test_performance_comparison do
    IO.puts("\n=== Performance Comparison ===")

    test_buffers = [
      {"small_styled", create_small_styled_buffer()},
      {"medium_mixed", create_medium_mixed_buffer()},
      {"large_full_screen", create_large_full_screen_buffer()}
    ]

    IO.puts("Buffer Type    | Original (μs) | Cached (μs) | Improvement | Target Met?")
    IO.puts("---------------|---------------|-------------|-------------|------------")

    Enum.each(test_buffers, fn {name, buffer} ->
      # Benchmark original renderer
      original_renderer = Renderer.new(buffer, %{}, %{}, false)
      original_time = benchmark_renderer(fn -> Renderer.render(original_renderer) end, 100)

      # Benchmark cached renderer
      cached_renderer = CachedStyleRenderer.new(buffer)
      cached_time = benchmark_renderer(fn -> CachedStyleRenderer.render(cached_renderer) end, 100)

      improvement = (original_time - cached_time) / original_time * 100
      target_met = if cached_time < 500, do: "✓", else: "✗"

      improvement_str = if improvement > 0, do: "+#{Float.round(improvement, 1)}%", else: "#{Float.round(improvement, 1)}%"

      IO.puts("#{String.pad_trailing(name, 14)} | #{String.pad_leading(Float.round(original_time, 1) |> to_string, 13)} | #{String.pad_leading(Float.round(cached_time, 1) |> to_string, 11)} | #{String.pad_leading(improvement_str, 11)} | #{target_met}")
    end)
  end

  defp generate_optimization_report do
    IO.puts("\n=== Style Caching Optimization Report ===")

    IO.puts("IMPLEMENTATION HIGHLIGHTS:")
    IO.puts("✓ Pre-compiled templates for 16 common style combinations")
    IO.puts("✓ LRU cache with efficient key generation")
    IO.puts("✓ Batch processing for consecutive identical styles")
    IO.puts("✓ Memory-efficient iolist-based string building")

    IO.puts("\nPERFORMANCE IMPACT:")
    # Quick overall test
    buffer = create_medium_mixed_buffer()
    original_renderer = Renderer.new(buffer, %{}, %{}, false)
    cached_renderer = CachedStyleRenderer.new(buffer)

    original_time = benchmark_renderer(fn -> Renderer.render(original_renderer) end, 50)
    cached_time = benchmark_renderer(fn -> CachedStyleRenderer.render(cached_renderer) end, 50)

    improvement = (original_time - cached_time) / original_time * 100

    IO.puts("  Overall performance improvement: #{if improvement > 0, do: "+", else: ""}#{Float.round(improvement, 1)}%")
    IO.puts("  Target achievement: #{if cached_time < 500, do: "✓ ACHIEVED", else: "✗ Need further optimization"}")

    stats = CachedStyleRenderer.get_cache_stats()
    IO.puts("  Cache hit rate: #{stats.hit_rate_percent}%")

    IO.puts("\nNEXT OPTIMIZATION TARGETS:")
    if cached_time >= 500 do
      IO.puts("1. Further template expansion for complex styles")
      IO.puts("2. Memory pool allocation for string building")
      IO.puts("3. Damage-only rendering implementation")
    else
      IO.puts("1. Move to memory pool optimization")
      IO.puts("2. Implement damage-only rendering")
      IO.puts("3. Begin binary pattern compilation")
    end

    IO.puts("\nRECOMMENDation:")
    if improvement > 30 do
      IO.puts("→ Deploy cached style renderer - significant improvement achieved")
    elsif improvement > 10 do
      IO.puts("→ Deploy with additional optimizations")
    else
      IO.puts("→ Investigate further bottlenecks before deployment")
    end
  end

  # Helper functions to create test buffers

  defp create_repeated_styles_buffer do
    # Buffer with many cells using the same few styles
    buffer = ScreenBuffer.Core.new(80, 8)

    red_style = %TextFormatting{foreground: :red}
    bold_style = %TextFormatting{bold: true}

    cells = for y <- 1..8 do
      for x <- 1..80 do
        style = if rem(x, 2) == 0, do: red_style, else: bold_style
        %Raxol.Terminal.Cell{char: "R", style: style}
      end
    end

    %{buffer | cells: cells}
  end

  defp create_mixed_styles_buffer do
    # Buffer with moderate style variety
    buffer = ScreenBuffer.Core.new(80, 8)

    styles = [
      %TextFormatting{foreground: :red},
      %TextFormatting{foreground: :green},
      %TextFormatting{bold: true},
      %TextFormatting{italic: true},
      %TextFormatting{bold: true, foreground: :blue}
    ]

    cells = for y <- 1..8 do
      for x <- 1..80 do
        style = Enum.at(styles, rem(x + y, length(styles)))
        %Raxol.Terminal.Cell{char: "M", style: style}
      end
    end

    %{buffer | cells: cells}
  end

  defp create_unique_styles_buffer do
    # Buffer where most cells have unique styles (worst case for caching)
    buffer = ScreenBuffer.Core.new(80, 8)

    cells = for y <- 1..8 do
      for x <- 1..80 do
        # Create unique RGB colors
        r = rem(x * 3, 256)
        g = rem(y * 7, 256)
        b = rem((x + y) * 5, 256)

        style = %TextFormatting{foreground: %{r: r, g: g, b: b}}
        %Raxol.Terminal.Cell{char: "U", style: style}
      end
    end

    %{buffer | cells: cells}
  end

  defp create_template_styles_buffer do
    # Buffer using only template-covered styles
    buffer = ScreenBuffer.Core.new(80, 8)

    template_styles = [
      %TextFormatting{},                              # default
      %TextFormatting{foreground: :red},              # red_fg
      %TextFormatting{bold: true},                    # bold
      %TextFormatting{bold: true, foreground: :red},  # bold_red
      %TextFormatting{underline: true, foreground: :red} # underline_red
    ]

    cells = for y <- 1..8 do
      for x <- 1..80 do
        style = Enum.at(template_styles, rem(x, length(template_styles)))
        %Raxol.Terminal.Cell{char: "T", style: style}
      end
    end

    %{buffer | cells: cells}
  end

  defp create_single_style_buffer(style) do
    buffer = ScreenBuffer.Core.new(20, 4)

    cells = for _y <- 1..4 do
      for _x <- 1..20 do
        %Raxol.Terminal.Cell{char: "S", style: style}
      end
    end

    %{buffer | cells: cells}
  end

  defp create_small_styled_buffer do
    create_single_style_buffer(%TextFormatting{bold: true, foreground: :red})
  end

  defp create_medium_mixed_buffer do
    create_mixed_styles_buffer()
  end

  defp create_large_full_screen_buffer do
    buffer = ScreenBuffer.Core.new(80, 24)

    cells = for y <- 1..24 do
      for x <- 1..80 do
        # Create varied but cacheable styles
        style = case rem(x + y, 6) do
          0 -> %TextFormatting{}
          1 -> %TextFormatting{foreground: :red}
          2 -> %TextFormatting{foreground: :green}
          3 -> %TextFormatting{bold: true}
          4 -> %TextFormatting{bold: true, foreground: :blue}
          5 -> %TextFormatting{italic: true}
        end

        %Raxol.Terminal.Cell{char: Integer.to_string(rem(x + y, 10)), style: style}
      end
    end

    %{buffer | cells: cells}
  end

  defp measure_performance_gain(buffer) do
    original_renderer = Renderer.new(buffer, %{}, %{}, false)
    cached_renderer = CachedStyleRenderer.new(buffer)

    original_time = benchmark_renderer(fn -> Renderer.render(original_renderer) end, 20)
    cached_time = benchmark_renderer(fn -> CachedStyleRenderer.render(cached_renderer) end, 20)

    improvement = (original_time - cached_time) / original_time * 100
    if improvement > 0, do: "+#{Float.round(improvement, 1)}%", else: "#{Float.round(improvement, 1)}%"
  end

  defp benchmark_renderer(render_fn, iterations) do
    # Warmup
    Enum.each(1..10, fn _ -> render_fn.() end)

    {time, _result} = :timer.tc(fn ->
      Enum.each(1..iterations, fn _ -> render_fn.() end)
    end)

    time / iterations
  end
end

# Run the benchmark
CachedStyleRendererBenchmark.run()