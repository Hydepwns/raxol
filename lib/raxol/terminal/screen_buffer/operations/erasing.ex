defmodule Raxol.Terminal.ScreenBuffer.Operations.Erasing do
  @moduledoc """
  Erasing operations for the screen buffer.

  This module handles various erasing operations including
  erase in display and erase in line with different modes.
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cell

  @doc """
  Erases in display based on mode.

  Mode values:
  - 0: From cursor to end of display
  - 1: From start to cursor
  - 2: Entire display
  - 3: Entire display including scrollback
  """
  @spec erase_in_display(ScreenBuffer.t(), non_neg_integer(), map()) ::
          ScreenBuffer.t()
  def erase_in_display(buffer, mode, cursor_pos \\ %{x: 0, y: 0})

  def erase_in_display(buffer, 0, cursor_pos) do
    # Erase from cursor to end of display
    erase_from_cursor_to_end(buffer, cursor_pos)
  end

  def erase_in_display(buffer, 1, cursor_pos) do
    # Erase from start to cursor
    erase_from_start_to_cursor(buffer, cursor_pos)
  end

  def erase_in_display(buffer, 2, _cursor_pos) do
    # Erase entire display
    clear_display(buffer)
  end

  def erase_in_display(buffer, 3, _cursor_pos) do
    # Erase entire display including scrollback
    clear_display_with_scrollback(buffer)
  end

  def erase_in_display(buffer, _, _), do: buffer

  @doc """
  Erases in line based on mode.

  Mode values:
  - 0: From cursor to end of line
  - 1: From start of line to cursor
  - 2: Entire line
  """
  @spec erase_in_line(ScreenBuffer.t(), non_neg_integer(), map()) ::
          ScreenBuffer.t()
  def erase_in_line(buffer, mode, cursor_pos \\ %{x: 0, y: 0})

  def erase_in_line(buffer, 0, cursor_pos) do
    # Erase from cursor to end of line
    erase_line_from_cursor_to_end(buffer, cursor_pos)
  end

  def erase_in_line(buffer, 1, cursor_pos) do
    # Erase from start of line to cursor
    erase_line_from_start_to_cursor(buffer, cursor_pos)
  end

  def erase_in_line(buffer, 2, cursor_pos) do
    # Erase entire line
    clear_line(buffer, cursor_pos.y)
  end

  def erase_in_line(buffer, _, _), do: buffer

  # Private helper functions

  defp erase_from_cursor_to_end(buffer, %{x: x, y: y}) do
    cells = buffer.cells || []

    new_cells =
      cells
      |> Enum.with_index()
      |> Enum.map(fn {row, row_idx} ->
        cond do
          row_idx < y -> row
          row_idx == y -> erase_row_from(row, x)
          true -> create_empty_row(buffer.width)
        end
      end)

    %{buffer | cells: new_cells}
  end

  defp erase_from_start_to_cursor(buffer, %{x: x, y: y}) do
    cells = buffer.cells || []

    new_cells =
      cells
      |> Enum.with_index()
      |> Enum.map(fn {row, row_idx} ->
        cond do
          row_idx < y -> create_empty_row(buffer.width)
          row_idx == y -> erase_row_to(row, x)
          true -> row
        end
      end)

    %{buffer | cells: new_cells}
  end

  defp erase_line_from_cursor_to_end(buffer, %{x: x, y: y}) do
    cells = buffer.cells || []

    new_cells =
      cells
      |> Enum.with_index()
      |> Enum.map(fn {row, row_idx} ->
        if row_idx == y do
          erase_row_from(row, x)
        else
          row
        end
      end)

    %{buffer | cells: new_cells}
  end

  defp erase_line_from_start_to_cursor(buffer, %{x: x, y: y}) do
    cells = buffer.cells || []

    new_cells =
      cells
      |> Enum.with_index()
      |> Enum.map(fn {row, row_idx} ->
        if row_idx == y do
          erase_row_to(row, x)
        else
          row
        end
      end)

    %{buffer | cells: new_cells}
  end

  defp clear_display(buffer) do
    empty_cells =
      for _ <- 0..(buffer.height - 1) do
        create_empty_row(buffer.width)
      end

    %{buffer | cells: empty_cells}
  end

  defp clear_display_with_scrollback(buffer) do
    buffer
    |> clear_display()
    |> Map.put(:scrollback, [])
  end

  defp clear_line(buffer, y) when y >= 0 and y < buffer.height do
    cells = buffer.cells || []

    new_cells =
      cells
      |> Enum.with_index()
      |> Enum.map(fn {row, row_idx} ->
        if row_idx == y do
          create_empty_row(buffer.width)
        else
          row
        end
      end)

    %{buffer | cells: new_cells}
  end

  defp clear_line(buffer, _), do: buffer

  defp create_empty_row(width) do
    List.duplicate(Cell.new(), width)
  end

  defp erase_row_from(row, x) do
    row
    |> Enum.with_index()
    |> Enum.map(fn {cell, idx} ->
      if idx >= x, do: Cell.new(), else: cell
    end)
  end

  defp erase_row_to(row, x) do
    row
    |> Enum.with_index()
    |> Enum.map(fn {cell, idx} ->
      if idx <= x, do: Cell.new(), else: cell
    end)
  end
end
