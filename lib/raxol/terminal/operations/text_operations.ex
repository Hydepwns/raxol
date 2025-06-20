defmodule Raxol.Terminal.Operations.TextOperations do
  @moduledoc """
  Implements text-related operations for the terminal emulator.
  """

  alias Raxol.Terminal.{ScreenManager, ScreenBuffer}

  def write_string(emulator, x, y, string, style) do
    buffer = ScreenManager.get_active_buffer(emulator)
    new_buffer = ScreenBuffer.write_string(buffer, x, y, string, style)
    ScreenManager.update_active_buffer(emulator, new_buffer)
  end

  def get_text_in_region(emulator, x1, y1, x2, y2) do
    buffer = ScreenManager.get_active_buffer(emulator)
    ScreenBuffer.get_text_in_region(buffer, x1, y1, x2, y2)
  end

  def get_content(emulator) do
    buffer = ScreenManager.get_active_buffer(emulator)
    ScreenBuffer.get_content(buffer)
  end

  def get_line(emulator, line) do
    buffer = ScreenManager.get_active_buffer(emulator)
    # Get the line directly from the buffer cells
    if line >= 0 and line < buffer.height do
      buffer.cells
      |> Enum.at(line, [])
      |> Enum.map(& &1.char)
      |> Enum.join()
      |> String.trim_trailing()
    else
      ""
    end
  end

  def get_cell_at(emulator, x, y) do
    buffer = ScreenManager.get_active_buffer(emulator)
    ScreenBuffer.get_cell(buffer, x, y)
  end
end
