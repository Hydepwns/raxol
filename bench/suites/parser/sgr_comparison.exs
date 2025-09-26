# Compare SGR processor performance
Logger.configure(level: :error)

alias Raxol.Terminal.ANSI.{SGRProcessor, SGRProcessorOptimized, TextFormatting}

IO.puts("SGR Processor Performance Comparison")
IO.puts("=" <> String.duplicate("=", 40))

style = TextFormatting.new()

test_cases = [
  {"Reset [0]", [0]},
  {"Red [31]", [31]},
  {"Bold red [1, 31]", [1, 31]},
  {"Complex [1, 4, 31, 43]", [1, 4, 31, 43]},
  {"256 color [38, 5, 196]", [38, 5, 196]},
  {"RGB [38, 2, 255, 0, 0]", [38, 2, 255, 0, 0]}
]

IO.puts("\nOriginal SGRProcessor:")

for {name, codes} <- test_cases do
  {time, _} =
    :timer.tc(fn ->
      Enum.each(1..1000, fn _ ->
        SGRProcessor.process_sgr_codes(codes, style)
      end)
    end)

  IO.puts(
    "  #{String.pad_trailing(name, 25)}: #{Float.round(time / 1000, 2)} μs/op"
  )
end

IO.puts("\nOptimized SGRProcessor:")

for {name, codes} <- test_cases do
  {time, _} =
    :timer.tc(fn ->
      Enum.each(1..1000, fn _ ->
        SGRProcessorOptimized.process_sgr_codes(codes, style)
      end)
    end)

  IO.puts(
    "  #{String.pad_trailing(name, 25)}: #{Float.round(time / 1000, 2)} μs/op"
  )
end

# Test with string params
IO.puts("\nString parameter parsing:")

string_tests = [
  {"Empty", ""},
  {"0", "0"},
  {"31", "31"},
  {"1;31", "1;31"},
  {"38;5;196", "38;5;196"},
  {"38;2;255;0;0", "38;2;255;0;0"}
]

IO.puts("\nOriginal process() - uses process_sgr_codes:")

for {name, params} <- string_tests do
  {time, _} =
    :timer.tc(fn ->
      Enum.each(1..1000, fn _ ->
        codes =
          try do
            params |> String.split(";") |> Enum.map(&String.to_integer(&1, 10))
          rescue
            _ -> [0]
          end

        SGRProcessor.process_sgr_codes(codes, style)
      end)
    end)

  IO.puts(
    "  #{String.pad_trailing(name, 15)}: #{Float.round(time / 1000, 2)} μs/op"
  )
end

IO.puts("\nOptimized process():")

for {name, params} <- string_tests do
  {time, _} =
    :timer.tc(fn ->
      Enum.each(1..1000, fn _ ->
        SGRProcessorOptimized.process(params, style)
      end)
    end)

  IO.puts(
    "  #{String.pad_trailing(name, 15)}: #{Float.round(time / 1000, 2)} μs/op"
  )
end

# Verify correctness
IO.puts("\nCorrectness check:")

for {name, codes} <- test_cases do
  original = SGRProcessor.process_sgr_codes(codes, style)
  optimized = SGRProcessorOptimized.process_sgr_codes(codes, style)
  match = original == optimized
  IO.puts("  #{String.pad_trailing(name, 25)}: #{if match, do: "[OK]", else: "[FAIL]"}")

  if not match do
    IO.puts("    Original:  #{inspect(original)}")
    IO.puts("    Optimized: #{inspect(optimized)}")
  end
end
