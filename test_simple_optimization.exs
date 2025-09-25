# Test Simple Render Optimization

alias Raxol.Terminal.{ScreenBuffer, Renderer}

# Create basic buffer
buffer = ScreenBuffer.new(80, 24)
buffer_with_text = ScreenBuffer.write_string(buffer, 0, 0, "Hello world! This is a performance test.")

# Test old approach (no batching)
renderer_old = Renderer.new(buffer_with_text, %{}, %{}, false)
{time_old, result_old} = :timer.tc(fn -> Renderer.render(renderer_old) end)

# Test new approach (with batching and templates)
renderer_new = Renderer.new(buffer_with_text, %{}, %{}, true)
{time_new, result_new} = :timer.tc(fn -> Renderer.render(renderer_new) end)

improvement = ((time_old - time_new) / time_old * 100.0)

IO.puts("=== Simple Render Optimization Test ===")
IO.puts("Old approach: #{Float.round(time_old / 1.0, 1)}μs")
IO.puts("New approach: #{Float.round(time_new / 1.0, 1)}μs")
IO.puts("Improvement: #{Float.round(improvement, 1)}%")
IO.puts("Target met (<500μs): #{time_new < 500}")
IO.puts("Results identical: #{result_old == result_new}")