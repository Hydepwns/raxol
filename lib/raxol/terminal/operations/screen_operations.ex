defmodule Raxol.Terminal.Operations.ScreenOperations do
  @moduledoc """
  Implements screen-related operations for the terminal emulator.
  """

  alias Raxol.Terminal.ScreenManager
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cursor.Manager, as: CursorManager
  alias Raxol.Terminal.Buffer.Eraser
  alias Raxol.Terminal.Buffer.LineOperations

  def clear_screen(emulator) do
    buffer = ScreenManager.get_active_buffer(emulator)
    new_buffer = ScreenBuffer.clear(buffer)
    ScreenManager.update_active_buffer(emulator, new_buffer)
  end

  def clear_line(emulator) do
    buffer = ScreenManager.get_active_buffer(emulator)
    {_, y} = ScreenBuffer.get_cursor_position(buffer) || {0, 0}
    new_buffer = ScreenBuffer.clear_line(buffer, y)
    ScreenManager.update_active_buffer(emulator, new_buffer)
  end

  def clear_line(emulator, line) do
    buffer = ScreenManager.get_active_buffer(emulator)
    new_buffer = ScreenBuffer.clear_line(buffer, line)
    ScreenManager.update_active_buffer(emulator, new_buffer)
  end

  def erase_line(emulator) do
    buffer = ScreenManager.get_active_buffer(emulator)
    {_, y} = ScreenBuffer.get_cursor_position(buffer) || {0, 0}
    new_buffer = ScreenBuffer.erase_line(buffer, y)
    ScreenManager.update_active_buffer(emulator, new_buffer)
  end

  def erase_line(emulator, mode) do
    buffer = ScreenManager.get_active_buffer(emulator)
    {_, y} = ScreenBuffer.get_cursor_position(buffer) || {0, 0}
    new_buffer = ScreenBuffer.erase_line(buffer, y, mode)
    ScreenManager.update_active_buffer(emulator, new_buffer)
  end

  def erase_in_line(emulator, _opts) do
    buffer = ScreenManager.get_active_buffer(emulator)
    {x, y} = CursorManager.get_position(emulator.cursor)
    updated_buffer = ScreenBuffer.set_cursor_position(buffer, x, y)
    # Erase from cursor to end of line
    new_buffer = Eraser.erase_in_line(updated_buffer, {x, y}, :to_end)
    ScreenManager.update_active_buffer(emulator, new_buffer)
  end

  def erase_from_cursor_to_end(emulator) do
    buffer = ScreenManager.get_active_buffer(emulator)
    new_buffer = Eraser.erase_from_cursor_to_end(buffer)
    ScreenManager.update_active_buffer(emulator, new_buffer)
  end

  def erase_from_start_to_cursor(emulator) do
    buffer = ScreenManager.get_active_buffer(emulator)
    new_buffer = ScreenBuffer.erase_from_start_to_cursor(buffer)
    ScreenManager.update_active_buffer(emulator, new_buffer)
  end

  def erase_chars(emulator, count) do
    buffer = ScreenManager.get_active_buffer(emulator)
    new_buffer = Eraser.erase_chars(buffer, count)
    ScreenManager.update_active_buffer(emulator, new_buffer)
  end

  def delete_chars(emulator, count) do
    buffer = ScreenManager.get_active_buffer(emulator)
    new_buffer = LineOperations.delete_chars(buffer, count)
    ScreenManager.update_active_buffer(emulator, new_buffer)
  end

  def insert_chars(emulator, count) do
    buffer = ScreenManager.get_active_buffer(emulator)
    new_buffer = LineOperations.insert_chars(buffer, count)
    ScreenManager.update_active_buffer(emulator, new_buffer)
  end

  def delete_lines(emulator, count) do
    buffer = ScreenManager.get_active_buffer(emulator)
    new_buffer = LineOperations.delete_lines(buffer, count)
    ScreenManager.update_active_buffer(emulator, new_buffer)
  end

  def insert_lines(emulator, count) do
    buffer = ScreenManager.get_active_buffer(emulator)
    new_buffer = LineOperations.insert_lines(buffer, count)
    ScreenManager.update_active_buffer(emulator, new_buffer)
  end

  def prepend_lines(emulator, count) do
    buffer = ScreenManager.get_active_buffer(emulator)
    new_buffer = LineOperations.prepend_lines(buffer, count)
    ScreenManager.update_active_buffer(emulator, new_buffer)
  end

  def write_string(emulator, x, y, string, style) do
    buffer = ScreenManager.get_active_buffer(emulator)
    new_buffer = ScreenManager.write_string(buffer, x, y, string, style)
    ScreenManager.update_active_buffer(emulator, new_buffer)
  end

  def get_content(emulator) do
    buffer = ScreenManager.get_active_buffer(emulator)
    ScreenBuffer.get_content(buffer)
  end

  def get_line(emulator, line) do
    buffer = ScreenManager.get_active_buffer(emulator)
    cells = ScreenBuffer.get_line(buffer, line)
    Enum.map_join(cells, "", fn cell -> cell.char end)
  end

  def set_cursor_position(emulator, x, y) do
    buffer = ScreenManager.get_active_buffer(emulator)
    new_buffer = ScreenBuffer.set_cursor_position(buffer, x, y)

    new_cursor =
      case emulator.cursor do
        pid when is_pid(pid) ->
          Raxol.Terminal.Cursor.Manager.set_position(pid, {x, y})
          pid

        map when is_map(map) ->
          %{map | position: {x, y}}

        other ->
          other
      end

    new_emulator = %{emulator | cursor: new_cursor}
    ScreenManager.update_active_buffer(new_emulator, new_buffer)
  end

  def get_cursor_position(emulator) do
    Raxol.Terminal.Emulator.get_cursor_position(emulator)
  end

  # Remove unused function completely
  # defp mode_to_type(_), do: :to_end

  # Functions expected by tests
  @doc """
  Erases the entire display (1-arity version).
  """
  @spec erase_display(Emulator.t()) :: Emulator.t()
  def erase_display(emulator) do
    erase_display(emulator, 0)
  end

  @doc """
  Erases the display based on the specified mode.
  """
  @spec erase_display(Emulator.t(), integer()) :: Emulator.t()
  def erase_display(emulator, mode) do
    buffer = ScreenManager.get_active_buffer(emulator)
    new_buffer = ScreenBuffer.erase_display(buffer, mode)
    ScreenManager.update_active_buffer(emulator, new_buffer)
  end

  @doc """
  Erases from cursor to end of line (1-arity version).
  """
  @spec erase_in_line(Emulator.t()) :: Emulator.t()
  def erase_in_line(emulator) do
    erase_in_line(emulator, %{})
  end

  @doc """
  Erases the display based on the specified mode.
  """
  @spec erase_in_display(Emulator.t(), atom()) :: Emulator.t()
  def erase_in_display(emulator, mode) do
    buffer = ScreenManager.get_active_buffer(emulator)
    {x, y} = Raxol.Terminal.Emulator.get_cursor_position(emulator)

    # Update the buffer's cursor position before erasing
    buffer_with_cursor = ScreenBuffer.set_cursor_position(buffer, x, y)
    new_buffer = Eraser.erase_in_display(buffer_with_cursor, mode)
    ScreenManager.update_active_buffer(emulator, new_buffer)
  end

  @doc """
  Erases from cursor to end of display (1-arity version).
  """
  @spec erase_in_display(Emulator.t()) :: Emulator.t()
  def erase_in_display(emulator) do
    erase_in_display(emulator, 0)
  end
end
