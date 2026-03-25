defmodule Raxol.Terminal.ScreenBuffer.EraseOps do
  @moduledoc false

  require Logger

  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.Buffer.CharEditor
  alias Raxol.Terminal.ScreenBuffer.{BehaviourImpl, EraseOperations}

  def clear(buffer, _style \\ nil) do
    new_cells = create_empty_grid(buffer.width, buffer.height)
    %{buffer | cells: new_cells}
  end

  def erase_from_cursor_to_end(buffer, x, y, top, bottom) do
    EraseOperations.erase_from_cursor_to_end(buffer, x, y, top, bottom)
  rescue
    e ->
      Logger.warning(
        "Failed to erase from cursor to end at (#{x},#{y}): #{Exception.message(e)}"
      )

      buffer
  end

  def erase_from_cursor_to_end(buffer) do
    EraseOperations.erase_from_cursor_to_end(buffer)
  rescue
    e ->
      Logger.warning(
        "Failed to erase from cursor to end: #{Exception.message(e)}"
      )

      buffer
  end

  def erase_from_start_to_cursor(buffer, x, y, top, bottom) do
    EraseOperations.erase_from_start_to_cursor(buffer, x, y, top, bottom)
  rescue
    e ->
      Logger.warning(
        "Failed to erase from start to cursor at (#{x},#{y}): #{Exception.message(e)}"
      )

      buffer
  end

  def erase_all(buffer) do
    EraseOperations.erase_all(buffer)
  rescue
    e ->
      Logger.warning(
        "Failed to erase all buffer content: #{Exception.message(e)}"
      )

      buffer
  end

  def clear_region(buffer, x, y, width, height) do
    EraseOperations.clear_region(buffer, x, y, width, height)
  rescue
    e ->
      Logger.warning(
        "Failed to clear region at (#{x},#{y}) size #{width}x#{height}: #{Exception.message(e)}"
      )

      buffer
  end

  def erase_display(buffer, mode, _cursor, _min_row, _max_row) do
    case mode do
      0 -> erase_from_cursor_to_end(buffer)
      1 -> BehaviourImpl.erase_from_start_to_cursor(buffer)
      2 -> clear(buffer)
      _ -> buffer
    end
  end

  def erase_screen(buffer) do
    EraseOperations.erase_all(buffer)
  end

  def erase_line(buffer, mode, cursor, _min_col, _max_col) do
    {cursor_x, cursor_y} = {elem(cursor, 0), elem(cursor, 1)}

    case mode do
      0 ->
        EraseOperations.erase_in_line(buffer, {cursor_x, cursor_y}, :to_end)

      1 ->
        EraseOperations.erase_in_line(
          buffer,
          {cursor_x, cursor_y},
          :to_beginning
        )

      2 ->
        EraseOperations.erase_in_line(buffer, {cursor_x, cursor_y}, :all)

      _ ->
        buffer
    end
  end

  def erase_in_line(buffer, position, type) do
    EraseOperations.erase_in_line(buffer, position, type)
  rescue
    e ->
      Logger.warning(
        "Failed to erase in line at #{inspect(position)} type #{type}: #{Exception.message(e)}"
      )

      buffer
  end

  def erase_in_display(buffer, position, type) do
    EraseOperations.erase_in_display(buffer, position, type)
  end

  def delete_chars(buffer, count, cursor, _max_col) do
    {cursor_x, cursor_y} = cursor

    CharEditor.delete_characters(
      buffer,
      cursor_y,
      cursor_x,
      count,
      buffer.default_style
    )
  end

  def insert_chars(buffer, _count, _cursor, _max_col) do
    buffer
  end

  def delete_characters(buffer, row, col, count, default_style) do
    CharEditor.delete_characters(buffer, row, col, count, default_style)
  end

  defp create_empty_grid(width, height) when width > 0 and height > 0 do
    for _y <- 0..(height - 1) do
      for _x <- 0..(width - 1) do
        Cell.new()
      end
    end
  end

  defp create_empty_grid(_width, _height), do: []
end
