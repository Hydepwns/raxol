defmodule Raxol.Terminal.Operations.SelectionOperations do
  @moduledoc """
  Implements selection-related operations for the terminal emulator.
  """

  alias Raxol.Terminal.ScreenManager

  def get_selection(emulator) do
    buffer = ScreenManager.get_active_buffer(emulator)
    ScreenManager.get_selection(buffer)
  end

  def get_selection_start(emulator) do
    buffer = ScreenManager.get_active_buffer(emulator)
    ScreenManager.get_selection_start(buffer)
  end

  def get_selection_end(emulator) do
    buffer = ScreenManager.get_active_buffer(emulator)
    ScreenManager.get_selection_end(buffer)
  end

  def get_selection_boundaries(emulator) do
    buffer = ScreenManager.get_active_buffer(emulator)
    ScreenManager.get_selection_boundaries(buffer)
  end

  def start_selection(emulator, x, y) do
    buffer = ScreenManager.get_active_buffer(emulator)
    new_buffer = ScreenManager.start_selection(buffer, x, y)
    ScreenManager.update_active_buffer(emulator, new_buffer)
  end

  def update_selection(emulator, x, y) do
    buffer = ScreenManager.get_active_buffer(emulator)
    new_buffer = ScreenManager.update_selection(buffer, x, y)
    ScreenManager.update_active_buffer(emulator, new_buffer)
  end

  def clear_selection(emulator) do
    buffer = ScreenManager.get_active_buffer(emulator)
    new_buffer = ScreenManager.clear_selection(buffer)
    ScreenManager.update_active_buffer(emulator, new_buffer)
  end

  def selection_active?(emulator) do
    buffer = ScreenManager.get_active_buffer(emulator)
    ScreenManager.selection_active?(buffer)
  end

  def in_selection?(emulator, x, y) do
    buffer = ScreenManager.get_active_buffer(emulator)
    ScreenManager.in_selection?(buffer, x, y)
  end
end
