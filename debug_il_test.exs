#!/usr/bin/env elixir

# Debug script for IL Insert Line issue

Mix.install([])

defmodule DebugIL do
  def run do
    IO.puts("Analysis of IL Insert Line test failure:")

    IO.puts("\nTest setup:")
    IO.puts("- 5x5 buffer")
    IO.puts("- fill_buffer writes 'Line 0', 'Line 1', 'Line 2', 'Line 3', 'Line 4'")
    IO.puts("- Set scroll region 2-4 (indices 1-3)")
    IO.puts("- Move cursor to row 3 (index 2)")
    IO.puts("- Insert 2 lines with \\e[2L")

    IO.puts("\nExpected result after IL:")
    IO.puts("- Line 0: 'Line0' (unchanged - outside scroll region)")
    IO.puts("- Line 1: 'Line1' (unchanged - outside scroll region)")
    IO.puts("- Line 2: '     ' (new blank line - inserted)")
    IO.puts("- Line 3: '     ' (new blank line - inserted)")
    IO.puts("- Line 4: 'Line4' (unchanged - outside scroll region)")

    IO.puts("\nActual debug output shows:")
    IO.puts("- Line 0: 'Line ' (truncated)")
    IO.puts("- Line 1: 'Line ' (truncated)")
    IO.puts("- Line 2: '     ' (correct)")
    IO.puts("- Line 3: '     ' (correct)")
    IO.puts("- Line 4: 'Line ' (truncated)")

    IO.puts("\nPossible issues:")
    IO.puts("1. Buffer width (5) truncating 'Line0' to 'Line ' (4+1 space)")
    IO.puts("2. ScreenBuffer.get_line() returning nil causing Protocol.UndefinedError")
    IO.puts("3. Insert Line operation affecting wrong lines")

    IO.puts("\nWidth analysis:")
    IO.puts("- 'Line 0' = 6 characters, but buffer width = 5")
    IO.puts("- So 'Line 0' gets truncated to 'Line ' (5 chars)")
    IO.puts("- This explains the truncation but not the nil issue")

    IO.puts("\nThe actual error is Protocol.UndefinedError on Enumerable")
    IO.puts("This means ScreenBuffer.get_line(buffer, y) is returning nil")
    IO.puts("instead of a list of cells for some line.")
  end
end

DebugIL.run()