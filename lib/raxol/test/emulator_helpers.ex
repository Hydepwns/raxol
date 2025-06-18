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
    result =
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

    # Ensure the original result (emulator struct) is returned
    result
  end

  @doc """
  Retrieves the text content of a specific line from the emulator's active buffer.
  Replaces nil chars with spaces.
  """
  def get_line_text(emulator, line_index) do
    # IO.puts("get_line_text(#{line_index}):") # DEBUG
    buffer = Emulator.get_active_buffer(emulator)
    line_cells = ScreenBuffer.get_line(buffer, line_index)

    text = Enum.map_join(line_cells, &(&1.char || " "))
    text
  end

  @doc """
  Unwraps {:ok, value}, {:error, _, value}, or returns value if already a struct.
  Useful for safely extracting emulator or buffer structs from handler results.
  """
  def unwrap_ok({:ok, value}), do: value
  def unwrap_ok({:error, _, value}), do: value

  def unwrap_ok(value) when is_map(value) and not is_struct(value) do
    # If it's a plain map (and not a struct, since structs are maps), return as is.
    # This case might be hit if some code legitimately returns a map that needs unwrapping.
    # However, if it was intended to be an emulator and became a map, that's an issue elsewhere.
    value
  end

  # If it's a struct (including Emulator struct), or any other type, return as is.
  def unwrap_ok(value), do: value
end
