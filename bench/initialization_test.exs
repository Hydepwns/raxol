# Test initialization overhead
Logger.configure(level: :error)

alias Raxol.Terminal.Emulator
alias Raxol.Terminal.Parser

IO.puts("Initialization Test")
IO.puts("=" <> String.duplicate("=", 40))

# Force module loading by accessing them
modules = [
  Raxol.Terminal.Parser,
  Raxol.Terminal.Parser.State,
  Raxol.Terminal.Parser.States.GroundState,
  Raxol.Terminal.Input.InputHandler,
  Raxol.Terminal.Input.CharacterProcessor,
  Raxol.Terminal.ANSI.TextFormatting,
  Raxol.Terminal.ANSI.SGRProcessor,
  Raxol.Terminal.ScreenBuffer,
  Raxol.Terminal.EmulatorLite
]

IO.puts("Loading modules...")
for mod <- modules do
  Code.ensure_loaded(mod)
  IO.puts("  #{inspect(mod)}: loaded")
end

IO.puts("\nFirst emulator creation:")
{time1, em1} = :timer.tc(fn -> Emulator.new_minimal(80, 24) end)
IO.puts("  Time: #{time1} μs")

IO.puts("\nSecond emulator creation:")
{time2, em2} = :timer.tc(fn -> Emulator.new_minimal(80, 24) end)
IO.puts("  Time: #{time2} μs")

IO.puts("\nFirst parse (simple text):")
{time_parse1, _} = :timer.tc(fn -> Parser.parse(em1, "Hello") end)
IO.puts("  Time: #{time_parse1} μs")

IO.puts("\nSecond parse (simple text):")
{time_parse2, _} = :timer.tc(fn -> Parser.parse(em1, "Hello") end)
IO.puts("  Time: #{time_parse2} μs")

IO.puts("\nFirst parse with new emulator:")
{time_parse3, _} = :timer.tc(fn -> Parser.parse(em2, "Hello") end)
IO.puts("  Time: #{time_parse3} μs")

# Warm up the parser completely
IO.puts("\nWarming up parser...")
Enum.each(1..10, fn _ -> Parser.parse(em1, "test") end)

IO.puts("\nPost-warmup parse times:")
for i <- 1..5 do
  {time, _} = :timer.tc(fn -> Parser.parse(em1, "Hello World") end)
  IO.puts("  Run #{i}: #{time} μs")
end

# Test ANSI after warmup
IO.puts("\nANSI parse after warmup:")
for i <- 1..5 do
  {time, _} = :timer.tc(fn -> Parser.parse(em1, "\e[31mRed\e[0m") end)
  IO.puts("  Run #{i}: #{time} μs")
end