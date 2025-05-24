defmodule Raxol.Terminal.Commands.Screen do
  @moduledoc """
  Handles screen manipulation commands in the terminal.

  This module provides functions for clearing the screen or parts of it,
  inserting and deleting lines, and other screen manipulation operations.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Buffer.Eraser

  require Logger

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
    {cursor_x, cursor_y} = Raxol.Terminal.Emulator.get_cursor_position(emulator)
    default_style = emulator.style

    Logger.debug("[Screen.clear_screen] default_style for mode: #{mode}")

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
        Logger.warn("Unknown clear screen mode: #{mode}")
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
    {cursor_x, cursor_y} = Raxol.Terminal.Emulator.get_cursor_position(emulator)

    Logger.debug(
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
          Logger.warn("Unknown clear line mode: #{mode}")
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
    {_, cursor_y} = Raxol.Terminal.Emulator.get_cursor_position(emulator)
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
    {_, cursor_y} = Raxol.Terminal.Emulator.get_cursor_position(emulator)
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
  Scrolls the screen up.

  ## Parameters

  * `emulator` - The current emulator state
  * `count` - The number of lines to scroll

  ## Returns

  * Updated emulator state
  """
  @spec scroll_up(Emulator.t(), integer()) :: Emulator.t()
  def scroll_up(emulator, count) do
    active_buffer = Emulator.get_active_buffer(emulator)

    # ScreenBuffer.scroll_up returns {updated_buffer_with_scrolled_cells, scrolled_off_lines}
    {buffer_after_scroll, scrolled_off_lines} =
      ScreenBuffer.scroll_up(active_buffer, count, emulator.scroll_region)

    # Combine scrolled_off_lines with existing scrollback and trim
    # scrolled_off_lines are the lines that just moved from viewport to scrollback (newest scrollback entries)
    # Prepend them to the existing scrollback list.
    current_scrollback = buffer_after_scroll.scrollback || []
    limit = buffer_after_scroll.scrollback_limit

    combined_scrollback = scrolled_off_lines ++ current_scrollback
    trimmed_scrollback = Enum.take(combined_scrollback, limit)

    final_buffer = %{buffer_after_scroll | scrollback: trimmed_scrollback}

    Emulator.update_active_buffer(emulator, final_buffer)
  end

  @doc """
  Scrolls the screen down.

  If there are lines in the emulator's scrollback_buffer, restores up to `count` lines from scrollback into the visible buffer. Otherwise, inserts blank lines as before.

  ## Parameters

  * `emulator` - The current emulator state
  * `count` - The number of lines to scroll

  ## Returns

  * Updated emulator state
  """
  @spec scroll_down(Emulator.t(), integer()) :: Emulator.t()
  def scroll_down(emulator, count) do
    buffer = Emulator.get_active_buffer(emulator)
    scrollback = emulator.scrollback_buffer || []

    {restore_lines, new_scrollback} =
      if count > 0 and length(scrollback) > 0 do
        # Take up to count lines from the end of scrollback_buffer
        n = min(count, length(scrollback))
        {Enum.take(scrollback, n), Enum.drop(scrollback, n)}
      else
        {[], scrollback}
      end

    # If we have lines to restore, use them; otherwise, insert blank lines
    new_buffer =
      if restore_lines != [] do
        # Prepend restored lines to the visible buffer using ScreenBuffer.scroll_down
        ScreenBuffer.scroll_down(buffer, restore_lines, length(restore_lines))
      else
        # Fallback: insert blank lines as before
        ScreenBuffer.scroll_down(buffer, count)
      end

    # Update emulator state with new buffer and trimmed scrollback
    %{
      Emulator.update_active_buffer(emulator, new_buffer)
      | scrollback_buffer: new_scrollback
    }
  end
end
