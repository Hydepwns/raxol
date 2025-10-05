# Renderer Performance Benchmark
# Targets:
# - render_to_string: < 1ms for 80x24 buffer
# - render_diff: < 2ms for 80x24 buffer

alias Raxol.Core.{Buffer, Renderer}

# Create test buffers
buffer_small = Buffer.create_blank_buffer(40, 12)
buffer_large = Buffer.create_blank_buffer(80, 24)

buffer_with_text = Buffer.write_at(buffer_large, 0, 0, "Hello, World!")

buffer_old = Buffer.create_blank_buffer(80, 24)
buffer_new_small_change = Buffer.write_at(buffer_old, 40, 12, "X")
buffer_new_large_change = buffer_old
|> Buffer.write_at(0, 0, String.duplicate("Test ", 16))
|> Buffer.write_at(0, 1, String.duplicate("More ", 16))
|> Buffer.write_at(0, 2, String.duplicate("Text ", 16))

Benchee.run(
  %{
    "render_to_string (40x12)" => fn ->
      Renderer.render_to_string(buffer_small)
    end,
    "render_to_string (80x24)" => fn ->
      Renderer.render_to_string(buffer_large)
    end,
    "render_to_string (with text)" => fn ->
      Renderer.render_to_string(buffer_with_text)
    end,
    "render_diff (identical)" => fn ->
      Renderer.render_diff(buffer_old, buffer_old)
    end,
    "render_diff (1 cell)" => fn ->
      Renderer.render_diff(buffer_old, buffer_new_small_change)
    end,
    "render_diff (many cells)" => fn ->
      Renderer.render_diff(buffer_old, buffer_new_large_change)
    end,
    "render_diff (dimensions change)" => fn ->
      Renderer.render_diff(buffer_small, buffer_large)
    end
  },
  time: 2,
  memory_time: 1,
  print: [
    fast_warning: false,
    configuration: false
  ]
)

# Performance validation
IO.puts("\n\n=== Performance Target Validation ===")
IO.puts("Target: render_to_string < 1ms, render_diff < 2ms")
IO.puts("\nMeasuring operations:")

# Test render_to_string
{time_us, _result} = :timer.tc(fn ->
  Renderer.render_to_string(buffer_large)
end)

render_status = if time_us < 1000, do: "PASS", else: "FAIL"
IO.puts("  render_to_string(80x24): #{time_us}μs [#{render_status}]")

# Test render_diff
{time_us, _result} = :timer.tc(fn ->
  Renderer.render_diff(buffer_old, buffer_new_small_change)
end)

diff_status = if time_us < 2000, do: "PASS", else: "FAIL"
IO.puts("  render_diff(1 change): #{time_us}μs [#{diff_status}]")

all_passed = render_status == "PASS" and diff_status == "PASS"

if all_passed do
  IO.puts("\n✓ All performance targets met!")
else
  IO.puts("\n✗ Some performance targets not met")
end
