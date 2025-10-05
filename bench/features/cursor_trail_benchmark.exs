
# Cursor Trail Effects Performance Benchmark
# Target: add_position < 50μs, apply < 5ms for 100 positions

alias Raxol.Effects.CursorTrail
alias Raxol.Core.Buffer

buffer = Buffer.create_blank_buffer(80, 24)

# Create trail with various configurations
trail_short = CursorTrail.new(%{max_length: 10})
trail_long = CursorTrail.new(%{max_length: 100})
trail_rainbow = CursorTrail.rainbow()
trail_comet = CursorTrail.comet()
trail_minimal = CursorTrail.minimal()

# Pre-populate trails
trail_with_positions = Enum.reduce(1..50, trail_long, fn i, acc ->
  CursorTrail.add_position(acc, {i, i})
end)

Benchee.run(
  %{
    "new/0" => fn ->
      CursorTrail.new()
    end,
    "new/1 (custom config)" => fn ->
      CursorTrail.new(%{max_length: 50, enabled: true})
    end,
    "rainbow preset" => fn ->
      CursorTrail.rainbow()
    end,
    "comet preset" => fn ->
      CursorTrail.comet()
    end,
    "minimal preset" => fn ->
      CursorTrail.minimal()
    end,
    "add_position (empty)" => fn ->
      CursorTrail.add_position(trail_short, {10, 10})
    end,
    "add_position (short trail)" => fn ->
      trail = Enum.reduce(1..5, trail_short, fn i, acc ->
        CursorTrail.add_position(acc, {i, i})
      end)
      CursorTrail.add_position(trail, {6, 6})
    end,
    "add_position (long trail)" => fn ->
      CursorTrail.add_position(trail_with_positions, {51, 51})
    end,
    "add_position (duplicate)" => fn ->
      trail = CursorTrail.add_position(trail_short, {5, 5})
      CursorTrail.add_position(trail, {5, 5})
    end,
    "interpolate (short)" => fn ->
      CursorTrail.interpolate({0, 0}, {5, 5})
    end,
    "interpolate (long)" => fn ->
      CursorTrail.interpolate({0, 0}, {50, 50})
    end,
    "add_interpolated (short)" => fn ->
      CursorTrail.add_interpolated(trail_short, {0, 0}, {5, 5})
    end,
    "add_interpolated (long)" => fn ->
      CursorTrail.add_interpolated(trail_long, {0, 0}, {50, 50})
    end,
    "apply (empty)" => fn ->
      CursorTrail.apply(trail_short, buffer)
    end,
    "apply (10 positions)" => fn ->
      trail = Enum.reduce(1..10, trail_short, fn i, acc ->
        CursorTrail.add_position(acc, {i * 5, i})
      end)
      CursorTrail.apply(trail, buffer)
    end,
    "apply (50 positions)" => fn ->
      CursorTrail.apply(trail_with_positions, buffer)
    end,
    "apply (100 positions)" => fn ->
      trail = Enum.reduce(1..100, trail_long, fn i, acc ->
        CursorTrail.add_position(acc, {rem(i, 80), rem(i, 24)})
      end)
      CursorTrail.apply(trail, buffer)
    end,
    "apply (rainbow)" => fn ->
      trail = Enum.reduce(1..20, trail_rainbow, fn i, acc ->
        CursorTrail.add_position(acc, {i * 3, i})
      end)
      CursorTrail.apply(trail, buffer)
    end,
    "apply (comet)" => fn ->
      trail = Enum.reduce(1..20, trail_comet, fn i, acc ->
        CursorTrail.add_position(acc, {i * 3, i})
      end)
      CursorTrail.apply(trail, buffer)
    end,
    "apply (with glow)" => fn ->
      trail = CursorTrail.new(%{glow: true, glow_radius: 2, max_length: 20})
      trail = Enum.reduce(1..10, trail, fn i, acc ->
        CursorTrail.add_position(acc, {i * 5, i})
      end)
      CursorTrail.apply(trail, buffer)
    end,
    "clear" => fn ->
      CursorTrail.clear(trail_with_positions)
    end,
    "enable" => fn ->
      trail = CursorTrail.new(%{enabled: false})
      CursorTrail.enable(trail)
    end,
    "disable" => fn ->
      CursorTrail.disable(trail_short)
    end,
    "get_positions" => fn ->
      CursorTrail.get_positions(trail_with_positions)
    end,
    "get_age" => fn ->
      CursorTrail.get_age(trail_with_positions, 25)
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
IO.puts("Target: add_position < 50μs, apply < 5ms for 100 positions")
IO.puts("\nMeasuring key operations:")

measurements = [
  {"new", fn -> CursorTrail.new() end},
  {"add_position", fn -> CursorTrail.add_position(trail_short, {10, 10}) end},
  {"interpolate", fn -> CursorTrail.interpolate({0, 0}, {50, 50}) end},
  {"add_interpolated", fn -> CursorTrail.add_interpolated(trail_long, {0, 0}, {25, 25}) end},
  {"apply (10 pos)", fn ->
    trail = Enum.reduce(1..10, trail_short, fn i, acc ->
      CursorTrail.add_position(acc, {i * 5, i})
    end)
    CursorTrail.apply(trail, buffer)
  end},
  {"apply (100 pos)", fn ->
    trail = Enum.reduce(1..100, trail_long, fn i, acc ->
      CursorTrail.add_position(acc, {rem(i, 80), rem(i, 24)})
    end)
    CursorTrail.apply(trail, buffer)
  end},
  {"apply rainbow", fn ->
    trail = Enum.reduce(1..20, trail_rainbow, fn i, acc ->
      CursorTrail.add_position(acc, {i * 3, i})
    end)
    CursorTrail.apply(trail, buffer)
  end}
]

results = Enum.map(measurements, fn {name, func} ->
  {time_us, _result} = :timer.tc(func)
  target = cond do
    String.contains?(name, "add_position") -> 50
    String.contains?(name, "apply") -> 5000
    String.contains?(name, "interpolate") -> 100
    true -> 50
  end
  status = if time_us < target, do: "PASS", else: "FAIL"
  IO.puts("  #{name}: #{time_us}μs [#{status}]")
  {name, time_us < target}
end)

all_passed = Enum.all?(results, fn {_name, passed} -> passed end)

if all_passed do
  IO.puts("\n[OK] All performance targets met!")
else
  IO.puts("\n[FAIL] Some performance targets not met")
end
