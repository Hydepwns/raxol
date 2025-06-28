defmodule Raxol.Terminal.Commands.Screen do
  @moduledoc """
  Handles screen manipulation commands in the terminal.

  This module provides functions for clearing the screen or parts of it,
  inserting and deleting lines, and other screen manipulation operations.
  """

  import Raxol.Guards
  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Buffer.Eraser
  alias Raxol.Terminal.Buffer.Operations

  require Raxol.Core.Runtime.Log

  @spec clear_screen(Emulator.t(), integer()) :: Emulator.t()
  def clear_screen(emulator, mode) do
    buffer = Emulator.get_active_buffer(emulator)
    {x, y} = Emulator.get_cursor_position(emulator)
    {top, bottom} = ScreenBuffer.get_scroll_region(buffer)

    new_buffer =
      case mode do
        0 -> ScreenBuffer.erase_from_cursor_to_end(buffer, x, y, top, bottom)
        1 -> ScreenBuffer.erase_from_start_to_cursor(buffer, x, y, top, bottom)
        2 -> ScreenBuffer.clear(buffer)
        3 -> ScreenBuffer.erase_all(buffer)
        _ -> buffer
      end

    Emulator.update_active_buffer(emulator, new_buffer)
  end

  @spec clear_line(Emulator.t(), integer()) :: Emulator.t()
  def clear_line(emulator, mode) do
    buffer = Emulator.get_active_buffer(emulator)

    {cursor_x, cursor_y} =
      Raxol.Terminal.Cursor.Manager.get_position(emulator.cursor)

    Raxol.Core.Runtime.Log.debug(
      "[Screen.clear_line] CALLED with mode: #{mode}, cursor_x: #{cursor_x}, cursor_y from emulator: #{cursor_y}"
    )

    default_style = emulator.style

    new_buffer =
      case mode do
        # Clear from cursor to end of line
        0 ->
          Eraser.clear_line_from(buffer, cursor_y, cursor_x, default_style)

        # Clear from beginning of line to cursor
        1 ->
          Eraser.clear_line_to(buffer, cursor_y, cursor_x, default_style)

        # Clear entire line
        2 ->
          Eraser.clear_line(buffer, cursor_y, default_style)

        # Unknown mode, do nothing
        _ ->
          Raxol.Core.Runtime.Log.warning_with_context(
            "Unknown clear line mode: #{mode}",
            %{}
          )

          buffer
      end

    Emulator.update_active_buffer(emulator, new_buffer)
  end

  @spec insert_lines(Emulator.t(), integer()) :: Emulator.t()
  def insert_lines(emulator, count) do
    {_, cursor_y} = Raxol.Terminal.Cursor.Manager.get_position(emulator.cursor)
    buffer = Emulator.get_active_buffer(emulator)

    # Apply scroll region constraints if active
    {top, bottom} =
      case emulator.scroll_region do
        nil -> {0, ScreenBuffer.get_height(buffer) - 1}
        region -> region
      end

    # Only insert if cursor is within the scroll region
    if cursor_y >= top && cursor_y <= bottom do
      # Insert count lines at cursor_y
      new_buffer =
        ScreenBuffer.insert_lines(buffer, cursor_y, count, emulator.style)

      Emulator.update_active_buffer(emulator, new_buffer)
    else
      # Outside scroll region, do nothing
      emulator
    end
  end

  @spec delete_lines(Emulator.t(), integer()) :: Emulator.t()
  def delete_lines(emulator, count) do
    {_, cursor_y} = Raxol.Terminal.Cursor.Manager.get_position(emulator.cursor)
    buffer = Emulator.get_active_buffer(emulator)

    # Apply scroll region constraints if active
    {top, bottom} =
      case emulator.scroll_region do
        nil -> {0, ScreenBuffer.get_height(buffer) - 1}
        region -> region
      end

    # Only delete if cursor is within the scroll region
    if cursor_y >= top && cursor_y <= bottom do
      # Delete count lines at cursor_y, passing the scroll region
      new_buffer =
        ScreenBuffer.delete_lines(
          buffer,
          cursor_y,
          count,
          emulator.style,
          {top, bottom}
        )

      Emulator.update_active_buffer(emulator, new_buffer)
    else
      # Outside scroll region, do nothing
      emulator
    end
  end

  @spec scroll_up_screen_command(Emulator.t(), non_neg_integer()) ::
          Emulator.t()
  def scroll_up_screen_command(emulator, count)
      when integer?(count) and count > 0 do
    Raxol.Core.Runtime.Log.debug(
      "[Screen.scroll_up_screen_command] CALLED with count: #{count}"
    )

    scrollback = emulator.scrollback_buffer || []
    buffer = emulator.main_screen_buffer
    {to_restore, remaining_scrollback} = Enum.split(scrollback, count)

    # Move lines from scrollback to the top of the screen buffer
    new_buffer = ScreenBuffer.prepend_lines(buffer, Enum.reverse(to_restore))

    %{
      emulator
      | scrollback_buffer: remaining_scrollback,
        main_screen_buffer: new_buffer
    }
  end

  @spec scroll_down(Emulator.t(), non_neg_integer()) :: Emulator.t()
  def scroll_down(emulator, count) when integer?(count) and count > 0 do
    Raxol.Core.Runtime.Log.debug(
      "[Screen.scroll_down] CALLED with count: #{count}"
    )

    buffer = Emulator.get_active_buffer(emulator)
    {top, bottom} = ScreenBuffer.get_scroll_region(buffer)

    # Use ScreenBuffer.scroll_down since we have a ScreenBuffer struct
    new_buffer = ScreenBuffer.scroll_down(buffer, top, bottom, count)
    Emulator.update_active_buffer(emulator, new_buffer)
  end

  @spec scroll_up(Emulator.t(), non_neg_integer()) :: Emulator.t()
  def scroll_up(emulator, lines) when integer?(lines) and lines > 0 do
    Raxol.Core.Runtime.Log.debug(
      "[Screen.scroll_up] CALLED with lines: #{lines}"
    )

    buffer = Emulator.get_active_buffer(emulator)
    {top, bottom} = ScreenBuffer.get_scroll_region(buffer)

    # Use ScreenBuffer.scroll_up since we have a ScreenBuffer struct
    new_buffer = ScreenBuffer.scroll_up(buffer, top, bottom, lines)
    Emulator.update_active_buffer(emulator, new_buffer)
  end
end
