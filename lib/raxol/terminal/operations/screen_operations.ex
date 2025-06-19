defmodule Raxol.Terminal.Operations.ScreenOperations do
  @moduledoc """
  Implements screen-related operations for the terminal emulator.
  """

  alias Raxol.Terminal.ScreenManager

  def clear_screen(emulator) do
    buffer = ScreenManager.get_active_buffer(emulator)
    new_buffer = ScreenManager.clear_screen(buffer)
    ScreenManager.update_active_buffer(emulator, new_buffer)
  end

  def clear_line(emulator, line) do
    buffer = ScreenManager.get_active_buffer(emulator)
    new_buffer = ScreenManager.clear_line(buffer, line)
    ScreenManager.update_active_buffer(emulator, new_buffer)
  end

  def erase_display(emulator, mode) do
    buffer = ScreenManager.get_active_buffer(emulator)
    new_buffer = ScreenManager.erase_display(buffer, mode)
    ScreenManager.update_active_buffer(emulator, new_buffer)
  end

  def erase_in_display(emulator, mode) do
    buffer = ScreenManager.get_active_buffer(emulator)
    new_buffer = ScreenManager.erase_in_display(buffer, mode)
    ScreenManager.update_active_buffer(emulator, new_buffer)
  end

  def erase_line(emulator, mode) do
    buffer = ScreenManager.get_active_buffer(emulator)
    new_buffer = ScreenManager.erase_line(buffer, mode)
    ScreenManager.update_active_buffer(emulator, new_buffer)
  end

  def erase_in_line(emulator, mode) do
    buffer = ScreenManager.get_active_buffer(emulator)
    new_buffer = ScreenManager.erase_in_line(buffer, mode)
    ScreenManager.update_active_buffer(emulator, new_buffer)
  end

  def erase_from_cursor_to_end(emulator) do
    buffer = ScreenManager.get_active_buffer(emulator)
    new_buffer = ScreenManager.erase_from_cursor_to_end(buffer)
    ScreenManager.update_active_buffer(emulator, new_buffer)
  end

  def erase_from_start_to_cursor(emulator) do
    buffer = ScreenManager.get_active_buffer(emulator)
    new_buffer = ScreenManager.erase_from_start_to_cursor(buffer)
    ScreenManager.update_active_buffer(emulator, new_buffer)
  end

  def erase_chars(emulator, count) do
    buffer = ScreenManager.get_active_buffer(emulator)
    new_buffer = ScreenManager.erase_chars(buffer, count)
    ScreenManager.update_active_buffer(emulator, new_buffer)
  end

  def delete_chars(emulator, count) do
    buffer = ScreenManager.get_active_buffer(emulator)
    new_buffer = ScreenManager.delete_chars(buffer, count)
    ScreenManager.update_active_buffer(emulator, new_buffer)
  end

  def insert_chars(emulator, count) do
    buffer = ScreenManager.get_active_buffer(emulator)
    new_buffer = ScreenManager.insert_chars(buffer, count)
    ScreenManager.update_active_buffer(emulator, new_buffer)
  end

  def delete_lines(emulator, count) do
    buffer = ScreenManager.get_active_buffer(emulator)
    new_buffer = ScreenManager.delete_lines(buffer, count)
    ScreenManager.update_active_buffer(emulator, new_buffer)
  end

  def insert_lines(emulator, count) do
    buffer = ScreenManager.get_active_buffer(emulator)
    new_buffer = ScreenManager.insert_lines(buffer, count)
    ScreenManager.update_active_buffer(emulator, new_buffer)
  end

  def prepend_lines(emulator, count) do
    buffer = ScreenManager.get_active_buffer(emulator)
    new_buffer = ScreenManager.prepend_lines(buffer, count)
    ScreenManager.update_active_buffer(emulator, new_buffer)
  end
end
