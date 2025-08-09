# Test lightweight emulator performance
Logger.configure(level: :error)

alias Raxol.Terminal.Emulator
alias Raxol.Terminal.EmulatorLite
alias Raxol.Terminal.Parser

IO.puts("Emulator Performance Comparison")
IO.puts("=" <> String.duplicate("=", 40))

# Test 1: Creation time - Original
{time_heavy, _} = :timer.tc(fn ->
  Enum.each(1..100, fn _ ->
    Emulator.new(80, 24)
  end)
end)
IO.puts("Heavy Emulator.new (100x): #{Float.round(time_heavy/100, 2)} μs/op")

# Test 2: Creation time - Lite
{time_lite, _} = :timer.tc(fn ->
  Enum.each(1..100, fn _ ->
    Emulator.new_lite(80, 24)
  end)
end)
IO.puts("Lite Emulator.new_lite (100x): #{Float.round(time_lite/100, 2)} μs/op")

# Test 3: Creation time - Minimal
{time_minimal, _} = :timer.tc(fn ->
  Enum.each(1..100, fn _ ->
    Emulator.new_minimal(80, 24)
  end)
end)
IO.puts("Minimal Emulator.new_minimal (100x): #{Float.round(time_minimal/100, 2)} μs/op")

# Test 4: Direct EmulatorLite creation
{time_direct, _} = :timer.tc(fn ->
  Enum.each(1..1000, fn _ ->
    EmulatorLite.new(80, 24)
  end)
end)
IO.puts("Direct EmulatorLite.new (1000x): #{Float.round(time_direct/1000, 2)} μs/op")

IO.puts("\nSpeedup: #{Float.round(time_heavy/time_minimal, 1)}x")

# Now test parsing with lite emulator
IO.puts("\nParser Performance with Lite Emulator")
IO.puts("-" <> String.duplicate("-", 40))

# Create emulators once
heavy_emulator = Emulator.new(80, 24)
lite_emulator = Emulator.new_lite(80, 24)
minimal_emulator = Emulator.new_minimal(80, 24)

# Test parsing simple text
text = "Hello World"

{time_parse_heavy, _} = :timer.tc(fn ->
  Enum.each(1..1000, fn _ ->
    Parser.parse(heavy_emulator, text)
  end)
end)
IO.puts("Parse with heavy (1000x): #{Float.round(time_parse_heavy/1000, 2)} μs/op")

{time_parse_lite, _} = :timer.tc(fn ->
  Enum.each(1..1000, fn _ ->
    Parser.parse(lite_emulator, text)
  end)
end)
IO.puts("Parse with lite (1000x): #{Float.round(time_parse_lite/1000, 2)} μs/op")

{time_parse_minimal, _} = :timer.tc(fn ->
  Enum.each(1..1000, fn _ ->
    Parser.parse(minimal_emulator, text)
  end)
end)
IO.puts("Parse with minimal (1000x): #{Float.round(time_parse_minimal/1000, 2)} μs/op")

IO.puts("\nParsing speedup: #{Float.round(time_parse_heavy/time_parse_minimal, 1)}x")

# Test with ANSI sequences
ansi_text = "\e[31mRed\e[0m"

{time_ansi_heavy, _} = :timer.tc(fn ->
  Enum.each(1..100, fn _ ->
    Parser.parse(heavy_emulator, ansi_text)
  end)
end)
IO.puts("\nANSI parsing:")
IO.puts("Heavy (100x): #{Float.round(time_ansi_heavy/100, 2)} μs/op")

{time_ansi_minimal, _} = :timer.tc(fn ->
  Enum.each(1..100, fn _ ->
    Parser.parse(minimal_emulator, ansi_text)
  end)
end)
IO.puts("Minimal (100x): #{Float.round(time_ansi_minimal/100, 2)} μs/op")
IO.puts("Speedup: #{Float.round(time_ansi_heavy/time_ansi_minimal, 1)}x")