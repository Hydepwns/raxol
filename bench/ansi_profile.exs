# Profile ANSI parsing to find bottlenecks
Logger.configure(level: :error)

alias Raxol.Terminal.Emulator
alias Raxol.Terminal.Parser
alias Raxol.Terminal.Parser.States.{GroundState, EscapeState, CSIParamState}
alias Raxol.Terminal.ANSI.{SGRProcessor, SequenceHandlers}

IO.puts("ANSI Parsing Profile")
IO.puts("=" <> String.duplicate("=", 40))

# Create minimal emulator
emulator = Emulator.new_minimal(80, 24)

# Warm up everything
Parser.parse(emulator, "\e[31mWarmup\e[0m")

# Test individual components
IO.puts("\n1. Component-level timing:")

# Test SGR processing alone
style = %Raxol.Terminal.ANSI.TextFormatting{}
{time_sgr, _} = :timer.tc(fn ->
  Enum.each(1..1000, fn _ ->
    SGRProcessor.process_sgr_codes([31], style)
  end)
end)
IO.puts("SGRProcessor.process [31]: #{Float.round(time_sgr/1000, 2)} μs/op")

{time_sgr_reset, _} = :timer.tc(fn ->
  Enum.each(1..1000, fn _ ->
    SGRProcessor.process_sgr_codes([0], style)
  end)
end)
IO.puts("SGRProcessor.process [0]: #{Float.round(time_sgr_reset/1000, 2)} μs/op")

# Test sequence parsing
{time_parse_seq, _} = :timer.tc(fn ->
  Enum.each(1..1000, fn _ ->
    SequenceHandlers.parse_ansi_sequence("[31m")
  end)
end)
IO.puts("SequenceHandlers.parse_ansi_sequence: #{Float.round(time_parse_seq/1000, 2)} μs/op")

# Test full parser with different inputs
IO.puts("\n2. Parser timing by input type:")

test_cases = [
  {"Plain text", "Hello World"},
  {"Single ESC", "\e"},
  {"ESC[", "\e["},
  {"ESC[31", "\e[31"},
  {"ESC[31m", "\e[31m"},
  {"Complete color", "\e[31mRed\e[0m"},
  {"Just reset", "\e[0m"},
  {"Two params", "\e[1;31m"},
  {"Movement", "\e[5;10H"},
  {"Clear screen", "\e[2J"}
]

for {name, input} <- test_cases do
  # Warm up this specific pattern
  Parser.parse(emulator, input)
  
  {time, _} = :timer.tc(fn ->
    Enum.each(1..100, fn _ ->
      Parser.parse(emulator, input)
    end)
  end)
  
  IO.puts("#{String.pad_trailing(name, 15)}: #{Float.round(time/100, 2)} μs/op")
end

# Test parser state transitions
IO.puts("\n3. State machine transitions:")

parser_state = %Raxol.Terminal.Parser.ParserState{state: :ground}

# Test ground state with plain text
{time_ground, _} = :timer.tc(fn ->
  Enum.each(1..1000, fn _ ->
    GroundState.handle(emulator, parser_state, "Hello")
  end)
end)
IO.puts("GroundState.handle (plain): #{Float.round(time_ground/1000, 2)} μs/op")

# Test ground state with ESC
{time_ground_esc, _} = :timer.tc(fn ->
  Enum.each(1..1000, fn _ ->
    GroundState.handle(emulator, parser_state, <<27>>)
  end)
end)
IO.puts("GroundState.handle (ESC): #{Float.round(time_ground_esc/1000, 2)} μs/op")

# Profile memory allocations
IO.puts("\n4. Memory analysis:")

# Measure memory before
before_mem = :erlang.memory(:total)

# Parse ANSI 1000 times
Enum.each(1..1000, fn _ ->
  Parser.parse(emulator, "\e[31mTest\e[0m")
end)

after_mem = :erlang.memory(:total)
mem_per_op = (after_mem - before_mem) / 1000
IO.puts("Memory per parse: #{Float.round(mem_per_op, 2)} bytes")

# Check what's being created
IO.puts("\n5. Object creation analysis:")

# Count process dictionary size changes
initial_pd = Process.get() |> length()
Parser.parse(emulator, "\e[31mTest\e[0m")
final_pd = Process.get() |> length()
IO.puts("Process dict entries created: #{final_pd - initial_pd}")

# Check if we're creating unnecessary intermediate structures
{time_direct, result1} = :timer.tc(fn ->
  Parser.parse(emulator, "\e[31mDirect\e[0m")
end)

{time_chunked, result2} = :timer.tc(fn ->
  Parser.parse_chunk(emulator, nil, "\e[31mChunked\e[0m")
end)

IO.puts("\n6. Parse vs parse_chunk:")
IO.puts("Parser.parse: #{time_direct} μs")
IO.puts("Parser.parse_chunk: #{time_chunked} μs")
IO.puts("Difference: #{time_direct - time_chunked} μs")