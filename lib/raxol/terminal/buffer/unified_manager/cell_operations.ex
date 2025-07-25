defmodule Raxol.Terminal.Buffer.UnifiedManager.CellOperations do
  @moduledoc """
  Handles cell operations for the unified buffer manager.

  This module provides functions for getting, setting, and manipulating
  individual cells in the buffer.
  """

  alias Raxol.Terminal.Cell

  @doc """
  Gets a cell from the buffer at the specified coordinates.
  """
  @spec get_cell_at_coordinates(map(), non_neg_integer(), non_neg_integer()) :: {:valid, Cell.t()} | {:invalid, Cell.t()}
  def get_cell_at_coordinates(state, x, y) do
    if coordinates_valid?(state, x, y) do
      {:valid, extract_and_clean_cell(state, x, y)}
    else
      {:invalid, create_default_cell()}
    end
  end

  @doc """
  Validates if coordinates are within buffer bounds.
  """
  @spec coordinates_valid?(map(), non_neg_integer(), non_neg_integer()) :: boolean()
  def coordinates_valid?(state, x, y) do
    x >= 0 and y >= 0 and x < state.active_buffer.width and
      y < state.active_buffer.height
  end

  @doc """
  Validates if coordinates are valid for setting cells.
  """
  @spec coordinates_valid_for_set?(map(), non_neg_integer(), non_neg_integer()) :: boolean()
  def coordinates_valid_for_set?(state, x, y) do
    x >= 0 and y >= 0 and x < state.active_buffer.width and
      y < state.active_buffer.height
  end

  @doc """
  Creates a default cell.
  """
  @spec create_default_cell() :: Raxol.Terminal.Cell.t()
  def create_default_cell do
    %Raxol.Terminal.Cell{
      char: " ",
      style: Raxol.Terminal.ANSI.TextFormatting.Core.new(),
      dirty: false,
      wide_placeholder: false
    }
  end

  @doc """
  Creates a cell from input data.
  """
  @spec create_cell_from_input(Raxol.Terminal.Cell.t()) :: Raxol.Terminal.Cell.t()
  def create_cell_from_input(cell) do
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

  @doc """
  Updates a cell in the buffer.
  """
  @spec update_buffer_cell(map(), non_neg_integer(), non_neg_integer(), Raxol.Terminal.Cell.t()) :: map()
  def update_buffer_cell(buffer, x, y, new_cell) do
    updated_cells =
      buffer.cells
      |> List.update_at(y, fn row ->
        List.update_at(row, x, fn _ -> new_cell end)
      end)

    %{buffer | cells: updated_cells}
  end

  # Private functions

  defp extract_and_clean_cell(state, x, y) do
    cell = get_cell_from_buffer(state.active_buffer, x, y)

    if cell_empty?(cell) do
      create_default_cell()
    else
      clean_cell_style(cell)
    end
  end

  defp get_cell_from_buffer(buffer, x, y) do
    case buffer.cells do
      nil ->
        # Return a default cell if cells is nil
        create_default_cell()

      cells ->
        case Enum.at(cells, y) do
          nil ->
            # Row doesn't exist, return default cell
            create_default_cell()

          row ->
            case Enum.at(row, x) do
              nil ->
                # Cell doesn't exist, return default cell
                create_default_cell()

              cell ->
                if is_list(cell) do
                  List.first(cell) || create_default_cell()
                else
                  cell
                end
            end
        end
    end
  end

  defp cell_empty?(cell) do
    cell == nil or cell == %{}
  end

  defp clean_cell_style(%Raxol.Terminal.Cell{} = cell) do
    # For Terminal.Cell, we don't need to clean style since it uses separate fields
    cell
  end

  defp clean_cell_style(other) do
    # Return unchanged if not a Cell struct
    other
  end

  defp has_default_style?(_), do: true
end
