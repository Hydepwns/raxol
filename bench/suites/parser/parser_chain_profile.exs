# Profile the parser chain to find where time is spent
Logger.configure(level: :error)

alias Raxol.Terminal.Emulator
alias Raxol.Terminal.Parser
alias Raxol.Terminal.Parser.States.GroundState
alias Raxol.Terminal.ANSI.SequenceHandlers
alias Raxol.Terminal.Emulator.ANSIHandler

IO.puts("Parser Chain Profiling")
IO.puts("=" <> String.duplicate("=", 40))

emulator = Emulator.new(80, 24, enable_history: false, alternate_buffer: false)
parser_state = %Raxol.Terminal.Parser.ParserState{state: :ground}

# Warm up
Parser.parse(emulator, "\e[31m")

IO.puts("\n1. Full chain breakdown:")

# Full parse
{time_full, _} = :timer.tc(fn ->
  Enum.each(1..1000, fn _ ->
    Parser.parse(emulator, "\e[31m")
  end)
end)
IO.puts("Full Parser.parse: #{Float.round(time_full/1000, 2)} μs/op")

# Parse chunk (bypasses parse wrapper)
{time_chunk, _} = :timer.tc(fn ->
  Enum.each(1..1000, fn _ ->
    Parser.parse_chunk(emulator, parser_state, "\e[31m")
  end)
end)
IO.puts("Parser.parse_chunk: #{Float.round(time_chunk/1000, 2)} μs/op")

# Ground state directly
{time_ground, _} = :timer.tc(fn ->
  Enum.each(1..1000, fn _ ->
    GroundState.handle(emulator, parser_state, "\e[31m")
  end)
end)
IO.puts("GroundState.handle: #{Float.round(time_ground/1000, 2)} μs/op")

# Sequence parsing
{time_seq, _} = :timer.tc(fn ->
  Enum.each(1..1000, fn _ ->
    SequenceHandlers.parse_ansi_sequence("[31m")
  end)
end)
IO.puts("SequenceHandlers.parse_ansi_sequence: #{Float.round(time_seq/1000, 2)} μs/op")

# ANSI handler
{time_ansi, _} = :timer.tc(fn ->
  Enum.each(1..1000, fn _ ->
    ANSIHandler.handle_ansi_sequences("\e[31m", emulator)
  end)
end)
IO.puts("ANSIHandler.handle_ansi_sequences: #{Float.round(time_ansi/1000, 2)} μs/op")

# SGR handling directly
{time_sgr, _} = :timer.tc(fn ->
  Enum.each(1..1000, fn _ ->
    ANSIHandler.handle_sgr("31", emulator)
  end)
end)
IO.puts("ANSIHandler.handle_sgr: #{Float.round(time_sgr/1000, 2)} μs/op")

IO.puts("\n2. Time breakdown:")
IO.puts("Parse wrapper overhead: #{Float.round(time_full/1000 - time_chunk/1000, 2)} μs")
IO.puts("Parse chunk to ground state: #{Float.round(time_chunk/1000 - time_ground/1000, 2)} μs")
IO.puts("Ground state processing: #{Float.round(time_ground/1000, 2)} μs")
IO.puts("Sequence parsing: #{Float.round(time_seq/1000, 2)} μs")
IO.puts("ANSI handler total: #{Float.round(time_ansi/1000, 2)} μs")
IO.puts("SGR handling: #{Float.round(time_sgr/1000, 2)} μs")

# Test plain text for comparison
IO.puts("\n3. Plain text comparison:")
{time_plain, _} = :timer.tc(fn ->
  Enum.each(1..1000, fn _ ->
    Parser.parse(emulator, "Hello")
  end)
end)
IO.puts("Plain text 'Hello': #{Float.round(time_plain/1000, 2)} μs/op")

{time_ground_plain, _} = :timer.tc(fn ->
  Enum.each(1..1000, fn _ ->
    GroundState.handle(emulator, parser_state, "Hello")
  end)
end)
IO.puts("GroundState plain text: #{Float.round(time_ground_plain/1000, 2)} μs/op")