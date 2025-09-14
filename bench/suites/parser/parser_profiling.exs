# Parser profiling script to identify bottlenecks
Logger.configure(level: :error)

alias Raxol.Terminal.Parser
alias Raxol.Terminal.Emulator

# Create emulator once
emulator = Emulator.new(80, 24)

# Profile different operations
IO.puts("Parser Performance Profiling")
IO.puts("=" <> String.duplicate("=", 40))

# Test 1: Plain text parsing
plain_text = "Hello World"
{time_plain, _} = :timer.tc(fn ->
  Enum.each(1..10_000, fn _ ->
    Parser.parse(emulator, plain_text)
  end)
end)
IO.puts("Plain text (10k iterations): #{Float.round(time_plain/10_000, 2)} μs/op")

# Test 2: Single character
single_char = "a"
{time_single, _} = :timer.tc(fn ->
  Enum.each(1..10_000, fn _ ->
    Parser.parse(emulator, single_char)
  end)
end)
IO.puts("Single char (10k iterations): #{Float.round(time_single/10_000, 2)} μs/op")

# Test 3: Empty string
{time_empty, _} = :timer.tc(fn ->
  Enum.each(1..10_000, fn _ ->
    Parser.parse(emulator, "")
  end)
end)
IO.puts("Empty string (10k iterations): #{Float.round(time_empty/10_000, 2)} μs/op")

# Test 4: Basic ANSI color
color_text = "\e[31mRed\e[0m"
{time_color, _} = :timer.tc(fn ->
  Enum.each(1..1_000, fn _ ->
    Parser.parse(emulator, color_text)
  end)
end)
IO.puts("ANSI color (1k iterations): #{Float.round(time_color/1_000, 2)} μs/op")

# Test 5: Just the parser state creation
{time_state, _} = :timer.tc(fn ->
  Enum.each(1..100_000, fn _ ->
    %Raxol.Terminal.Parser.ParserState{}
  end)
end)
IO.puts("Parser state creation (100k iterations): #{Float.round(time_state/100_000, 2)} μs/op")

# Test 6: String processing without parser
test_string = "Hello World"
{time_string, _} = :timer.tc(fn ->
  Enum.each(1..100_000, fn _ ->
    String.graphemes(test_string)
  end)
end)
IO.puts("String.graphemes (100k iterations): #{Float.round(time_string/100_000, 2)} μs/op")

# Test 7: Binary pattern matching
{time_binary, _} = :timer.tc(fn ->
  Enum.each(1..100_000, fn _ ->
    case test_string do
      <<char::utf8, rest::binary>> -> {char, rest}
      _ -> nil
    end
  end)
end)
IO.puts("Binary pattern match (100k iterations): #{Float.round(time_binary/100_000, 2)} μs/op")