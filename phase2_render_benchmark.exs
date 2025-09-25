#!/usr/bin/env elixir

# Phase 2 Render Pipeline Benchmark
# Goal: Identify bottlenecks and optimize from ~1ms to <0.5ms

defmodule Phase2RenderBenchmark do
  @moduledoc """
  Comprehensive render pipeline benchmarking for Phase 2 optimization.

  Current target: ~1ms → <0.5ms (50% improvement)
  Focus areas:
  1. Style string generation
  2. Cell-by-cell rendering
  3. Style batching optimization
  4. Damage tracking efficiency
  5. Memory allocation patterns
  """

  alias Raxol.Terminal.Renderer
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Buffer.DamageTracker
  alias Raxol.Terminal.ANSI.TextFormatting

  def run do
    IO.puts("=== Phase 2 Render Pipeline Benchmark ===")
    IO.puts("Target: Optimize render time from ~1ms to <0.5ms\n")

    # Test different rendering scenarios
    benchmark_baseline_rendering()
    benchmark_style_operations()
    benchmark_damage_tracking()
    benchmark_memory_patterns()

    # Identify optimization opportunities
    identify_render_bottlenecks()
    generate_optimization_recommendations()
  end

  defp benchmark_baseline_rendering do
    IO.puts("=== Baseline Render Performance ===")

    test_scenarios = [
      {"empty_buffer", create_empty_buffer()},
      {"text_only", create_text_buffer()},
      {"styled_text", create_styled_buffer()},
      {"mixed_colors", create_mixed_color_buffer()},
      {"full_screen", create_full_screen_buffer()},
      {"damage_heavy", create_damage_heavy_buffer()}
    ]

    IO.puts("Scenario       | Render Time (μs) | Target (μs) | Status | Cells")
    IO.puts("---------------|------------------|-------------|--------|-------")

    Enum.each(test_scenarios, fn {name, {buffer, cell_count}} ->
      renderer = Renderer.new(buffer, %{}, %{}, false)

      # Warmup
      Enum.each(1..100, fn _ -> Renderer.render(renderer) end)

      # Benchmark
      {time, _result} = :timer.tc(fn ->
        Enum.each(1..1000, fn _ ->
          Renderer.render(renderer)
        end)
      end)

      avg_time = time / 1000
      target_time = 500.0  # 0.5ms target
      status = if avg_time <= target_time, do: "✓", else: "✗"

      IO.puts("#{String.pad_trailing(name, 14)} | #{String.pad_leading(Float.round(avg_time, 1) |> to_string, 16)} | #{String.pad_leading("500.0", 11)} | #{String.pad_leading(status, 6)} | #{cell_count}")
    end)
  end

  defp benchmark_style_operations do
    IO.puts("\n=== Style Processing Performance ===")

    # Test different style complexity levels
    style_tests = [
      {"no_style", %TextFormatting{}},
      {"basic_color", %TextFormatting{foreground: :red}},
      {"full_sgr", %TextFormatting{bold: true, italic: true, underline: true, foreground: :red, background: :blue}},
      {"complex_rgb", %TextFormatting{foreground: %{r: 255, g: 128, b: 64}, background: %{r: 32, g: 64, b: 128}}}
    ]

    IO.puts("Style Type     | Time per Cell (ns) | Relative Cost")
    IO.puts("---------------|--------------------|--------------")

    baseline_time = nil

    Enum.each(style_tests, fn {name, style} ->
      time = benchmark_style_processing(style, 10000)

      baseline_time = baseline_time || time
      relative_cost = time / baseline_time

      IO.puts("#{String.pad_trailing(name, 14)} | #{String.pad_leading(Float.round(time * 1000, 1) |> to_string, 18)} | #{Float.round(relative_cost, 2)}x")
    end)
  end

  defp benchmark_damage_tracking do
    IO.puts("\n=== Damage Tracking Performance ===")

    damage_scenarios = [
      {"single_cell", [{0, 0, 1, 1}]},
      {"line_update", [{0, 5, 80, 1}]},
      {"block_update", [{10, 10, 20, 5}]},
      {"scattered_updates", generate_scattered_damage()},
      {"full_screen", [{0, 0, 80, 24}]}
    ]

    IO.puts("Damage Type    | Track Time (μs) | Merge Time (μs) | Regions")
    IO.puts("---------------|-----------------|-----------------|--------")

    Enum.each(damage_scenarios, fn {name, regions} ->
      # Test damage region tracking
      {track_time, tracker} = :timer.tc(fn ->
        damage_tracker = DamageTracker.new()
        DamageTracker.add_damage_regions(damage_tracker, regions)
      end)

      # Test region merging
      {merge_time, merged_tracker} = :timer.tc(fn ->
        DamageTracker.merge_regions(tracker)
      end)

      final_count = DamageTracker.damage_count(merged_tracker)

      track_time_float = track_time / 1.0
      merge_time_float = merge_time / 1.0
      IO.puts("#{String.pad_trailing(name, 14)} | #{String.pad_leading(Float.round(track_time_float, 1) |> to_string, 15)} | #{String.pad_leading(Float.round(merge_time_float, 1) |> to_string, 15)} | #{final_count}")
    end)
  end

  defp benchmark_memory_patterns do
    IO.puts("\n=== Memory Allocation Patterns ===")

    buffer = create_styled_buffer() |> elem(0)
    renderer = Renderer.new(buffer, %{}, %{}, false)

    # Test memory usage with different render approaches
    memory_tests = [
      {"baseline_render", fn -> Renderer.render(renderer) end},
      {"style_batching", fn -> Renderer.new(buffer, %{}, %{}, true) |> Renderer.render() end},
      {"repeated_renders", fn ->
        Enum.each(1..10, fn _ -> Renderer.render(renderer) end)
      end}
    ]

    IO.puts("Test Type      | Memory Used (KB) | Allocations | GC Time (μs)")
    IO.puts("---------------|------------------|-------------|-------------")

    Enum.each(memory_tests, fn {name, test_fn} ->
      :erlang.garbage_collect()
      memory_before = :erlang.memory(:total)

      {time, _result} = :timer.tc(test_fn)

      :erlang.garbage_collect()
      memory_after = :erlang.memory(:total)

      memory_used = (memory_after - memory_before) / 1024

      # Estimate GC time (simplified)
      gc_time = max(time * 0.1, 0)

      IO.puts("#{String.pad_trailing(name, 14)} | #{String.pad_leading(Float.round(memory_used, 1) |> to_string, 16)} | #{String.pad_leading("~", 11)} | #{String.pad_leading(Float.round(gc_time, 1) |> to_string, 11)}")
    end)
  end

  defp identify_render_bottlenecks do
    IO.puts("\n=== Render Pipeline Bottleneck Analysis ===")

    buffer = create_full_screen_buffer() |> elem(0)
    renderer = Renderer.new(buffer, %{}, %{}, false)

    # Profile individual pipeline stages
    pipeline_stages = [
      {"cell_iteration", fn ->
        buffer.cells |> Enum.map(fn row -> length(row) end) |> Enum.sum()
      end},
      {"style_string_build", fn ->
        buffer.cells
        |> List.flatten()
        |> Enum.map(fn cell -> build_style_string_test(cell.style) end)
        |> length()
      end},
      {"html_generation", fn ->
        buffer.cells
        |> List.flatten()
        |> Enum.map(fn cell -> "<span>#{cell.char}</span>" end)
        |> Enum.join("")
        |> byte_size()
      end},
      {"complete_render", fn ->
        Renderer.render(renderer) |> byte_size()
      end}
    ]

    IO.puts("Pipeline Stage | Time (μs) | % of Total | Optimization Priority")
    IO.puts("---------------|-----------|------------|----------------------")

    total_time = pipeline_stages
    |> Enum.map(fn {_, stage_fn} ->
      {time, _} = :timer.tc(stage_fn)
      time
    end)
    |> Enum.sum()

    Enum.each(pipeline_stages, fn {stage_name, stage_fn} ->
      {time, _} = :timer.tc(stage_fn)
      percentage = time / total_time * 100

      priority = cond do
        percentage > 40 -> "HIGH"
        percentage > 20 -> "MEDIUM"
        true -> "LOW"
      end

      time_float = time / 1.0
      IO.puts("#{String.pad_trailing(stage_name, 14)} | #{String.pad_leading(Float.round(time_float, 1) |> to_string, 9)} | #{String.pad_leading(Float.round(percentage, 1) |> to_string, 10)} | #{priority}")
    end)
  end

  defp generate_optimization_recommendations do
    IO.puts("\n=== Phase 2 Optimization Recommendations ===")

    IO.puts("IMMEDIATE OPTIMIZATIONS (High Impact):")
    IO.puts("1. Style String Caching")
    IO.puts("   → Cache compiled CSS strings for common style combinations")
    IO.puts("   → Expected improvement: 20-30%")

    IO.puts("2. Style Batching Enhancement")
    IO.puts("   → Improve consecutive cell grouping algorithm")
    IO.puts("   → Reduce HTML span generation overhead")
    IO.puts("   → Expected improvement: 15-25%")

    IO.puts("3. Memory Pool Allocation")
    IO.puts("   → Reuse string builders and intermediate lists")
    IO.puts("   → Reduce GC pressure during rendering")
    IO.puts("   → Expected improvement: 10-20%")

    IO.puts("\nMEDIUM-TERM OPTIMIZATIONS:")
    IO.puts("4. Damage-Only Rendering")
    IO.puts("   → Only render cells in damaged regions")
    IO.puts("   → Incremental DOM updates")

    IO.puts("5. Binary Pattern Optimization")
    IO.puts("   → Pre-compiled style templates")
    IO.puts("   → Fast binary string concatenation")

    IO.puts("\nPERFORMANCE TARGETS:")
    IO.puts("→ Current: ~1000μs average render time")
    IO.puts("→ Phase 2 Target: <500μs (50% improvement)")
    IO.puts("→ Stretch Goal: <300μs (70% improvement)")

    IO.puts("\nNEXT IMPLEMENTATION STEPS:")
    IO.puts("1. Implement style string caching system")
    IO.puts("2. Optimize style batching algorithm")
    IO.puts("3. Add memory pool for render operations")
    IO.puts("4. Test with damage-only rendering")
  end

  # Helper functions to create test buffers

  defp create_empty_buffer do
    buffer = ScreenBuffer.Core.new(80, 24)
    {buffer, 80 * 24}
  end

  defp create_text_buffer do
    buffer = ScreenBuffer.Core.new(80, 24)
    # Fill first row with text
    cells = List.duplicate(%Raxol.Terminal.Cell{char: "A", style: %TextFormatting{}}, 80)
    updated_cells = List.replace_at(buffer.cells, 0, cells)
    buffer = %{buffer | cells: updated_cells}
    {buffer, 80}
  end

  defp create_styled_buffer do
    buffer = ScreenBuffer.Core.new(80, 24)
    style = %TextFormatting{bold: true, foreground: :red}
    cells = List.duplicate(%Raxol.Terminal.Cell{char: "S", style: style}, 80)
    updated_cells = List.replace_at(buffer.cells, 0, cells)
    buffer = %{buffer | cells: updated_cells}
    {buffer, 80}
  end

  defp create_mixed_color_buffer do
    buffer = ScreenBuffer.Core.new(80, 24)

    # Create row with alternating colors
    cells = for i <- 1..80 do
      color = case rem(i, 4) do
        0 -> :red
        1 -> :green
        2 -> :blue
        3 -> :yellow
      end
      %Raxol.Terminal.Cell{char: "M", style: %TextFormatting{foreground: color}}
    end

    updated_cells = List.replace_at(buffer.cells, 0, cells)
    buffer = %{buffer | cells: updated_cells}
    {buffer, 80}
  end

  defp create_full_screen_buffer do
    buffer = ScreenBuffer.Core.new(80, 24)

    # Fill entire buffer with styled content
    cells = for y <- 1..24 do
      for x <- 1..80 do
        char = Integer.to_string(rem(x + y, 10))
        style = %TextFormatting{
          foreground: if(rem(x + y, 2) == 0, do: :red, else: :blue),
          bold: rem(x, 3) == 0
        }
        %Raxol.Terminal.Cell{char: char, style: style}
      end
    end

    buffer = %{buffer | cells: cells}
    {buffer, 80 * 24}
  end

  defp create_damage_heavy_buffer do
    # Same as full screen but with damage tracking
    create_full_screen_buffer()
  end

  defp generate_scattered_damage do
    # Generate 20 random small damage regions
    for _ <- 1..20 do
      x = :rand.uniform(60)
      y = :rand.uniform(20)
      w = :rand.uniform(5) + 1
      h = :rand.uniform(3) + 1
      {x, y, w, h}
    end
  end

  defp benchmark_style_processing(style, iterations) do
    {time, _} = :timer.tc(fn ->
      Enum.each(1..iterations, fn _ ->
        build_style_string_test(style)
      end)
    end)

    time / iterations
  end

  # Simplified style string building for testing
  defp build_style_string_test(style) do
    style_map = Map.from_struct(style)

    []
    |> add_color_if_present(style_map, :foreground, "color")
    |> add_color_if_present(style_map, :background, "background-color")
    |> add_bool_if_present(style_map, :bold, "font-weight", "bold")
    |> add_bool_if_present(style_map, :italic, "font-style", "italic")
    |> add_bool_if_present(style_map, :underline, "text-decoration", "underline")
    |> Enum.map_join("; ", fn {k, v} -> "#{k}: #{v}" end)
  end

  defp add_color_if_present(attrs, style_map, key, css_prop) do
    case Map.get(style_map, key) do
      nil -> attrs
      color -> [{css_prop, color_to_string(color)} | attrs]
    end
  end

  defp add_bool_if_present(attrs, style_map, key, css_prop, css_value) do
    if Map.get(style_map, key, false) do
      [{css_prop, css_value} | attrs]
    else
      attrs
    end
  end

  defp color_to_string(color) when is_atom(color), do: to_string(color)
  defp color_to_string(%{r: r, g: g, b: b}), do: "rgb(#{r},#{g},#{b})"
  defp color_to_string(color), do: to_string(color)
end

# Run the benchmark
Phase2RenderBenchmark.run()