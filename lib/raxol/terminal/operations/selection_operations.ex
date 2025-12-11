defmodule Raxol.Terminal.Operations.SelectionOperations do
  @moduledoc """
  Implements selection-related operations for the terminal emulator.
  """

  alias Raxol.Terminal.ScreenManager

  def write_string(emulator, x, y, string, style) do
    buffer = ScreenManager.get_screen_buffer(emulator)
    new_buffer = ScreenManager.write_string(buffer, x, y, string, style)
    ScreenManager.update_active_buffer(emulator, new_buffer)
  end

  def get_selection(emulator) do
    buffer = ScreenManager.get_screen_buffer(emulator)
    ScreenManager.get_selected_text(buffer)
  end

  def get_selection_start(emulator) do
    buffer = ScreenManager.get_screen_buffer(emulator)
    ScreenManager.get_selection_start(buffer)
  end

  def get_selection_end(emulator) do
    buffer = ScreenManager.get_screen_buffer(emulator)
    ScreenManager.get_selection_end(buffer)
  end

  def get_selection_boundaries(emulator) do
    buffer = ScreenManager.get_screen_buffer(emulator)

    # Return selection boundaries as-is (already in {{x, y}, {x, y}} format or nil)
    ScreenManager.get_selection_boundaries(buffer)
  end

  def start_selection(emulator, x, y) do
    buffer = ScreenManager.get_screen_buffer(emulator)
    new_buffer = ScreenManager.start_selection(buffer, x, y)
    ScreenManager.update_active_buffer(emulator, new_buffer)
  end

  def update_selection(emulator, x, y) do
    buffer = ScreenManager.get_screen_buffer(emulator)
    new_buffer = ScreenManager.update_selection(buffer, x, y)
    ScreenManager.update_active_buffer(emulator, new_buffer)
  end

  def clear_selection(emulator) do
    buffer = ScreenManager.get_screen_buffer(emulator)
    new_buffer = ScreenManager.clear_selection(buffer)
    ScreenManager.update_active_buffer(emulator, new_buffer)
  end

  def selection_active?(emulator) do
    buffer = ScreenManager.get_screen_buffer(emulator)
    ScreenManager.selection_active?(buffer)
  end

  def in_selection?(emulator, x, y) do
    buffer = ScreenManager.get_screen_buffer(emulator)
    ScreenManager.in_selection?(buffer, x, y)
  end

  def end_selection(emulator) do
    # End the current selection - for now just clear it
    clear_selection(emulator)
  end

  def has_selection?(emulator) do
    # Check if there's an active selection - for now just check if selection is active
    selection_active?(emulator)
  end
end
