#!/usr/bin/env elixir

# LiveView Rendering Performance Benchmark
#
# Validates that all LiveView rendering operations meet the 60fps target (< 16ms per frame)
#
# Run with: mix run bench/live_view/rendering_benchmark.exs

defmodule LiveViewRenderingBenchmark do
  alias Raxol.Core.{Buffer, Box}
  alias Raxol.LiveView.TerminalBridge

  @target_ms 16
  @target_us @target_ms * 1000

  def run do
    IO.puts("\n" <> String.duplicate("=", 80))
    IO.puts("RAXOL LIVEVIEW RENDERING BENCHMARK")
    IO.puts("Target: < #{@target_ms}ms per operation (60fps)")
    IO.puts(String.duplicate("=", 80) <> "\n")

    results = [
      # Basic rendering
      benchmark("Empty 80x24 buffer to HTML", fn ->
        buffer = Buffer.create_blank_buffer(80, 24)
        TerminalBridge.buffer_to_html(buffer)
      end),

      benchmark("Simple text buffer to HTML", fn ->
        buffer = Buffer.create_blank_buffer(80, 24)
        buffer = Buffer.write_at(buffer, 0, 0, "Hello, World!")
        TerminalBridge.buffer_to_html(buffer)
      end),

      benchmark("Full 80x24 buffer with text", fn ->
        buffer = Buffer.create_blank_buffer(80, 24)
        buffer = Enum.reduce(0..23, buffer, fn y, acc ->
          Buffer.write_at(acc, 0, y, "Line #{y}: The quick brown fox jumps over the lazy dog")
        end)
        TerminalBridge.buffer_to_html(buffer)
      end),

      # Styled content
      benchmark("Buffer with bold text", fn ->
        buffer = Buffer.create_blank_buffer(80, 24)
        buffer = Buffer.write_at(buffer, 0, 0, "Bold Text", %{bold: true})
        TerminalBridge.buffer_to_html(buffer)
      end),

      benchmark("Buffer with multiple styles", fn ->
        buffer = Buffer.create_blank_buffer(80, 24)
        buffer = Buffer.write_at(buffer, 0, 0, "Bold", %{bold: true})
        buffer = Buffer.write_at(buffer, 5, 0, "Italic", %{italic: true})
        buffer = Buffer.write_at(buffer, 12, 0, "Underline", %{underline: true})
        buffer = Buffer.write_at(buffer, 0, 1, "Red", %{fg_color: :red})
        buffer = Buffer.write_at(buffer, 4, 1, "Blue", %{fg_color: :blue})
        TerminalBridge.buffer_to_html(buffer)
      end),

      benchmark("Buffer with RGB colors", fn ->
        buffer = Buffer.create_blank_buffer(80, 24)
        buffer = Buffer.write_at(buffer, 0, 0, "RGB", %{fg_color: {255, 128, 64}})
        buffer = Buffer.write_at(buffer, 0, 1, "BG", %{bg_color: {64, 128, 255}})
        TerminalBridge.buffer_to_html(buffer, use_inline_styles: true)
      end),

      # Theming
      benchmark("Buffer with Nord theme", fn ->
        buffer = Buffer.create_blank_buffer(80, 24)
        buffer = Buffer.write_at(buffer, 0, 0, "Themed")
        TerminalBridge.buffer_to_html(buffer, theme: :nord)
      end),

      benchmark("Buffer with Dracula theme", fn ->
        buffer = Buffer.create_blank_buffer(80, 24)
        buffer = Buffer.write_at(buffer, 0, 0, "Themed")
        TerminalBridge.buffer_to_html(buffer, theme: :dracula)
      end),

      # Cursor rendering
      benchmark("Buffer with block cursor", fn ->
        buffer = Buffer.create_blank_buffer(80, 24)
        TerminalBridge.buffer_to_html(buffer,
          show_cursor: true,
          cursor_position: {5, 3},
          cursor_style: :block
        )
      end),

      benchmark("Buffer with underline cursor", fn ->
        buffer = Buffer.create_blank_buffer(80, 24)
        TerminalBridge.buffer_to_html(buffer,
          show_cursor: true,
          cursor_position: {5, 3},
          cursor_style: :underline
        )
      end),

      # Diff rendering
      benchmark("Diff with no changes", fn ->
        buffer = Buffer.create_blank_buffer(80, 24)
        TerminalBridge.buffer_diff_to_html(buffer, buffer)
      end),

      benchmark("Diff with single line change", fn ->
        old_buffer = Buffer.create_blank_buffer(80, 24)
        new_buffer = Buffer.write_at(old_buffer, 0, 0, "Changed")
        TerminalBridge.buffer_diff_to_html(old_buffer, new_buffer)
      end),

      benchmark("Diff with multiple changes", fn ->
        old_buffer = Buffer.create_blank_buffer(80, 24)
        new_buffer = Enum.reduce(0..5, old_buffer, fn y, acc ->
          Buffer.write_at(acc, 0, y, "Line #{y}")
        end)
        TerminalBridge.buffer_diff_to_html(old_buffer, new_buffer)
      end),

      # Style conversion
      benchmark("style_to_classes - empty", fn ->
        TerminalBridge.style_to_classes(%{})
      end),

      benchmark("style_to_classes - bold + color", fn ->
        TerminalBridge.style_to_classes(%{bold: true, fg_color: :blue})
      end),

      benchmark("style_to_classes - all attributes", fn ->
        TerminalBridge.style_to_classes(%{
          bold: true,
          italic: true,
          underline: true,
          reverse: true,
          fg_color: :blue,
          bg_color: :red
        })
      end),

      benchmark("style_to_inline - empty", fn ->
        TerminalBridge.style_to_inline(%{})
      end),

      benchmark("style_to_inline - bold + RGB", fn ->
        TerminalBridge.style_to_inline(%{
          bold: true,
          fg_color: {255, 128, 64}
        })
      end),

      benchmark("style_to_inline - all attributes", fn ->
        TerminalBridge.style_to_inline(%{
          bold: true,
          italic: true,
          underline: true,
          fg_color: {255, 0, 0},
          bg_color: {0, 0, 255}
        })
      end),

      # Complex layouts
      benchmark("Buffer with box drawing", fn ->
        buffer = Buffer.create_blank_buffer(80, 24)
        buffer = Box.draw_box(buffer, 0, 0, 80, 24, :double)
        buffer = Box.draw_box(buffer, 2, 2, 76, 20, :single)
        TerminalBridge.buffer_to_html(buffer)
      end),

      benchmark("Buffer with nested boxes", fn ->
        buffer = Buffer.create_blank_buffer(80, 24)
        buffer = Box.draw_box(buffer, 0, 0, 80, 24, :double)
        buffer = Box.draw_box(buffer, 5, 3, 70, 18, :single)
        buffer = Box.draw_box(buffer, 10, 6, 60, 12, :rounded)
        TerminalBridge.buffer_to_html(buffer)
      end),

      # Larger buffers
      benchmark("120x40 buffer to HTML", fn ->
        buffer = Buffer.create_blank_buffer(120, 40)
        buffer = Enum.reduce(0..39, buffer, fn y, acc ->
          Buffer.write_at(acc, 0, y, "Line #{y}")
        end)
        TerminalBridge.buffer_to_html(buffer)
      end),

      benchmark("200x60 buffer to HTML", fn ->
        buffer = Buffer.create_blank_buffer(200, 60)
        buffer = Enum.reduce(0..59, buffer, fn y, acc ->
          Buffer.write_at(acc, 0, y, "Line #{y}")
        end)
        TerminalBridge.buffer_to_html(buffer)
      end),

      # HTML escaping
      benchmark("Buffer with HTML special chars", fn ->
        buffer = Buffer.create_blank_buffer(80, 24)
        buffer = Buffer.write_at(buffer, 0, 0, "<script>alert('xss')</script>")
        buffer = Buffer.write_at(buffer, 0, 1, "A & B")
        buffer = Buffer.write_at(buffer, 0, 2, "\"quoted\"")
        TerminalBridge.buffer_to_html(buffer)
      end),

      # Custom CSS prefix
      benchmark("Buffer with custom prefix", fn ->
        buffer = Buffer.create_blank_buffer(80, 24)
        buffer = Buffer.write_at(buffer, 0, 0, "Custom")
        TerminalBridge.buffer_to_html(buffer, css_prefix: "custom")
      end),

      # Inline styles
      benchmark("Buffer with inline styles", fn ->
        buffer = Buffer.create_blank_buffer(80, 24)
        buffer = Buffer.write_at(buffer, 0, 0, "Inline", %{
          bold: true,
          fg_color: {255, 0, 0}
        })
        TerminalBridge.buffer_to_html(buffer, use_inline_styles: true)
      end),

      # Full render cycle (realistic usage)
      benchmark("Full render: create + style + convert", fn ->
        buffer = Buffer.create_blank_buffer(80, 24)
        buffer = Box.draw_box(buffer, 0, 0, 80, 24, :double)
        buffer = Buffer.write_at(buffer, 2, 1, "Raxol Terminal", %{bold: true})
        buffer = Buffer.write_at(buffer, 2, 3, "Status: Running", %{fg_color: :green})
        buffer = Buffer.write_at(buffer, 2, 4, "FPS: 60", %{fg_color: :cyan})
        TerminalBridge.buffer_to_html(buffer,
          theme: :nord,
          show_cursor: true,
          cursor_position: {2, 6},
          cursor_style: :block
        )
      end)
    ]

    print_summary(results)
  end

  defp benchmark(name, fun) do
    # Warmup
    Enum.each(1..10, fn _ -> fun.() end)

    # Actual benchmark
    {time_us, _result} = :timer.tc(fn ->
      Enum.each(1..100, fn _ -> fun.() end)
    end)

    avg_us = div(time_us, 100)
    avg_ms = avg_us / 1000
    passed = avg_us < @target_us

    status = if passed, do: "[PASS]", else: "[FAIL]"

    IO.puts("#{status} #{name}")
    IO.puts("      #{format_time(avg_us)} (target: < #{@target_ms}ms)")
    IO.puts("")

    %{name: name, time_us: avg_us, time_ms: avg_ms, passed: passed}
  end

  defp format_time(us) when us < 1000, do: "#{us}μs"
  defp format_time(us), do: "#{Float.round(us / 1000, 2)}ms"

  defp print_summary(results) do
    passed = Enum.count(results, & &1.passed)
    total = length(results)
    pass_rate = Float.round(passed / total * 100, 1)

    avg_time = results |> Enum.map(& &1.time_us) |> Enum.sum() |> div(total)
    min_time = results |> Enum.map(& &1.time_us) |> Enum.min()
    max_time = results |> Enum.map(& &1.time_us) |> Enum.max()

    IO.puts(String.duplicate("=", 80))
    IO.puts("SUMMARY")
    IO.puts(String.duplicate("=", 80))
    IO.puts("Total benchmarks: #{total}")
    IO.puts("Passed: #{passed}")
    IO.puts("Failed: #{total - passed}")
    IO.puts("Pass rate: #{pass_rate}%")
    IO.puts("")
    IO.puts("Performance:")
    IO.puts("  Average: #{format_time(avg_time)}")
    IO.puts("  Min: #{format_time(min_time)}")
    IO.puts("  Max: #{format_time(max_time)}")
    IO.puts("")

    if pass_rate == 100.0 do
      IO.puts("✓ All benchmarks passed! LiveView rendering is ready for 60fps.")
    else
      IO.puts("✗ Some benchmarks failed. Review performance optimizations.")
      IO.puts("\nFailed benchmarks:")
      results
      |> Enum.reject(& &1.passed)
      |> Enum.each(fn result ->
        IO.puts("  - #{result.name}: #{format_time(result.time_us)}")
      end)
    end

    IO.puts(String.duplicate("=", 80))
  end
end

LiveViewRenderingBenchmark.run()
