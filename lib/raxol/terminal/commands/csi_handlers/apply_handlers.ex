defmodule Raxol.Terminal.Commands.CSIHandlers.ApplyHandlers do
  @moduledoc """
  Functions for applying specific CSI command handlers.
  """

  alias Raxol.Terminal.Commands.CSIHandlers.{
    CursorMovement,
    ScreenHandlers,
    DeviceHandlers,
    TextHandlers,
    CharsetHandlers
  }

  alias Raxol.Terminal.Commands.CSIHandlers

  def apply_handler(emulator, :cursor_up, amount),
    do: CursorMovement.handle_cursor_up(emulator, amount)

  def apply_handler(emulator, :cursor_down, amount),
    do: CursorMovement.handle_cursor_down(emulator, amount)

  def apply_handler(emulator, :cursor_forward, amount),
    do: CursorMovement.handle_cursor_forward(emulator, amount)

  def apply_handler(emulator, :cursor_backward, amount),
    do: CursorMovement.handle_cursor_backward(emulator, amount)

  def apply_handler(emulator, :cursor_position, params),
    do: CursorMovement.handle_cursor_position(emulator, params)

  def apply_handler(emulator, :cursor_column, column),
    do: CursorMovement.handle_cursor_column(emulator, column)

  def apply_handler(emulator, :screen_clear, params),
    do: ScreenHandlers.handle_screen_clear(emulator, params)

  def apply_handler(emulator, :line_clear, params),
    do: ScreenHandlers.handle_line_clear(emulator, params)

  def apply_handler(emulator, :text_attributes, params),
    do: TextHandlers.handle_text_attributes(emulator, params)

  def apply_handler(emulator, :save_cursor, params),
    do: TextHandlers.handle_save_cursor(emulator, params)

  def apply_handler(emulator, :restore_cursor, params),
    do: TextHandlers.handle_restore_cursor(emulator, params)

  def apply_handler(emulator, :save_restore_cursor, params),
    do: TextHandlers.handle_save_restore_cursor(emulator, params)

  def apply_handler(emulator, :r, params),
    do: ScreenHandlers.handle_r(emulator, params)

  def apply_handler(emulator, :scroll_up, lines),
    do: ScreenHandlers.handle_scroll_up(emulator, lines)

  def apply_handler(emulator, :scroll_down, lines),
    do: ScreenHandlers.handle_scroll_down(emulator, lines)

  def apply_handler(emulator, :device_status, params),
    do: DeviceHandlers.handle_device_status(emulator, params)

  def apply_handler(emulator, :device_status_report, _params),
    do: DeviceHandlers.handle_device_status_report(emulator)

  def apply_handler(emulator, :cursor_position_report, _params),
    do: DeviceHandlers.handle_cursor_position_report(emulator)

  def apply_handler(emulator, :locking_shift_g0, _params),
    do: CharsetHandlers.handle_locking_shift_g0(emulator)

  def apply_handler(emulator, :locking_shift_g1, _params),
    do: CharsetHandlers.handle_locking_shift_g1(emulator)

  def apply_handler(emulator, :single_shift_g2, _params),
    do: CharsetHandlers.handle_single_shift_g2(emulator)

  def apply_handler(emulator, :single_shift_g3, _params),
    do: CharsetHandlers.handle_single_shift_g3(emulator)

  # Bracketed paste handlers
  def apply_handler(emulator, :bracketed_paste_start, _params),
    do: CSIHandlers.handle_bracketed_paste_start(emulator)

  def apply_handler(emulator, :bracketed_paste_end, _params),
    do: CSIHandlers.handle_bracketed_paste_end(emulator)
end
