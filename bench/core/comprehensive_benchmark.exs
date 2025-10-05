defmodule Raxol.Core.ComprehensiveBenchmark do
  @moduledoc """
  Comprehensive benchmark suite for all Raxol.Core modules.

  Verifies Phase 1 performance targets:
  - All operations < 1ms for standard 80x24 buffers
  - Diff rendering < 2ms
  - Box drawing < 1ms

  Run with: mix run bench/core/comprehensive_benchmark.exs
  """

  alias Raxol.Core.{Buffer, Renderer, Style, Box}

  def run do
    IO.puts("\n" <> String.duplicate("=", 70))
    IO.puts("RAXOL.CORE COMPREHENSIVE BENCHMARK SUITE")
    IO.puts("Phase 1 Performance Validation")
    IO.puts(String.duplicate("=", 70) <> "\n")

    results = %{
      buffer: benchmark_buffer(),
      renderer: benchmark_renderer(),
      style: benchmark_style(),
      box: benchmark_box()
    }

    print_summary(results)

    results
  end

  # ===== BUFFER BENCHMARKS =====

  defp benchmark_buffer do
    IO.puts("=== Buffer Module ===\n")

    benchmarks = [
      {"create_blank_buffer (80x24)", 1000, fn ->
        Buffer.create_blank_buffer(80, 24)
      end},
      {"create_blank_buffer (120x40)", 2000, fn ->
        Buffer.create_blank_buffer(120, 40)
      end},
      {"write_at (short string)", 1000, fn ->
        buffer = Buffer.create_blank_buffer(80, 24)
        Buffer.write_at(buffer, 5, 3, "Hello, World!")
      end},
      {"write_at (long string)", 1000, fn ->
        buffer = Buffer.create_blank_buffer(80, 24)
        text = String.duplicate("A", 80)
        Buffer.write_at(buffer, 0, 0, text)
      end},
      {"get_cell (in bounds)", 1000, fn ->
        buffer = Buffer.create_blank_buffer(80, 24)
        Buffer.get_cell(buffer, 40, 12)
      end},
      {"get_cell (out of bounds)", 1000, fn ->
        buffer = Buffer.create_blank_buffer(80, 24)
        Buffer.get_cell(buffer, 100, 100)
      end},
      {"set_cell", 1000, fn ->
        buffer = Buffer.create_blank_buffer(80, 24)
        Buffer.set_cell(buffer, 10, 5, "X", %{})
      end},
      {"clear", 1000, fn ->
        buffer = Buffer.create_blank_buffer(80, 24)
        Buffer.clear(buffer)
      end},
      {"resize (expand)", 2000, fn ->
        buffer = Buffer.create_blank_buffer(80, 24)
        Buffer.resize(buffer, 120, 40)
      end},
      {"resize (shrink)", 1000, fn ->
        buffer = Buffer.create_blank_buffer(80, 24)
        Buffer.resize(buffer, 40, 12)
      end},
      {"to_string", 1000, fn ->
        buffer = Buffer.create_blank_buffer(80, 24)
        Buffer.to_string(buffer)
      end}
    ]

    run_benchmarks(benchmarks)
  end

  # ===== RENDERER BENCHMARKS =====

  defp benchmark_renderer do
    IO.puts("\n=== Renderer Module ===\n")

    buffer1 = Buffer.create_blank_buffer(80, 24)
    buffer2 = Buffer.write_at(buffer1, 5, 3, "Changed text")

    buffer3 = Buffer.create_blank_buffer(80, 24)
    buffer4 =
      Enum.reduce(0..23, buffer3, fn y, acc ->
        Buffer.write_at(acc, 0, y, "Line #{y}")
      end)

    benchmarks = [
      {"render_to_string (empty)", 1000, fn ->
        Renderer.render_to_string(buffer1)
      end},
      {"render_to_string (full)", 1000, fn ->
        Renderer.render_to_string(buffer4)
      end},
      {"render_diff (minimal change)", 2000, fn ->
        Renderer.render_diff(buffer1, buffer2)
      end},
      {"render_diff (many changes)", 2000, fn ->
        Renderer.render_diff(buffer3, buffer4)
      end},
      {"render_diff (no changes)", 1000, fn ->
        Renderer.render_diff(buffer1, buffer1)
      end}
    ]

    run_benchmarks(benchmarks)
  end

  # ===== STYLE BENCHMARKS =====

  defp benchmark_style do
    IO.puts("\n=== Style Module ===\n")

    style1 = Style.new(bold: true, fg_color: :blue)
    style2 = Style.new(italic: true, bg_color: :red)

    benchmarks = [
      {"new (minimal)", 1000, fn ->
        Style.new([])
      end},
      {"new (full)", 1000, fn ->
        Style.new(bold: true, italic: true, underline: true, fg_color: :blue, bg_color: :red)
      end},
      {"merge", 1000, fn ->
        Style.merge(style1, style2)
      end},
      {"rgb", 1000, fn ->
        Style.rgb(255, 128, 64)
      end},
      {"color_256", 1000, fn ->
        Style.color_256(196)
      end},
      {"named_color", 1000, fn ->
        Style.named_color(:blue)
      end},
      {"to_ansi (simple)", 1000, fn ->
        style = Style.new(bold: true)
        Style.to_ansi(style)
      end},
      {"to_ansi (complex)", 1000, fn ->
        style = Style.new(bold: true, italic: true, fg_color: {255, 100, 50}, bg_color: 196)
        Style.to_ansi(style)
      end}
    ]

    run_benchmarks(benchmarks)
  end

  # ===== BOX BENCHMARKS =====

  defp benchmark_box do
    IO.puts("\n=== Box Module ===\n")

    buffer = Buffer.create_blank_buffer(80, 24)

    benchmarks = [
      {"draw_box (small, single)", 1000, fn ->
        Box.draw_box(buffer, 10, 5, 10, 5, :single)
      end},
      {"draw_box (medium, double)", 1000, fn ->
        Box.draw_box(buffer, 10, 5, 30, 10, :double)
      end},
      {"draw_box (large, rounded)", 1000, fn ->
        Box.draw_box(buffer, 5, 3, 70, 18, :rounded)
      end},
      {"draw_box (full buffer)", 1000, fn ->
        Box.draw_box(buffer, 0, 0, 80, 24, :single)
      end},
      {"draw_horizontal_line (short)", 1000, fn ->
        Box.draw_horizontal_line(buffer, 10, 5, 10)
      end},
      {"draw_horizontal_line (full width)", 1000, fn ->
        Box.draw_horizontal_line(buffer, 0, 0, 80)
      end},
      {"draw_vertical_line (short)", 1000, fn ->
        Box.draw_vertical_line(buffer, 10, 5, 5)
      end},
      {"draw_vertical_line (full height)", 1000, fn ->
        Box.draw_vertical_line(buffer, 0, 0, 24)
      end},
      {"fill_area (small 5x5)", 1000, fn ->
        Box.fill_area(buffer, 10, 5, 5, 5, "#")
      end},
      {"fill_area (medium 20x10)", 1000, fn ->
        Box.fill_area(buffer, 10, 5, 20, 10, ".")
      end},
      {"fill_area (full buffer)", 2000, fn ->
        Box.fill_area(buffer, 0, 0, 80, 24, " ")
      end},
      {"complex scene", 1000, fn ->
        buffer
        |> Box.draw_box(5, 3, 30, 10, :double)
        |> Box.draw_box(40, 8, 25, 12, :single)
        |> Box.draw_horizontal_line(0, 0, 80)
        |> Box.fill_area(6, 4, 28, 8, ".")
      end}
    ]

    run_benchmarks(benchmarks)
  end

  # ===== HELPER FUNCTIONS =====

  defp run_benchmarks(benchmarks) do
    Enum.map(benchmarks, fn {name, target_us, fun} ->
      {time_us, _result} = measure_us(fun)
      status = if time_us < target_us, do: "PASS", else: "FAIL"
      color = if time_us < target_us, do: :green, else: :red

      padded_name = String.pad_trailing(name, 40)
      status_text = colorize("#{status}", color)
      IO.puts("#{status_text} | #{padded_name} | #{String.pad_leading("#{time_us}", 6)} us (target: #{target_us})")

      {name, time_us, target_us, time_us < target_us}
    end)
  end

  defp measure_us(fun) do
    start = System.monotonic_time(:microsecond)
    result = fun.()
    finish = System.monotonic_time(:microsecond)
    {finish - start, result}
  end

  defp colorize(text, :green), do: "\e[32m#{text}\e[0m"
  defp colorize(text, :red), do: "\e[31m#{text}\e[0m"
  defp colorize(text, :yellow), do: "\e[33m#{text}\e[0m"
  defp colorize(text, _), do: text

  defp print_summary(results) do
    IO.puts("\n" <> String.duplicate("=", 70))
    IO.puts("SUMMARY")
    IO.puts(String.duplicate("=", 70))

    all_results =
      Enum.flat_map(results, fn {_module, module_results} ->
        module_results
      end)

    total = length(all_results)
    passed = Enum.count(all_results, fn {_, _, _, pass} -> pass end)
    failed = total - passed

    pass_rate = Float.round(passed / total * 100, 1)

    IO.puts("\nTotal Benchmarks: #{total}")
    IO.puts("Passed: #{colorize("#{passed}", :green)} (#{pass_rate}%)")

    if failed > 0 do
      IO.puts("Failed: #{colorize("#{failed}", :red)} (#{Float.round(100 - pass_rate, 1)}%)")

      IO.puts("\nFailed Benchmarks:")

      all_results
      |> Enum.filter(fn {_, _, _, pass} -> not pass end)
      |> Enum.each(fn {name, time, target, _} ->
        over = time - target
        IO.puts("  - #{name}: #{time} us (#{over} us over target)")
      end)
    else
      IO.puts(colorize("\nAll benchmarks PASSED!", :green))
    end

    # Calculate statistics
    times = Enum.map(all_results, fn {_, time, _, _} -> time end)
    avg_time = div(Enum.sum(times), length(times))
    max_time = Enum.max(times)
    min_time = Enum.min(times)

    IO.puts("\nPerformance Statistics:")
    IO.puts("  Average: #{avg_time} us")
    IO.puts("  Min: #{min_time} us")
    IO.puts("  Max: #{max_time} us")

    IO.puts("\n" <> String.duplicate("=", 70))

    if failed == 0 do
      IO.puts(colorize("Phase 1 Performance Targets: MET", :green))
    else
      IO.puts(colorize("Phase 1 Performance Targets: REVIEW REQUIRED", :yellow))
    end

    IO.puts(String.duplicate("=", 70) <> "\n")
  end
end

# Run the benchmark
Raxol.Core.ComprehensiveBenchmark.run()
