#!/usr/bin/env elixir

Mix.Task.run("app.start")

# Run tests and capture output
{output, _} = System.cmd("mix", ["test", "--trace"], stderr_to_stdout: true)

# Write output to a temporary file for analysis
File.write!("test_output.tmp", output)

# Read the output back
{:ok, content} = File.read("test_output.tmp")

# Clean up
File.rm("test_output.tmp")

# Analyze the output
analysis = Raxol.TestAnalyzer.analyze_test_output(content)

# Print summary
IO.puts("\nTest Analysis Summary:")
IO.puts("====================")
IO.puts("Total Failures: #{analysis.total_failures}")
IO.puts("Total Skipped: #{analysis.total_skipped}")
IO.puts("Total Invalid: #{analysis.total_invalid}")

# Categorize and print failures
IO.puts("\nFailure Categories:")
IO.puts("=================")
categories = Raxol.TestAnalyzer.categorize_failures(analysis.failures)

Enum.each(categories, fn {category, failures} ->
  IO.puts("\n#{String.upcase("#{category}")} (#{length(failures)}):")
  Enum.each(failures, &IO.puts("  #{&1}"))
end)

# Print skipped tests
if analysis.skipped != [] do
  IO.puts("\nSkipped Tests:")
  IO.puts("=============")
  Enum.each(analysis.skipped, &IO.puts("  #{&1}"))
end

# Print invalid tests
if analysis.invalid != [] do
  IO.puts("\nInvalid Tests:")
  IO.puts("=============")
  Enum.each(analysis.invalid, &IO.puts("  #{&1}"))
end
