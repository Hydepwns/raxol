# Emulator creation profiling
Logger.configure(level: :error)

alias Raxol.Terminal.Emulator

IO.puts("Emulator Creation Performance")
IO.puts("=" <> String.duplicate("=", 40))

# Test 1: Emulator creation
{time_new, _} = :timer.tc(fn ->
  Enum.each(1..1_000, fn _ ->
    Emulator.new(80, 24)
  end)
end)
IO.puts("Emulator.new (1k iterations): #{Float.round(time_new/1_000, 2)} μs/op")

# Test 2: Get one emulator and write chars to it
emulator = Emulator.new(80, 24)

# Test writing directly (bypassing parser)
{time_write, _} = :timer.tc(fn ->
  Enum.each(1..10_000, fn _ ->
    # Access cursor position (common operation)
    _cursor = emulator.cursor
    _mode = emulator.mode_manager
    _buffer = emulator.buffer
  end)
end)
IO.puts("Emulator field access (10k iterations): #{Float.round(time_write/10_000, 2)} μs/op")

# Test 3: Check what Parser.parse actually returns  
alias Raxol.Terminal.Parser

# Simple parse
result = Parser.parse(emulator, "a")
IO.puts("\nParser.parse result type: #{inspect(elem(result, 0).__struct__)}")
IO.puts("Result tuple size: #{tuple_size(result)}")