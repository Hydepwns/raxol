#!/usr/bin/env elixir
# Phase 3 Render Optimization Test - Validation of <500μs Target

Mix.install([])

defmodule Phase3OptimizationTest do
  @moduledoc """
  Test the Phase 3 render optimizations - style batching with lightweight caching.
  Target: Reduce render time from ~1200μs to <500μs
  """

  alias Raxol.Terminal.{ScreenBuffer, Renderer}

  def run do
    IO.puts("=== Phase 3 Render Optimization Validation ===")
    IO.puts("Target: <500μs render time (60% improvement from baseline)")
    IO.puts("")

    # Create test scenarios
    scenarios = [
      {"empty_buffer", create_empty_buffer()},
      {"text_only", create_text_buffer()},
      {"styled_text", create_styled_buffer()},
      {"mixed_colors", create_mixed_color_buffer()},
      {"full_screen", create_full_screen_buffer()},
      {"common_styles", create_common_styles_buffer()}
    ]

    # Test both old and new rendering approaches
    IO.puts("=== Performance Comparison ===")
    IO.puts(String.pad_trailing("Scenario", 15) <> " | " <>
           String.pad_trailing("Old (μs)", 10) <> " | " <>
           String.pad_trailing("New (μs)", 10) <> " | " <>
           String.pad_trailing("Improvement", 12) <> " | " <>
           "Target Met?")
    IO.puts(String.duplicate("-", 70))

    Enum.each(scenarios, fn {name, buffer} ->
      old_time = benchmark_old_renderer(buffer)
      new_time = benchmark_new_renderer(buffer)
      improvement = calculate_improvement(old_time, new_time)
      target_met = new_time < 500.0

      status = if target_met, do: "✓", else: "✗"

      IO.puts(String.pad_trailing(name, 15) <> " | " <>
             String.pad_trailing("#{Float.round(old_time, 1)}", 10) <> " | " <>
             String.pad_trailing("#{Float.round(new_time, 1)}", 10) <> " | " <>
             String.pad_trailing("#{Float.round(improvement, 1)}%", 12) <> " | " <>
             status)
    end)

    # Test cache effectiveness
    IO.puts("")
    IO.puts("=== Cache Effectiveness Test ===")
    test_cache_effectiveness()

    IO.puts("")
    IO.puts("=== Template Matching Test ===")
    test_template_matching()
  end

  defp create_empty_buffer do
    ScreenBuffer.new(80, 24)
  end

  defp create_text_buffer do
    buffer = ScreenBuffer.new(80, 24)
    content = "Hello, world! This is a test of basic text rendering."
    ScreenBuffer.write_string(buffer, 0, 0, content)
  end

  defp create_styled_buffer do
    buffer = ScreenBuffer.new(80, 24)
    # Add styled text - bold red
    style = %{foreground: :red, bold: true}
    content = "This is bold red text for testing style rendering performance."
    ScreenBuffer.write_styled_string(buffer, 0, 0, content, style)
  end

  defp create_mixed_color_buffer do
    buffer = ScreenBuffer.new(80, 24)
    styles_and_text = [
      {%{foreground: :red}, "Red text "},
      {%{foreground: :green, bold: true}, "Bold green "},
      {%{foreground: :blue, italic: true}, "Italic blue "},
      {%{foreground: :yellow, underline: true}, "Underlined yellow"}
    ]

    {_, _} = Enum.reduce(styles_and_text, {buffer, 0}, fn {style, text}, {buf, col} ->
      new_buf = ScreenBuffer.write_styled_string(buf, 0, col, text, style)
      {new_buf, col + String.length(text)}
    end)

    buffer
  end

  defp create_full_screen_buffer do
    buffer = ScreenBuffer.new(80, 24)

    # Fill entire screen with styled content
    for row <- 0..23 do
      style = %{
        foreground: Enum.random([:red, :green, :blue, :yellow, :cyan, :magenta]),
        bold: rem(row, 3) == 0,
        italic: rem(row, 4) == 0
      }
      content = String.duplicate("X", 80)
      ScreenBuffer.write_styled_string(buffer, row, 0, content, style)
    end

    buffer
  end

  defp create_common_styles_buffer do
    buffer = ScreenBuffer.new(80, 24)

    # Create buffer with most common style patterns
    common_styles = [
      %{}, # default
      %{foreground: :red},
      %{foreground: :green},
      %{foreground: :blue},
      %{bold: true},
      %{italic: true},
      %{foreground: :red, bold: true},
      %{foreground: :green, bold: true}
    ]

    for {style, row} <- Enum.with_index(common_styles) do
      content = "Common style pattern ##{row + 1} " <> String.duplicate("test", 15)
      ScreenBuffer.write_styled_string(buffer, row, 0, content, style)
    end

    buffer
  end

  defp benchmark_old_renderer(buffer) do
    # Simulate old renderer without caching
    renderer = Renderer.new(buffer, %{}, %{}, false) # style_batching = false

    {time_us, _result} = :timer.tc(fn ->
      Renderer.render(renderer)
    end)

    time_us / 1.0
  end

  defp benchmark_new_renderer(buffer) do
    # Test new optimized renderer with caching
    renderer = Renderer.new(buffer, %{}, %{}, true) # style_batching = true

    {time_us, _result} = :timer.tc(fn ->
      Renderer.render_with_cache(renderer)
    end)

    time_us / 1.0
  end

  defp calculate_improvement(old_time, new_time) do
    ((old_time - new_time) / old_time) * 100.0
  end

  defp test_cache_effectiveness do
    buffer = create_common_styles_buffer()
    renderer = Renderer.new(buffer)

    # First render - cache misses
    {time1, {_content1, renderer1}} = :timer.tc(fn ->
      Renderer.render_with_cache(renderer)
    end)

    # Second render - should have cache hits
    {time2, {_content2, _renderer2}} = :timer.tc(fn ->
      Renderer.render_with_cache(renderer1)
    end)

    cache_improvement = calculate_improvement(time1 / 1.0, time2 / 1.0)

    IO.puts("First render (cache misses): #{Float.round(time1 / 1.0, 1)}μs")
    IO.puts("Second render (cache hits): #{Float.round(time2 / 1.0, 1)}μs")
    IO.puts("Cache effectiveness: #{Float.round(cache_improvement, 1)}% improvement")
  end

  defp test_template_matching do
    # Test that common styles use pre-compiled templates
    test_styles = [
      {%{}, "default style"},
      {%{foreground: :red}, "simple red"},
      {%{bold: true}, "simple bold"},
      {%{foreground: :red, bold: true}, "bold red combo"}
    ]

    IO.puts("Testing template matching for common styles:")

    Enum.each(test_styles, fn {style, description} ->
      buffer = ScreenBuffer.new(10, 1)
      ScreenBuffer.write_styled_string(buffer, 0, 0, "test", style)

      renderer = Renderer.new(buffer)
      {time_us, _result} = :timer.tc(fn ->
        Renderer.render(renderer)
      end)

      IO.puts("  #{description}: #{Float.round(time_us / 1.0, 1)}μs")
    end)
  end
end

# Add the project path and run
Code.prepend_path("lib")
Phase3OptimizationTest.run()