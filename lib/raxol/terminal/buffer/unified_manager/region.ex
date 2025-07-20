defmodule Raxol.Terminal.Buffer.UnifiedManager.Region do
  @moduledoc """
  Handles region operations for the unified buffer manager.

  This module provides functions for filling regions, validating regions,
  and managing region-based operations.
  """

  alias Raxol.Terminal.Buffer.Cell

  @doc """
  Validates if a region is within buffer bounds.
  """
  @spec region_valid?(map(), non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()) :: boolean()
  def region_valid?(state, x, y, width, height) do
    coordinates_valid_for_set?(state, x, y) and
      x + width <= state.active_buffer.width and
      y + height <= state.active_buffer.height
  end

  @doc """
  Fills a region with a cell.
  """
  @spec fill_region_with_cell(map(), non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer(), Cell.t()) :: map()
  def fill_region_with_cell(buffer, x, y, width, height, cell) do
    new_cell = create_cell_from_input(cell)

    updated_cells =
      buffer.cells
      |> Enum.with_index()
      |> Enum.map(fn {row, row_y} ->
        if row_in_region?(row_y, y, height) do
          update_row_in_region(row, x, width, new_cell)
        else
          row
        end
      end)

    %{buffer | cells: updated_cells}
  end

  @doc """
  Checks if a row is within a region.
  """
  @spec row_in_region?(non_neg_integer(), non_neg_integer(), non_neg_integer()) :: boolean()
  def row_in_region?(row_y, y, height) do
    row_y >= y and row_y < y + height
  end

  @doc """
  Checks if a column is within a region.
  """
  @spec col_in_region?(non_neg_integer(), non_neg_integer(), non_neg_integer()) :: boolean()
  def col_in_region?(col_x, x, width) do
    col_x >= x and col_x < x + width
  end

  @doc """
  Updates a row within a region.
  """
  @spec update_row_in_region(list(), non_neg_integer(), non_neg_integer(), Cell.t()) :: list()
  def update_row_in_region(row, x, width, new_cell) do
    row
    |> Enum.with_index()
    |> Enum.map(fn {col_cell, col_x} ->
      if col_in_region?(col_x, x, width) do
        new_cell
      else
        col_cell
      end
    end)
  end

  # Private functions

  defp coordinates_valid_for_set?(state, x, y) do
    x >= 0 and y >= 0 and x < state.active_buffer.width and
      y < state.active_buffer.height
  end

  defp create_cell_from_input(cell) do
    # Handle both old and new cell formats
    style = case cell do
      %{style: %Raxol.Terminal.ANSI.TextFormatting.Core{} = style} ->
        style
      %{style: %Raxol.Terminal.ANSI.TextFormatting{} = style} ->
        style
      %{foreground: fg, background: bg} = old_cell ->
        # Convert old format to new format
        %Raxol.Terminal.ANSI.TextFormatting.Core{
          foreground: fg,
          background: bg,
          bold: Map.get(old_cell, :bold, false),
          italic: Map.get(old_cell, :italic, false),
          underline: Map.get(old_cell, :underline, false),
          blink: Map.get(old_cell, :blink, false),
          reverse: Map.get(old_cell, :reverse, false),
          double_width: Map.get(old_cell, :double_width, false),
          double_height: Map.get(old_cell, :double_height, :none),
          faint: Map.get(old_cell, :faint, false),
          conceal: Map.get(old_cell, :conceal, false),
          strikethrough: Map.get(old_cell, :strikethrough, false),
          fraktur: Map.get(old_cell, :fraktur, false),
          double_underline: Map.get(old_cell, :double_underline, false),
          framed: Map.get(old_cell, :framed, false),
          encircled: Map.get(old_cell, :encircled, false),
          overlined: Map.get(old_cell, :overlined, false),
          hyperlink: Map.get(old_cell, :hyperlink, nil)
        }
      _ ->
        Raxol.Terminal.ANSI.TextFormatting.Core.new()
    end

    %Raxol.Terminal.Cell{
      char: cell.char,
      style: style,
      dirty: Map.get(cell, :dirty, false),
      wide_placeholder: Map.get(cell, :wide_placeholder, false)
    }
  end
end
