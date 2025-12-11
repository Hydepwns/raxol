defmodule Raxol.Terminal.Commands.Editor do
  @moduledoc """
  Handles editor-related terminal commands.
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Buffer.{LineEditor, CharEditor, Eraser}
  alias Raxol.Terminal.ANSI.TextFormatting
  alias Raxol.Terminal.Emulator

  @spec insert_lines(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          TextFormatting.text_style()
        ) :: ScreenBuffer.t()
  def insert_lines(buffer, row, count, default_style) do
    LineEditor.insert_lines(buffer, row, count, default_style)
  end

  @spec delete_lines(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          TextFormatting.text_style()
        ) :: ScreenBuffer.t()
  def delete_lines(buffer, row, count, default_style) do
    LineEditor.delete_lines(buffer, row, count, default_style)
  end

  @spec insert_chars(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          TextFormatting.text_style()
        ) :: ScreenBuffer.t()
  def insert_chars(buffer, row, col, count, default_style) do
    CharEditor.insert_characters(buffer, row, col, count, default_style)
  end

  @spec delete_chars(
          ScreenBuffer.t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          TextFormatting.text_style()
        ) :: ScreenBuffer.t()
  def delete_chars(buffer, row, col, count, default_style) do
    CharEditor.delete_characters(buffer, row, col, count, default_style)
  end

  @spec erase_chars(
          map(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          any()
        ) ::
          map()
  def erase_chars(buffer, row, col, count, default_style) do
    # Erase 'count' characters starting at {col, row} by replacing them with spaces.
    # Ensure coordinates and count are within bounds.
    _end_col = col + count - 1

    # Use Eraser.clear_region to replace the specified character cells with blanks.
    # Note: Eraser.clear_region handles clamping of coordinates internally.
    Eraser.clear_region(buffer, col, row, count, 1, default_style)
  end

  @spec clear_screen(
          Emulator.t(),
          integer(),
          {non_neg_integer(), non_neg_integer()},
          map()
        ) :: Emulator.t()
  def clear_screen(emulator, mode, cursor_pos, default_style) do
    buffer = Emulator.get_screen_buffer(emulator)
    {cursor_x, cursor_y} = cursor_pos

    case mode do
      # Clear from cursor to end of screen
      0 ->
        new_buffer =
          Eraser.clear_screen_from(buffer, cursor_y, cursor_x, default_style)

        Emulator.update_active_buffer(emulator, new_buffer)

      # Clear from beginning of screen to cursor
      1 ->
        new_buffer =
          Eraser.clear_screen_to(buffer, cursor_y, cursor_x, default_style)

        Emulator.update_active_buffer(emulator, new_buffer)

      # Clear entire screen
      2 ->
        new_buffer = Eraser.clear_screen(buffer, default_style)
        Emulator.update_active_buffer(emulator, new_buffer)

      # Clear entire screen and scrollback
      3 ->
        new_buffer = Eraser.clear_screen(buffer, default_style)
        # Clear scrollback as well
        emulator = Emulator.clear_scrollback(emulator)
        Emulator.update_active_buffer(emulator, new_buffer)

      # Unknown mode, do nothing
      _ ->
        emulator
    end
  end

  @spec clear_line(
          map(),
          integer(),
          {non_neg_integer(), non_neg_integer()},
          any()
        ) :: map()
  def clear_line(emulator, mode, cursor_pos, default_style) do
    buffer = Emulator.get_screen_buffer(emulator)
    {cursor_x, cursor_y} = cursor_pos

    new_buffer =
      case mode do
        # Clear from cursor to end of line
        0 -> Eraser.clear_line_from(buffer, cursor_y, cursor_x, default_style)
        # Clear from beginning of line to cursor
        1 -> Eraser.clear_line_to(buffer, cursor_y, cursor_x, default_style)
        # Clear entire line
        2 -> Eraser.clear_line(buffer, cursor_y, default_style)
        # Unknown mode, do nothing
        _ -> buffer
      end

    Emulator.update_active_buffer(emulator, new_buffer)
  end
end
