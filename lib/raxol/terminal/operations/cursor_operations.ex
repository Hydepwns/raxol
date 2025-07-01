defmodule Raxol.Terminal.Operations.CursorOperations do
  @moduledoc """
  Implements cursor-related operations for the terminal emulator.
  """

  alias Raxol.Terminal.Cursor.Manager, as: CursorManager

  def get_cursor_position(emulator) do
    CursorManager.get_position(emulator.cursor)
  end

  def set_cursor_position(emulator, x, y) do
    CursorManager.set_position(emulator.cursor, {x, y})
    emulator
  end

  def get_cursor_style(emulator) do
    CursorManager.get_style(emulator.cursor)
  end

  def set_cursor_style(emulator, style) do
    CursorManager.set_style(emulator.cursor, style)
    emulator
  end

  def cursor_visible?(emulator) do
    CursorManager.get_visibility(emulator.cursor)
  end

  def set_cursor_visibility(emulator, visible) do
    CursorManager.set_visibility(emulator.cursor, visible)
    emulator
  end

  def cursor_blinking?(emulator) do
    CursorManager.get_blink(emulator.cursor)
  end

  def set_cursor_blink(emulator, blinking) do
    CursorManager.set_blink(emulator.cursor, blinking)
    emulator
  end

  def toggle_visibility(emulator) do
    current_visible = CursorManager.get_visibility(emulator.cursor)
    CursorManager.set_visibility(emulator.cursor, !current_visible)
    emulator
  end

  def toggle_blink(emulator) do
    current_blinking = CursorManager.get_blink(emulator.cursor)
    CursorManager.set_blink(emulator.cursor, !current_blinking)
    emulator
  end

  def set_blink_rate(emulator, rate) do
    # For now, just set the blink state based on rate
    blinking = rate > 0
    CursorManager.set_blink(emulator.cursor, blinking)
    emulator
  end

  def update_blink(emulator) do
    if CursorManager.get_blink(emulator.cursor) do
      # Toggle the blink state for blinking cursors
      current_visible = CursorManager.get_visibility(emulator.cursor)
      CursorManager.set_visibility(emulator.cursor, !current_visible)
    else
      # For non-blinking cursors, ensure they're visible
      CursorManager.set_visibility(emulator.cursor, true)
    end

    emulator
  end

  # Function aliases expected by tests
  def visible?(emulator) do
    cursor_visible?(emulator)
  end

  def blinking?(emulator) do
    cursor_blinking?(emulator)
  end
end
