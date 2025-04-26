defmodule Raxol.Test.EmulatorHelpers do
  @moduledoc """
  Helper functions for Emulator tests.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ScreenBuffer

  @doc """
  Fills a region of the emulator buffer with identifiable line text.
  """
  def fill_buffer(emulator, start_line, end_line) do
    width = ScreenBuffer.get_width(Emulator.get_active_buffer(emulator))

    Enum.reduce(start_line..(end_line - 1), emulator, fn y, emu ->
      # Move to start of line (1-based)
      {emu_moved, _} = Emulator.process_input(emu, "\e[#{y + 1};1H")
      # Write line number and some padding/ellipsis if wide enough
      line_text = "Line #{y}"
      padding_needed = max(0, width - String.length(line_text))

      text_to_write =
        if padding_needed > 20 do
          line_text <>
            String.duplicate(" ", 16) <>
            "..." <> String.duplicate(" ", max(0, padding_needed - 19))
        else
          line_text <> String.duplicate(" ", padding_needed)
        end

      # Write the content for the line
      {emu_written, _} = Emulator.process_input(emu_moved, text_to_write)
      emu_written
    end)
  end

  @doc """
  Retrieves the text content of a specific line from the emulator's active buffer.
  Replaces nil chars with spaces.
  """
  def get_line_text(emulator, line_index) do
    buffer = Emulator.get_active_buffer(emulator)
    line_cells = ScreenBuffer.get_line(buffer, line_index)
    Enum.map_join(line_cells, &(&1.char || " "))
  end
end
