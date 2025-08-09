# Disable all logging for this test
Logger.configure(level: :error)

alias Raxol.Terminal.Parser
alias Raxol.Terminal.Emulator

# Create emulator
emulator = Emulator.new(80, 24)

# Test a simple string multiple times
test_string = "Hello World"
iterations = 10_000

IO.puts("Testing parser performance...")
{time_us, _} = :timer.tc(fn ->
  Enum.each(1..iterations, fn _ ->
    Parser.parse(emulator, test_string)
  end)
end)

avg_us = time_us / iterations
ops_per_sec = 1_000_000 / avg_us

IO.puts("Iterations: #{iterations}")
IO.puts("Total time: #{Float.round(time_us/1000, 2)} ms")
IO.puts("Average: #{Float.round(avg_us, 2)} μs/op")
IO.puts("Throughput: #{Float.round(ops_per_sec, 0)} ops/sec")

# Now test with actual parsing work
ansi_string = "\e[31mRed\e[0m \e[32mGreen\e[0m \e[34mBlue\e[0m"
{time_us2, _} = :timer.tc(fn ->
  Enum.each(1..1000, fn _ ->
    Parser.parse(emulator, ansi_string)
  end)
end)

avg_us2 = time_us2 / 1000
IO.puts("\nANSI string test:")
IO.puts("Average: #{Float.round(avg_us2, 2)} μs/op")
IO.puts("Throughput: #{Float.round(1_000_000 / avg_us2, 0)} ops/sec")