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
    Enum.reduce(start_line..(end_line - 1), emulator, fn y, emu ->
      # Move to start of line y (0-based index -> y+1 is 1-based row)
      {emu_moved, _} = Emulator.process_input(emu, "\e[#{y + 1};1H")
      # Write line number y
      line_text = "Line #{y}"
      # SIMPLIFIED: Just write the line text, let emulator handle rest
      text_to_write = line_text

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
    # IO.puts("get_line_text(#{line_index}):") # DEBUG
    buffer = Emulator.get_active_buffer(emulator)
    line_cells = ScreenBuffer.get_line(buffer, line_index)
    # IO.inspect(line_cells, label: "  -> line_cells for #{line_index}", limit: :infinity) # DEBUG
    text = Enum.map_join(line_cells, &(&1.char || " "))
    # IO.inspect(text, label: "  -> joined text for #{line_index}") # DEBUG
    text
  end
end
