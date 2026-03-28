defmodule Raxol.Terminal.Emulator.CursorOps do
  @moduledoc false

  alias Raxol.Terminal.Operations.CursorOperations

  def get_cursor_position(emulator),
    do: CursorOperations.get_cursor_position(emulator)

  def set_cursor_position(emulator, x, y),
    do: CursorOperations.set_cursor_position(emulator, x, y)

  def get_cursor_style(emulator),
    do: CursorOperations.get_cursor_style(emulator)

  def set_cursor_style(emulator, style),
    do: CursorOperations.set_cursor_style(emulator, style)

  def cursor_visible?(emulator),
    do: CursorOperations.cursor_visible?(emulator)

  def get_cursor_visible(emulator),
    do: CursorOperations.cursor_visible?(emulator)

  def get_cursor_position_struct(emulator),
    do: Raxol.Terminal.Emulator.Helpers.get_cursor_position_struct(emulator)

  def get_mode_manager_cursor_visible(emulator),
    do: Raxol.Terminal.Emulator.Helpers.get_mode_manager_cursor_visible(emulator)

  def set_cursor_visibility(emulator, visible),
    do: CursorOperations.set_cursor_visibility(emulator, visible)

  def cursor_blinking?(emulator),
    do: CursorOperations.cursor_blinking?(emulator)

  def set_cursor_blink(emulator, blinking),
    do: CursorOperations.set_cursor_blink(emulator, blinking)

  def blinking?(emulator),
    do: CursorOperations.cursor_blinking?(emulator)

  def visible?(emulator),
    do: CursorOperations.cursor_visible?(emulator)
end
