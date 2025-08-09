# Debug ANSI performance issues
Logger.configure(level: :error)

alias Raxol.Terminal.Emulator
alias Raxol.Terminal.Parser

IO.puts("ANSI Performance Debug")
IO.puts("=" <> String.duplicate("=", 40))

# Test with minimal emulator
emulator = Emulator.new_minimal(80, 24)

# Test different ANSI patterns
patterns = [
  {"Simple text", "Hello"},
  {"Single color", "\e[31mRed\e[0m"},
  {"Just ESC[31m", "\e[31m"},
  {"Just ESC[0m", "\e[0m"},
  {"Two colors", "\e[31mRed\e[32mGreen\e[0m"},
  {"Complex", "\e[H\e[2J\e[3;10H\e[1;33mHello\e[0m"}
]

for {name, text} <- patterns do
  {time_us, _result} =
    :timer.tc(fn ->
      Parser.parse(emulator, text)
    end)

  IO.puts("#{String.pad_trailing(name, 15)}: #{time_us} μs")
end

# Test repeated parsing to see if there's state accumulation
IO.puts("\nRepeated parsing (100x each):")

for {name, text} <- patterns do
  {time_us, _} =
    :timer.tc(fn ->
      Enum.each(1..100, fn _ ->
        Parser.parse(emulator, text)
      end)
    end)

  avg_us = time_us / 100
  IO.puts("#{String.pad_trailing(name, 15)}: #{Float.round(avg_us, 2)} μs/op")
end

# Check if emulator creation in loop is the issue
IO.puts("\nWith fresh emulator each time (10x):")
text = "\e[31mRed\e[0m"

{time_fresh, _} =
  :timer.tc(fn ->
    Enum.each(1..10, fn _ ->
      fresh_emulator = Emulator.new_minimal(80, 24)
      Parser.parse(fresh_emulator, text)
    end)
  end)

IO.puts("Fresh emulator: #{Float.round(time_fresh / 10, 2)} μs/op")

# Same emulator reused
{time_reused, _} =
  :timer.tc(fn ->
    Enum.each(1..10, fn _ ->
      Parser.parse(emulator, text)
    end)
  end)

IO.puts("Reused emulator: #{Float.round(time_reused / 10, 2)} μs/op")
