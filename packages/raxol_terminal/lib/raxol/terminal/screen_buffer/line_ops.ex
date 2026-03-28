defmodule Raxol.Terminal.ScreenBuffer.LineOps do
  @moduledoc false

  alias Raxol.Terminal.ScreenBuffer.Operations

  def insert_lines(buffer, y, count, style) do
    Operations.insert_lines(buffer, y, count, style)
  end

  def insert_lines(buffer, y, count, style, {top, bottom}) do
    Operations.insert_lines(buffer, y, count, style, {top, bottom})
  end

  def insert_lines_in_region(buffer, lines, y, top, bottom) do
    Operations.insert_lines(buffer, lines, y, top, bottom)
  end

  def delete_lines(buffer, y, count, style, {top, bottom}) do
    Operations.delete_lines(buffer, y, count, style, {top, bottom})
  end

  def delete_lines_in_region(buffer, lines, y, top, bottom) do
    Operations.delete_lines(buffer, lines, y, top, bottom)
  end

  def pop_bottom_lines(buffer, count) do
    cells = buffer.cells || []
    cells_count = length(cells)
    lines_to_remove = min(count, cells_count)

    {removed_lines, remaining_cells} = Enum.split(cells, -lines_to_remove)
    new_buffer = %{buffer | cells: remaining_cells}
    {new_buffer, removed_lines}
  end

  def get_line(buffer, y) when y >= 0 and y < buffer.height do
    case buffer.cells do
      nil -> []
      cells -> Enum.at(cells, y, [])
    end
  end

  def get_line(_, _), do: []

  def get_cell_at(buffer, x, y) do
    Raxol.Terminal.ScreenBuffer.WriteOps.get_cell(buffer, x, y)
  end
end
