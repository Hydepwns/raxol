defmodule Raxol.Terminal.Commands.Screen do
  @moduledoc """
  Handles screen manipulation commands in the terminal.

  This module provides functions for clearing the screen or parts of it,
  inserting and deleting lines, and other screen manipulation operations.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Buffer.Eraser

  require Raxol.Core.Runtime.Log

  @doc """
  Clears the screen or a part of it based on the mode parameter.

  ## Parameters

  * `emulator` - The current emulator state
  * `mode` - The clear mode:
    * 0 - Clear from cursor to end of screen
    * 1 - Clear from beginning of screen to cursor
    * 2 - Clear entire screen but don't move cursor
    * 3 - Clear entire screen including scrollback

  ## Returns

  * Updated emulator state
  """
  @spec clear_screen(Emulator.t(), integer()) :: Emulator.t()
  def clear_screen(emulator, mode) do
    buffer = Emulator.get_active_buffer(emulator)

    {cursor_x, cursor_y} =
      Raxol.Terminal.Cursor.Manager.get_position(emulator.cursor)

    default_style = emulator.style

    Raxol.Core.Runtime.Log.debug(
      "[Screen.clear_screen] default_style for mode: #{mode}"
    )

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

      # Clear entire screen including scrollback
      3 ->
        new_buffer = Eraser.clear_screen(buffer, default_style)
        # Clear scrollback as well
        Emulator.clear_scrollback(emulator)
        Emulator.update_active_buffer(emulator, new_buffer)

      # Unknown mode, do nothing
      _ ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "Unknown clear screen mode: #{mode}",
          %{}
        )

        emulator
    end
  end

  @doc """
  Clears a line or part of a line based on the mode parameter.

  ## Parameters

  * `emulator` - The current emulator state
  * `mode` - The clear mode:
    * 0 - Clear from cursor to end of line
    * 1 - Clear from beginning of line to cursor
    * 2 - Clear entire line

  ## Returns

  * Updated emulator state
  """
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

  @doc """
  Inserts blank lines at the current cursor position.

  ## Parameters

  * `emulator` - The current emulator state
  * `count` - The number of lines to insert

  ## Returns

  * Updated emulator state
  """
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

  @doc """
  Deletes lines at the current cursor position.

  ## Parameters

  * `emulator` - The current emulator state
  * `count` - The number of lines to delete

  ## Returns

  * Updated emulator state
  """
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

  @doc """
  Scrolls up by moving lines from the scrollback buffer into the screen buffer.
  """
  def scroll_up_screen_command(emulator, count) when is_integer(count) and count > 0 do
    scrollback = emulator.scrollback_buffer || []
    buffer = emulator.main_screen_buffer
    {to_restore, remaining_scrollback} = Enum.split(scrollback, count)
    # Move lines from scrollback to the top of the screen buffer
    new_buffer =
      Raxol.Terminal.ScreenBuffer.prepend_lines(
        buffer,
        Enum.reverse(to_restore)
      )

    %{
      emulator
      | scrollback_buffer: remaining_scrollback,
        main_screen_buffer: new_buffer
    }
  end

  @doc """
  Scrolls down by moving lines from the screen buffer into the scrollback buffer.
  """
  def scroll_down(emulator, count) when is_integer(count) and count > 0 do
    buffer = emulator.main_screen_buffer

    {to_scrollback, new_buffer} =
      Raxol.Terminal.ScreenBuffer.pop_top_lines(buffer, count)

    new_scrollback = (emulator.scrollback_buffer || []) ++ to_scrollback

    %{
      emulator
      | scrollback_buffer: new_scrollback,
        main_screen_buffer: new_buffer
    }
  end

  @doc """
  Scrolls the screen up by the specified number of lines.
  """
  @spec scroll_up(Emulator.t(), non_neg_integer()) :: Emulator.t()
  def scroll_up(emulator, lines) do
    buffer = Emulator.get_active_buffer(emulator)
    {new_buffer, _} = Raxol.Terminal.ScreenBuffer.scroll_up(buffer, lines)
    Emulator.update_active_buffer(emulator, new_buffer)
  end
end
