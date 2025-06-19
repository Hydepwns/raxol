defmodule Raxol.Terminal.Operations.TextOperations do
  @moduledoc """
  Implements text-related operations for the terminal emulator.
  """

  alias Raxol.Terminal.ScreenManager

  def write_string(emulator, x, y, string, style) do
    buffer = ScreenManager.get_active_buffer(emulator)
    new_buffer = ScreenManager.write_string(buffer, x, y, string, style)
    ScreenManager.update_active_buffer(emulator, new_buffer)
  end

  def get_text_in_region(emulator, x1, y1, x2, y2) do
    buffer = ScreenManager.get_active_buffer(emulator)
    ScreenManager.get_text_in_region(buffer, x1, y1, x2, y2)
  end

  def get_content(emulator) do
    buffer = ScreenManager.get_active_buffer(emulator)
    ScreenManager.get_content(buffer)
  end

  def get_line(emulator, line) do
    buffer = ScreenManager.get_active_buffer(emulator)
    ScreenManager.get_line(buffer, line)
  end

  def get_cell_at(emulator, x, y) do
    buffer = ScreenManager.get_active_buffer(emulator)
    ScreenManager.get_cell(buffer, x, y)
  end
end
