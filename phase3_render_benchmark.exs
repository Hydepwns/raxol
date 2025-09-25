#!/usr/bin/env elixir

# Phase 3 Render Optimization Benchmark
# Comparing original, cached, and optimized renderers

alias Raxol.Terminal.{Emulator, Renderer, ScreenBuffer}
alias Raxol.Terminal.Renderer.{CachedStyleRenderer, OptimizedStyleRenderer}
alias Raxol.Terminal.ANSI.TextFormatting

defmodule Phase3RenderBenchmark do
  def run do
    IO.puts("\n" <> String.duplicate("=", 70))
    IO.puts("PHASE 3 RENDER OPTIMIZATION BENCHMARK")
    IO.puts(String.duplicate("=", 70))
    IO.puts("Testing render performance improvements")
    IO.puts("Target: <500μs render time\n")

    # Create test buffers with different content patterns
    buffers = create_test_buffers()

    # Run benchmarks for each renderer type
    Enum.each(buffers, fn {name, buffer, description} ->
      IO.puts("\n" <> String.duplicate("-", 70))
      IO.puts("Test Case: #{name}")
      IO.puts("Description: #{description}")
      IO.puts(String.duplicate("-", 70))

      results = benchmark_renderers(buffer)
      analyze_results(results)
    end)

    IO.puts("\n" <> String.duplicate("=", 70))
    IO.puts("PHASE 3 OPTIMIZATION SUMMARY")
    IO.puts(String.duplicate("=", 70))
    print_summary()
  end

  defp create_test_buffers do
    [
      {"Empty Buffer", create_empty_buffer(), "80x24 empty terminal"},
      {"Plain Text", create_plain_text_buffer(), "Simple text without styling"},
      {"Colored Text", create_colored_buffer(), "Text with various colors"},
      {"Mixed Styles", create_mixed_styles_buffer(), "Bold, italic, underline combinations"},
      {"Full Screen", create_full_screen_buffer(), "Completely filled with styled content"},
      {"Realistic Terminal", create_realistic_buffer(), "Typical terminal session output"}
    ]
  end

  defp create_empty_buffer do
    ScreenBuffer.new(80, 24)
  end

  defp create_plain_text_buffer do
    buffer = ScreenBuffer.new(80, 24)
    text = "Hello, World! This is a test of plain text rendering."

    buffer
    |> write_text_at(0, 0, text)
    |> write_text_at(1, 0, "Line 2 of plain text")
    |> write_text_at(2, 0, "Line 3 with more content")
  end

  defp create_colored_buffer do
    buffer = ScreenBuffer.new(80, 24)

    buffer
    |> write_styled_text(0, 0, "Red text", %{foreground: :red})
    |> write_styled_text(0, 10, "Green text", %{foreground: :green})
    |> write_styled_text(0, 22, "Blue text", %{foreground: :blue})
    |> write_styled_text(1, 0, "Yellow background", %{background: :yellow})
    |> write_styled_text(2, 0, "Cyan on magenta", %{foreground: :cyan, background: :magenta})
  end

  defp create_mixed_styles_buffer do
    buffer = ScreenBuffer.new(80, 24)

    buffer
    |> write_styled_text(0, 0, "Bold text", %{bold: true})
    |> write_styled_text(0, 11, "Italic text", %{italic: true})
    |> write_styled_text(0, 24, "Underlined", %{underline: true})
    |> write_styled_text(1, 0, "Bold red", %{bold: true, foreground: :red})
    |> write_styled_text(2, 0, "Italic green underlined", %{italic: true, underline: true, foreground: :green})
  end

  defp create_full_screen_buffer do
    buffer = ScreenBuffer.new(80, 24)

    # Fill entire screen with pattern
    Enum.reduce(0..23, buffer, fn y, buf ->
      style = case rem(y, 4) do
        0 -> %{foreground: :red}
        1 -> %{foreground: :green, bold: true}
        2 -> %{foreground: :blue, italic: true}
        3 -> %{foreground: :yellow, underline: true}
      end

      text = String.duplicate("█", 80)
      write_styled_text(buf, y, 0, text, style)
    end)
  end

  defp create_realistic_buffer do
    buffer = ScreenBuffer.new(80, 24)

    buffer
    |> write_styled_text(0, 0, "user@host", %{foreground: :green, bold: true})
    |> write_text_at(0, 10, ":~/project$ ")
    |> write_text_at(0, 23, "git status")
    |> write_styled_text(1, 0, "On branch ", %{})
    |> write_styled_text(1, 10, "main", %{foreground: :cyan, bold: true})
    |> write_styled_text(2, 0, "Changes to be committed:", %{foreground: :green})
    |> write_styled_text(3, 2, "modified:", %{foreground: :green})
    |> write_text_at(3, 14, "src/app.ex")
    |> write_styled_text(4, 2, "new file:", %{foreground: :green})
    |> write_text_at(4, 14, "test/app_test.exs")
    |> write_styled_text(5, 0, "Changes not staged:", %{foreground: :red})
    |> write_styled_text(6, 2, "modified:", %{foreground: :red})
    |> write_text_at(6, 14, "README.md")
  end

  defp write_text_at(buffer, y, x, text) do
    write_styled_text(buffer, y, x, text, %{})
  end

  defp write_styled_text(buffer, y, x, text, style_attrs) do
    style = struct(TextFormatting, style_attrs)

    chars = String.graphemes(text)
    cells = Enum.map(chars, fn char ->
      %Raxol.Terminal.Cell{
        char: char,
        style: style,
        dirty: false
      }
    end)

    # Update the buffer row
    case buffer.cells do
      nil -> buffer
      rows ->
        row = Enum.at(rows, y, [])
        {before, after_with_x} = Enum.split(row, x)
        after_cells = Enum.drop(after_with_x, length(cells))
        new_row = before ++ cells ++ after_cells

        # Pad row if needed
        final_row = if length(new_row) < buffer.width do
          new_row ++ List.duplicate(default_cell(), buffer.width - length(new_row))
        else
          Enum.take(new_row, buffer.width)
        end

        new_rows = List.replace_at(rows, y, final_row)
        %{buffer | cells: new_rows}
    end
  end

  defp default_cell do
    %Raxol.Terminal.Cell{
      char: " ",
      style: TextFormatting.new(),
      dirty: false
    }
  end

  defp benchmark_renderers(buffer) do
    # Create renderer instances
    original_renderer = %Renderer{
      screen_buffer: buffer,
      cursor: nil,
      theme: %{},
      font_settings: %{},
      style_batching: true
    }

    # Warmup
    _ = Renderer.render(original_renderer)
    _ = OptimizedStyleRenderer.render(buffer)

    # Measure original renderer
    original_times = measure_render_times(fn ->
      Renderer.render(original_renderer)
    end, 100)

    # Measure optimized renderer
    optimized_times = measure_render_times(fn ->
      OptimizedStyleRenderer.render(buffer)
    end, 100)

    %{
      original: calculate_stats(original_times),
      optimized: calculate_stats(optimized_times)
    }
  end

  defp measure_render_times(render_fn, iterations) do
    Enum.map(1..iterations, fn _ ->
      {time, _result} = :timer.tc(render_fn)
      time
    end)
  end

  defp calculate_stats(times) do
    sorted = Enum.sort(times)
    count = length(sorted)

    %{
      min: Enum.min(sorted),
      max: Enum.max(sorted),
      median: Enum.at(sorted, div(count, 2)),
      mean: Enum.sum(sorted) / count,
      p95: Enum.at(sorted, round(count * 0.95)),
      p99: Enum.at(sorted, round(count * 0.99))
    }
  end

  defp analyze_results(results) do
    IO.puts("\nResults (microseconds):")
    IO.puts(String.duplicate("-", 50))

    IO.puts("Original Renderer:")
    print_stats(results.original)

    IO.puts("\nOptimized Renderer:")
    print_stats(results.optimized)

    # Calculate improvement
    improvement = (results.original.median - results.optimized.median) / results.original.median * 100
    speedup = results.original.median / results.optimized.median

    IO.puts("\nImprovement:")
    IO.puts("  Speedup: #{Float.round(speedup, 2)}x")
    IO.puts("  Reduction: #{Float.round(improvement, 1)}%")

    # Check if target met
    target_met = results.optimized.median < 500
    status = if target_met, do: "✓ TARGET MET", else: "✗ Target not met"
    IO.puts("  Status: #{status} (target: <500μs)")
  end

  defp print_stats(stats) do
    IO.puts("  Min:    #{format_time(stats.min)}")
    IO.puts("  Median: #{format_time(stats.median)}")
    IO.puts("  Mean:   #{format_time(stats.mean)}")
    IO.puts("  P95:    #{format_time(stats.p95)}")
    IO.puts("  P99:    #{format_time(stats.p99)}")
    IO.puts("  Max:    #{format_time(stats.max)}")
  end

  defp format_time(microseconds) do
    "#{Float.round(microseconds * 1.0, 1)}μs"
  end

  defp print_summary do
    IO.puts("\nKey Achievements:")
    IO.puts("1. Eliminated process dictionary usage")
    IO.puts("2. Pre-compiled common style patterns")
    IO.puts("3. Direct pattern matching for style lookup")
    IO.puts("4. Efficient iodata string building")
    IO.puts("5. Minimal memory allocations")

    IO.puts("\nOptimization Techniques Applied:")
    IO.puts("- Compile-time pattern generation")
    IO.puts("- Zero-cost abstractions for common cases")
    IO.puts("- Efficient grouping of styled spans")
    IO.puts("- Binary pattern matching for colors")
    IO.puts("- IOdata for string concatenation")
  end
end

# Run the benchmark
Phase3RenderBenchmark.run()