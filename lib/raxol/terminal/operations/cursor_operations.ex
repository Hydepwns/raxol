defmodule Raxol.Terminal.Operations.CursorOperations do
  @moduledoc """
  Implements cursor-related operations for the terminal emulator.
  """

  alias Raxol.Terminal.Cursor.Manager, as: CursorManager

  def get_cursor_position(emulator) do
    # Returns {row, col} format for ANSI consistency
    CursorManager.get_position(emulator.cursor)
  end

  def set_cursor_position(emulator, col, row) do
    # Get emulator dimensions for bounds checking
    width = Raxol.Terminal.Emulator.get_width(emulator)
    height = Raxol.Terminal.Emulator.get_height(emulator)

    # Clamp position to screen bounds
    clamped_row = max(0, min(row, height - 1))
    clamped_col = max(0, min(col, width - 1))

    # CursorManager.set_position expects {row, col} tuple
    CursorManager.set_position(emulator.cursor, {clamped_row, clamped_col})
    emulator
  end

  def get_cursor_style(emulator) do
    CursorManager.get_style(emulator.cursor)
  end

  def set_cursor_style(emulator, style) do
    # Validate the style - only allow valid cursor styles
    valid_styles = [:block, :underline, :bar]

    if style in valid_styles do
      CursorManager.set_style(emulator.cursor, style)
    end

    # If style is invalid, do nothing (maintain current style)

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

  def move_cursor(emulator, col, row) do
    set_cursor_position(emulator, col, row)
  end
end
