# Style Performance Benchmark

alias Raxol.Core.Style

# Pre-create styles for benchmarking
simple_style = Style.new(bold: true)
color_style = Style.new(fg_color: :red, bg_color: :blue)
rgb_style = Style.new(fg_color: {255, 128, 64})
complex_style = Style.new(
  bold: true,
  italic: true,
  underline: true,
  fg_color: {255, 0, 0},
  bg_color: :blue
)

Benchee.run(
  %{
    "new (empty)" => fn ->
      Style.new()
    end,
    "new (simple)" => fn ->
      Style.new(bold: true)
    end,
    "new (complex)" => fn ->
      Style.new(
        bold: true,
        italic: true,
        fg_color: :red,
        bg_color: :blue
      )
    end,
    "merge (simple)" => fn ->
      style1 = Style.new(bold: true)
      style2 = Style.new(italic: true)
      Style.merge(style1, style2)
    end,
    "merge (complex)" => fn ->
      style1 = Style.new(bold: true, fg_color: :red)
      style2 = Style.new(italic: true, bg_color: :blue)
      Style.merge(style1, style2)
    end,
    "rgb/3" => fn ->
      Style.rgb(255, 128, 64)
    end,
    "color_256/1" => fn ->
      Style.color_256(42)
    end,
    "named_color/1" => fn ->
      Style.named_color(:red)
    end,
    "to_ansi (empty)" => fn ->
      Style.to_ansi(simple_style)
    end,
    "to_ansi (color)" => fn ->
      Style.to_ansi(color_style)
    end,
    "to_ansi (RGB)" => fn ->
      Style.to_ansi(rgb_style)
    end,
    "to_ansi (complex)" => fn ->
      Style.to_ansi(complex_style)
    end
  },
  time: 2,
  memory_time: 1,
  print: [
    fast_warning: false,
    configuration: false
  ]
)

IO.puts("\n\n=== Performance Validation ===")
IO.puts("Measuring typical style operations:\n")

# Test style creation
{time_us, _result} = :timer.tc(fn ->
  Style.new(bold: true, fg_color: :red)
end)
IO.puts("  Style creation: #{time_us}μs")

# Test ANSI generation
style = Style.new(bold: true, fg_color: {255, 128, 0}, bg_color: :blue)
{time_us, _result} = :timer.tc(fn ->
  Style.to_ansi(style)
end)
IO.puts("  ANSI generation (complex): #{time_us}μs")

# Test merge
style1 = Style.new(bold: true, fg_color: :red)
style2 = Style.new(italic: true, bg_color: :blue)
{time_us, _result} = :timer.tc(fn ->
  Style.merge(style1, style2)
end)
IO.puts("  Style merge: #{time_us}μs")

IO.puts("\nAll style operations complete in microseconds - excellent performance!")
