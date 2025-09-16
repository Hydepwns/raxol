defmodule Raxol.Terminal.Buffer.Operations.Erasing do
  @moduledoc """
  Provides erase operations for the terminal buffer.
  Handles erasing display and line content based on ANSI escape sequences.
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cell

  @doc """
  Erases content in the display based on the mode.
  Mode 0: From cursor to end of display
  Mode 1: From start of display to cursor
  Mode 2: Entire display
  """
  @spec erase_in_display(
          ScreenBuffer.t(),
          non_neg_integer(),
          {non_neg_integer(), non_neg_integer()}
        ) ::
          ScreenBuffer.t()
  def erase_in_display(buffer, mode, {y, x}) do
    case mode do
      0 -> erase_from_cursor_to_end(buffer, y, x)
      1 -> erase_from_start_to_cursor(buffer, y, x)
      2 -> erase_entire_display(buffer)
      _ -> buffer
    end
  end

  @doc """
  Erases content in a line based on the mode.
  Mode 0: From cursor to end of line
  Mode 1: From start of line to cursor
  Mode 2: Entire line
  """
  @spec erase_in_line(
          ScreenBuffer.t(),
          non_neg_integer(),
          {non_neg_integer(), non_neg_integer()}
        ) ::
          ScreenBuffer.t()
  def erase_in_line(buffer, mode, {y, x}) do
    case mode do
      0 -> erase_line_from_cursor(buffer, y, x)
      1 -> erase_line_to_cursor(buffer, y, x)
      2 -> erase_entire_line(buffer, y)
      _ -> buffer
    end
  end

  # Private helper functions

  defp erase_from_cursor_to_end(buffer, y, x) do
    empty_cell = Cell.new(" ", buffer.default_style)

    new_cells =
      buffer.cells
      |> Enum.with_index()
      |> Enum.map(fn {line, line_y} ->
        cond do
          line_y < y -> line
          line_y == y -> erase_line_segment(line, x, length(line), empty_cell)
          true -> List.duplicate(empty_cell, buffer.width)
        end
      end)

    %{buffer | cells: new_cells}
  end

  defp erase_from_start_to_cursor(buffer, y, x) do
    empty_cell = Cell.new(" ", buffer.default_style)

    new_cells =
      buffer.cells
      |> Enum.with_index()
      |> Enum.map(fn {line, line_y} ->
        cond do
          line_y < y -> List.duplicate(empty_cell, buffer.width)
          line_y == y -> erase_line_segment(line, 0, x + 1, empty_cell)
          true -> line
        end
      end)

    %{buffer | cells: new_cells}
  end

  defp erase_entire_display(buffer) do
    empty_cell = Cell.new(" ", buffer.default_style)

    new_cells =
      for _ <- 1..buffer.height do
        List.duplicate(empty_cell, buffer.width)
      end

    %{buffer | cells: new_cells}
  end

  defp erase_line_from_cursor(buffer, y, x) do
    empty_cell = Cell.new(" ", buffer.default_style)

    new_cells =
      buffer.cells
      |> Enum.with_index()
      |> Enum.map(fn {line, line_y} ->
        if line_y == y do
          erase_line_segment(line, x, length(line), empty_cell)
        else
          line
        end
      end)

    %{buffer | cells: new_cells}
  end

  defp erase_line_to_cursor(buffer, y, x) do
    empty_cell = Cell.new(" ", buffer.default_style)

    new_cells =
      buffer.cells
      |> Enum.with_index()
      |> Enum.map(fn {line, line_y} ->
        if line_y == y do
          erase_line_segment(line, 0, x + 1, empty_cell)
        else
          line
        end
      end)

    %{buffer | cells: new_cells}
  end

  defp erase_entire_line(buffer, y) do
    empty_cell = Cell.new(" ", buffer.default_style)

    new_cells =
      buffer.cells
      |> Enum.with_index()
      |> Enum.map(fn {line, line_y} ->
        if line_y == y do
          List.duplicate(empty_cell, buffer.width)
        else
          line
        end
      end)

    %{buffer | cells: new_cells}
  end

  defp erase_line_segment(line, start_x, end_x, empty_cell) do
    line
    |> Enum.with_index()
    |> Enum.map(fn {cell, x} ->
      if x >= start_x and x < end_x do
        empty_cell
      else
        cell
      end
    end)
  end
end
