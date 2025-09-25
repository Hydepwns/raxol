# Debug what's happening in tests
Logger.configure(level: :error)

alias Raxol.Terminal.Emulator
alias Raxol.Terminal.Parser

# Same setup as test
emulator = Emulator.new(80, 24, enable_history: false, alternate_buffer: false)
ansi_text = "\e[31mRed\e[0m \e[32mGreen\e[0m \e[34mBlue\e[0m"

IO.puts("Emulator type: #{inspect(emulator.__struct__)}")
IO.puts("Has PIDs?: state=#{inspect(emulator.state)}, buffer=#{inspect(emulator.buffer)}")

# Warm up
IO.puts("\nWarmup (5x):")
Enum.each(1..5, fn i ->
  {time, _} = :timer.tc(fn ->
    Parser.parse(emulator, ansi_text)
  end)
  IO.puts("  Warmup #{i}: #{time} μs")
end)

# Actual test
IO.puts("\nTest run (100x):")
{time_us, _} = :timer.tc(fn ->
  Enum.each(1..100, fn _ ->
    Parser.parse(emulator, ansi_text)
  end)
end)

avg_us = time_us / 100
IO.puts("Average: #{Float.round(avg_us, 2)} μs/op")
IO.puts("Total: #{time_us} μs for 100 iterations")

# Check individual times
IO.puts("\nIndividual runs:")
for i <- 1..10 do
  {time, _} = :timer.tc(fn ->
    Parser.parse(emulator, ansi_text)
  end)
  IO.puts("  Run #{i}: #{time} μs")
end