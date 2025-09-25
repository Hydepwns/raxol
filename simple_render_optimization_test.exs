# Simple Phase 3 Render Optimization Test

alias Raxol.Terminal.{ScreenBuffer, Renderer}

defmodule SimpleRenderTest do
  def run do
    IO.puts("=== Phase 3 Render Optimization Test ===")
    IO.puts("Target: <500μs render time")
    IO.puts("")

    # Test basic text rendering
    test_basic_rendering()

    # Test style caching
    test_style_caching()
  end

  defp test_basic_rendering do
    IO.puts("Testing basic text rendering...")

    # Create a simple buffer with text
    buffer = ScreenBuffer.new(80, 24)
    content = "Hello, world! This is a test."
    buffer_with_content = ScreenBuffer.write_string(buffer, 0, 0, content)

    # Test old approach (no batching)
    renderer_old = Renderer.new(buffer_with_content, %{}, %{}, false)
    {time_old, _} = :timer.tc(fn -> Renderer.render(renderer_old) end)

    # Test new approach (with batching and caching)
    renderer_new = Renderer.new(buffer_with_content, %{}, %{}, true)
    {time_new, _} = :timer.tc(fn -> Renderer.render(renderer_new) end)

    improvement = ((time_old - time_new) / time_old * 100.0)

    IO.puts("  Old approach: #{Float.round(time_old / 1.0, 1)}μs")
    IO.puts("  New approach: #{Float.round(time_new / 1.0, 1)}μs")
    IO.puts("  Improvement: #{Float.round(improvement, 1)}%")
    IO.puts("  Target met: #{time_new < 500}")
    IO.puts("")
  end

  defp test_style_caching do
    IO.puts("Testing style caching effectiveness...")

    # Create buffer with styled content
    buffer = ScreenBuffer.new(20, 5)
    style = %{foreground: :red, bold: true}

    # Fill with repeated styled content to test caching
    buffer_with_styles = Enum.reduce(0..4, buffer, fn row, acc ->
      content = "Styled text row #{row}"
      ScreenBuffer.write_styled_string(acc, row, 0, content, style)
    end)

    renderer = Renderer.new(buffer_with_styles)

    # First render - cache misses
    {time1, {_, renderer1}} = :timer.tc(fn ->
      Renderer.render_with_cache(renderer)
    end)

    # Second render - should have cache hits
    {time2, _} = :timer.tc(fn ->
      Renderer.render_with_cache(renderer1)
    end)

    cache_improvement = ((time1 - time2) / time1 * 100.0)

    IO.puts("  First render: #{Float.round(time1 / 1.0, 1)}μs")
    IO.puts("  Second render: #{Float.round(time2 / 1.0, 1)}μs")
    IO.puts("  Cache effectiveness: #{Float.round(cache_improvement, 1)}%")
  end
end

SimpleRenderTest.run()