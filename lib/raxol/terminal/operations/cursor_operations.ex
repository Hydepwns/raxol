defmodule Raxol.Terminal.Operations.CursorOperations do
  @moduledoc """
  Implements cursor-related operations for the terminal emulator.
  """

  alias Raxol.Terminal.Cursor.Manager, as: CursorManager

  def get_cursor_position(emulator) do
    CursorManager.get_emulator_position(emulator)
  end

  def set_cursor_position(emulator, x, y) do
    CursorManager.set_emulator_position(emulator, x, y)
  end

  def get_cursor_style(emulator) do
    CursorManager.get_emulator_style(emulator)
  end

  def set_cursor_style(emulator, style) do
    CursorManager.set_emulator_style(emulator, style)
  end

  def cursor_visible?(emulator) do
    CursorManager.emulator_visible?(emulator)
  end

  def set_cursor_visibility(emulator, visible) do
    CursorManager.set_emulator_visibility(emulator, visible)
  end

  def cursor_blinking?(emulator) do
    CursorManager.emulator_blinking?(emulator)
  end

  def set_cursor_blink(emulator, blinking) do
    CursorManager.set_emulator_blink(emulator, blinking)
  end

  def toggle_visibility(emulator) do
    current_visible = CursorManager.emulator_visible?(emulator)
    CursorManager.set_emulator_visibility(emulator, !current_visible)
  end

  def toggle_blink(emulator) do
    current_blinking = CursorManager.emulator_blinking?(emulator)
    CursorManager.set_emulator_blink(emulator, !current_blinking)
  end

  def set_blink_rate(emulator, rate) do
    # For now, just set the blink state based on rate
    blinking = rate > 0
    CursorManager.set_emulator_blink(emulator, blinking)
  end

  def update_blink(emulator) do
    if CursorManager.emulator_blinking?(emulator) do
      # Toggle the blink state for blinking cursors
      current_visible = CursorManager.emulator_visible?(emulator)
      CursorManager.set_emulator_visibility(emulator, !current_visible)
    else
      # For non-blinking cursors, ensure they're visible
      CursorManager.set_emulator_visibility(emulator, true)
    end
  end

  # Function aliases expected by tests
  def is_cursor_visible?(emulator) do
    cursor_visible?(emulator)
  end

  def is_cursor_blinking?(emulator) do
    cursor_blinking?(emulator)
  end
end
