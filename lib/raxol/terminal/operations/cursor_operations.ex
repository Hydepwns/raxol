defmodule Raxol.Terminal.Operations.CursorOperations do
  @moduledoc """
  Implements cursor-related operations for the terminal emulator.
  """

  alias Raxol.Terminal.Cursor.Manager, as: CursorManager

  def get_cursor_position(emulator) do
    CursorManager.get_position(emulator.cursor)
  end

  def set_cursor_position(emulator, x, y) do
    %{emulator | cursor: CursorManager.set_position(emulator.cursor, x, y)}
  end

  def get_cursor_style(emulator) do
    CursorManager.get_style(emulator.cursor)
  end

  def set_cursor_style(emulator, style) do
    %{emulator | cursor: CursorManager.set_style(emulator.cursor, style)}
  end

  def cursor_visible?(emulator) do
    CursorManager.visible?(emulator.cursor)
  end

  def set_cursor_visibility(emulator, visible) do
    %{emulator | cursor: CursorManager.set_visibility(emulator.cursor, visible)}
  end

  def cursor_blinking?(emulator) do
    CursorManager.blinking?(emulator.cursor)
  end

  def set_cursor_blink(emulator, blinking) do
    %{emulator | cursor: CursorManager.set_blink(emulator.cursor, blinking)}
  end

  def toggle_visibility(emulator) do
    %{emulator | cursor: CursorManager.toggle_visibility(emulator.cursor)}
  end

  def toggle_blink(emulator) do
    %{emulator | cursor: CursorManager.toggle_blink(emulator.cursor)}
  end

  def set_blink_rate(emulator, rate) do
    %{emulator | cursor: CursorManager.set_blink_rate(emulator.cursor, rate)}
  end

  def update_blink(emulator) do
    %{emulator | cursor: CursorManager.update_blink(emulator.cursor)}
  end
end
