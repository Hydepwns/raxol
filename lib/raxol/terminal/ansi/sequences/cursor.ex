defmodule Raxol.Terminal.ANSI.Sequences.Cursor do
  @moduledoc """
  ANSI Cursor Sequence Handler.

  Handles parsing and application of ANSI cursor control sequences,
  including movement, position saving/restoring, and visibility.
  """

  alias Raxol.Terminal.ScreenBuffer

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
    height = ScreenBuffer.get_height(emulator.active_buffer)
    width = ScreenBuffer.get_width(emulator.active_buffer)

    row = min(row, height - 1)
    col = min(col, width - 1)

    # Update cursor position
    %{emulator | cursor_x: col, cursor_y: row}
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
    new_y = max(0, emulator.cursor_y - n)
    %{emulator | cursor_y: new_y}
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
    height = ScreenBuffer.get_height(emulator.active_buffer)
    new_y = min(emulator.cursor_y + n, height - 1)
    %{emulator | cursor_y: new_y}
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
    width = ScreenBuffer.get_width(emulator.active_buffer)
    new_x = min(emulator.cursor_x + n, width - 1)
    %{emulator | cursor_x: new_x}
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
    new_x = max(0, emulator.cursor_x - n)
    %{emulator | cursor_x: new_x}
  end

  @doc """
  Save current cursor position.

  ## Parameters

  * `emulator` - The terminal emulator state

  ## Returns

  Updated emulator state with saved cursor position
  """
  def save_cursor_position(emulator) do
    %{emulator | cursor_saved: {emulator.cursor_x, emulator.cursor_y}}
  end

  @doc """
  Restore previously saved cursor position.

  ## Parameters

  * `emulator` - The terminal emulator state

  ## Returns

  Updated emulator state with restored cursor position
  """
  def restore_cursor_position(emulator) do
    case emulator.cursor_saved do
      {x, y} -> %{emulator | cursor_x: x, cursor_y: y}
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
