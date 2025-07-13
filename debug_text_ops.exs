#!/usr/bin/env elixir

# Debug script for text operations
alias Raxol.UI.Components.Input.MultiLineInput.TextOperations
alias Raxol.UI.Components.Input.MultiLineInput.TextOperations.SingleLine
alias Raxol.UI.Components.Input.MultiLineInput.TextOperations.Utils

# Test case from the failing test
lines = ["hello", "world"]
start_pos = {0, 1}
end_pos = {0, 4}
replacement = "ey"

IO.puts("=== Debug Text Replacement ===")
IO.puts("Input lines: #{inspect(lines)}")
IO.puts("Start position: #{inspect(start_pos)}")
IO.puts("End position: #{inspect(end_pos)}")
IO.puts("Replacement: #{inspect(replacement)}")
IO.puts("Replacement length: #{String.length(replacement)}")
IO.puts("Replacement bytes: #{inspect(replacement)}")

# Test the main function
{new_text, replaced_text} =
  TextOperations.replace_text_range(lines, start_pos, end_pos, replacement)

IO.puts("=== Results ===")
IO.puts("New text: #{inspect(new_text)}")
IO.puts("Replaced text: #{inspect(replaced_text)}")

# Test the single-line function directly
{start_row, start_col, end_row, end_col} = {0, 1, 0, 4}
line = Utils.get_line(lines, start_row)
line_length = String.length(line)

IO.puts("=== Single Line Debug ===")
IO.puts("Line: #{inspect(line)}")
IO.puts("Line length: #{line_length}")
IO.puts("Start col: #{start_col}")
IO.puts("End col: #{end_col}")

# Test the replacement logic step by step
start_col_clamped = Utils.clamp(start_col, 0, line_length)
end_col_clamped = Utils.clamp(end_col, 0, line_length)
before = String.slice(line, 0, start_col_clamped)

after_part =
  if end_col_clamped >= line_length do
    ""
  else
    String.slice(line, end_col_clamped, line_length - end_col_clamped)
  end

new_line = before <> replacement <> after_part

IO.puts("=== Step by Step ===")
IO.puts("Start col clamped: #{start_col_clamped}")
IO.puts("End col clamped: #{end_col_clamped}")
IO.puts("Before: #{inspect(before)}")
IO.puts("After part: #{inspect(after_part)}")
IO.puts("New line: #{inspect(new_line)}")

# Expected: "hey" (h + ey + o)
# Actual: "heyo" (h + ey + o)
