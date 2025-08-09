alias Raxol.Terminal.Parser
alias Raxol.Terminal.Emulator

# Create emulator
emulator = Emulator.new(80, 24)

# Test simple parsing
test_cases = [
  {"simple text", "Hello World"},
  {"color code", "\e[31mRed Text\e[0m"},
  {"cursor move", "\e[10;20H"},
  {"clear screen", "\e[2J"},
  {"complex", "\e[1;31;47mBold Red on White\e[0m"}
]

IO.puts("=== Parser Performance Test ===\n")

Enum.each(test_cases, fn {name, input} ->
  {time, _result} = :timer.tc(fn ->
    Enum.each(1..1000, fn _ -> 
      Parser.parse(emulator, input) 
    end)
  end)
  
  avg_us = time / 1000
  IO.puts("#{String.pad_trailing(name, 15)} => #{Float.round(avg_us, 2)} μs/op")
end)

IO.puts("\n=== Throughput Test ===")

# Large text throughput
large_text = String.duplicate("Lorem ipsum dolor sit amet ", 100)
{time, _} = :timer.tc(fn ->
  Parser.parse(emulator, large_text)
end)

bytes_per_sec = byte_size(large_text) * 1_000_000 / time
IO.puts("Large text: #{byte_size(large_text)} bytes in #{Float.round(time/1000, 2)} ms")
IO.puts("Throughput: #{Float.round(bytes_per_sec / 1_000_000, 2)} MB/s")