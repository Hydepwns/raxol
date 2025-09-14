# Verify optimization is being used
Logger.configure(level: :error)

alias Raxol.Terminal.Emulator
alias Raxol.Terminal.Parser
alias Raxol.Terminal.ANSI.{SGRProcessor, SGRProcessorOptimized}

IO.puts("Verifying Optimization Usage")
IO.puts("=" <> String.duplicate("=", 40))

# Test SGR processors directly
style = %Raxol.Terminal.ANSI.TextFormatting{}

IO.puts("\n1. Direct SGR processor test:")
{time_old, _} = :timer.tc(fn ->
  Enum.each(1..1000, fn _ ->
    SGRProcessor.process_sgr_codes([31], style)
  end)
end)
IO.puts("Original SGRProcessor [31]: #{Float.round(time_old/1000, 2)} μs/op")

{time_new, _} = :timer.tc(fn ->
  Enum.each(1..1000, fn _ ->
    SGRProcessorOptimized.process_sgr_codes([31], style)
  end)
end)
IO.puts("Optimized SGRProcessor [31]: #{Float.round(time_new/1000, 2)} μs/op")
IO.puts("Speedup: #{Float.round(time_old/time_new, 1)}x")

# Test through the parser
emulator = Emulator.new_minimal(80, 24)

# Warm up
Parser.parse(emulator, "\e[31mWarmup\e[0m")

IO.puts("\n2. Through parser (after warmup):")
test_inputs = [
  {"ESC[31m", "\e[31m"},
  {"ESC[0m", "\e[0m"},
  {"Color text", "\e[31mRed\e[0m"}
]

for {name, input} <- test_inputs do
  {time, _} = :timer.tc(fn ->
    Enum.each(1..100, fn _ ->
      Parser.parse(emulator, input)
    end)
  end)
  IO.puts("#{String.pad_trailing(name, 12)}: #{Float.round(time/100, 2)} μs/op")
end

# Check which processor is actually loaded
IO.puts("\n3. Module check:")
IO.puts("SGRProcessor module: #{inspect(SGRProcessor)}")
IO.puts("Functions available: #{SGRProcessor.__info__(:functions) |> Keyword.keys() |> Enum.sort() |> inspect()}")

# Check if ANSIHandler is using the right one
alias Raxol.Terminal.Emulator.ANSIHandler
IO.puts("\n4. ANSIHandler check:")
code = """
defmodule TestCheck do
  def check do
    # See what SGRProcessor resolves to in ANSIHandler context
    alias Raxol.Terminal.ANSI.SGRProcessorOptimized, as: SGRProcessor
    SGRProcessor
  end
end
"""
Code.eval_string(code)
IO.puts("ANSIHandler's SGRProcessor: #{TestCheck.check()}")