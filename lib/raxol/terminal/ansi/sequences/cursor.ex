defmodule Raxol.Terminal.ANSI.Sequences.Cursor do
  @moduledoc """
  ANSI Cursor Sequence Handler.

  Handles parsing and application of ANSI cursor control sequences,
  including movement, position saving/restoring, and visibility.
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.BufferManager

  @doc """
  Move cursor to absolute position.

  ## Parameters

  * `emulator` - The terminal emulator state
  * `row` - Row to move to (1-indexed)
  * `col` - Column to move to (1-indexed)

  ## Returns

  Updated emulator state
  """
  def move_cursor(emulator, row, col) do
    # Convert 1-indexed ANSI coordinates to 0-indexed internal coordinates
    row = max(0, row - 1)
    col = max(0, col - 1)

    # Ensure coordinates are within bounds
    active_buffer = BufferManager.get_active_buffer(emulator)
    height = ScreenBuffer.get_height(active_buffer)
    width = ScreenBuffer.get_width(active_buffer)

    row = min(row, height - 1)
    col = min(col, width - 1)

    # Update cursor position (correctly update nested cursor struct)
    %{emulator | cursor: %{emulator.cursor | position: {row, col}}}
  end

  @doc """
  Move cursor up by specified number of rows.

  ## Parameters

  * `emulator` - The terminal emulator state
  * `n` - Number of rows to move up

  ## Returns

  Updated emulator state
  """
  def move_cursor_up(emulator, n) do
    n = if n <= 0, do: 1, else: n
    {cur_x, cur_y} = emulator.cursor.position
    new_y = max(0, cur_y - n)
    %{emulator | cursor: %{emulator.cursor | position: {cur_x, new_y}}}
  end

  @doc """
  Move cursor down by specified number of rows.

  ## Parameters

  * `emulator` - The terminal emulator state
  * `n` - Number of rows to move down

  ## Returns

  Updated emulator state
  """
  def move_cursor_down(emulator, n) do
    n = if n <= 0, do: 1, else: n
    active_buffer = BufferManager.get_active_buffer(emulator)
    height = ScreenBuffer.get_height(active_buffer)
    {cur_x, cur_y} = emulator.cursor.position
    new_y = min(cur_y + n, height - 1)
    %{emulator | cursor: %{emulator.cursor | position: {cur_x, new_y}}}
  end

  @doc """
  Move cursor forward by specified number of columns.

  ## Parameters

  * `emulator` - The terminal emulator state
  * `n` - Number of columns to move forward

  ## Returns

  Updated emulator state
  """
  def move_cursor_forward(emulator, n) do
    n = if n <= 0, do: 1, else: n
    active_buffer = BufferManager.get_active_buffer(emulator)
    width = ScreenBuffer.get_width(active_buffer)
    {cur_x, cur_y} = emulator.cursor.position
    new_x = min(cur_x + n, width - 1)
    %{emulator | cursor: %{emulator.cursor | position: {new_x, cur_y}}}
  end

  @doc """
  Move cursor backward by specified number of columns.

  ## Parameters

  * `emulator` - The terminal emulator state
  * `n` - Number of columns to move backward

  ## Returns

  Updated emulator state
  """
  def move_cursor_backward(emulator, n) do
    n = if n <= 0, do: 1, else: n
    {cur_x, cur_y} = emulator.cursor.position
    new_x = max(0, cur_x - n)
    %{emulator | cursor: %{emulator.cursor | position: {new_x, cur_y}}}
  end

  @doc """
  Save current cursor position.

  ## Parameters

  * `emulator` - The terminal emulator state

  ## Returns

  Updated emulator state with saved cursor position
  """
  def save_cursor_position(emulator) do
    %{
      emulator
      | cursor: %{emulator.cursor | saved_position: emulator.cursor.position}
    }
  end

  @doc """
  Restore previously saved cursor position.

  ## Parameters

  * `emulator` - The terminal emulator state

  ## Returns

  Updated emulator state with restored cursor position
  """
  def restore_cursor_position(emulator) do
    case emulator.cursor.saved_position do
      {x, y} -> %{emulator | cursor: %{emulator.cursor | position: {x, y}}}
      _ -> emulator
    end
  end

  @doc """
  Set cursor visibility.

  ## Parameters

  * `emulator` - The terminal emulator state
  * `visible` - Boolean indicating visibility

  ## Returns

  Updated emulator state
  """
  def set_cursor_visibility(emulator, visible) do
    %{emulator | cursor_visible: visible}
  end
end
