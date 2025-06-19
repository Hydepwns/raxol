defmodule Raxol.Terminal.Operations.StateOperations do
  @moduledoc """
  Implements state-related operations for the terminal emulator.
  """

  alias Raxol.Terminal.ScreenManager

  def get_state(emulator) do
    buffer = ScreenManager.get_active_buffer(emulator)
    ScreenManager.get_state(buffer)
  end

  def get_style(emulator) do
    buffer = ScreenManager.get_active_buffer(emulator)
    ScreenManager.get_style(buffer)
  end

  def get_style_at(emulator, x, y) do
    buffer = ScreenManager.get_active_buffer(emulator)
    ScreenManager.get_style_at(buffer, x, y)
  end

  def get_style_at_cursor(emulator) do
    buffer = ScreenManager.get_active_buffer(emulator)
    ScreenManager.get_style_at_cursor(buffer)
  end
end
