defmodule Raxol.Terminal.Operations.ScrollOperations do
  @moduledoc """
  Implements scroll-related operations for the terminal emulator.
  """

  alias Raxol.Terminal.ScreenManager

  def get_scroll_region(emulator) do
    buffer = ScreenManager.get_active_buffer(emulator)
    ScreenManager.get_scroll_region(buffer)
  end

  def set_scroll_region(emulator, region) do
    buffer = ScreenManager.get_active_buffer(emulator)
    new_buffer = ScreenManager.set_scroll_region(buffer, region)
    ScreenManager.update_active_buffer(emulator, new_buffer)
  end

  def get_scroll_top(emulator) do
    buffer = ScreenManager.get_active_buffer(emulator)
    ScreenManager.get_scroll_top(buffer)
  end

  def get_scroll_bottom(emulator) do
    buffer = ScreenManager.get_active_buffer(emulator)
    ScreenManager.get_scroll_bottom(buffer)
  end
end
