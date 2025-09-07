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
  @spec get_cell_at_coordinates(map(), non_neg_integer(), non_neg_integer()) ::
          {:valid, Cell.t()} | {:invalid, Cell.t()}
  def get_cell_at_coordinates(state, x, y) do
    case coordinates_valid?(state, x, y) do
      true ->
        {:valid, extract_and_clean_cell(state, x, y)}

      false ->
        {:invalid, create_default_cell()}
    end
  end

  @doc """
  Validates if coordinates are within buffer bounds.
  """
  @spec coordinates_valid?(map(), non_neg_integer(), non_neg_integer()) ::
          boolean()
  def coordinates_valid?(state, x, y) do
    x >= 0 and y >= 0 and x < state.active_buffer.width and
      y < state.active_buffer.height
  end

  @doc """
  Validates if coordinates are valid for setting cells.
  """
  @spec coordinates_valid_for_set?(map(), non_neg_integer(), non_neg_integer()) ::
          boolean()
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

  alias Raxol.Terminal.Buffer.CellHelper

  @doc """
  Creates a cell from input data.
  """
  @spec create_cell_from_input(Raxol.Terminal.Cell.t()) ::
          Raxol.Terminal.Cell.t()
  defdelegate create_cell_from_input(cell), to: CellHelper

  @doc """
  Updates a cell in the buffer.
  """
  @spec update_buffer_cell(
          map(),
          non_neg_integer(),
          non_neg_integer(),
          Raxol.Terminal.Cell.t()
        ) :: map()
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

    case cell_empty?(cell) do
      true ->
        create_default_cell()

      false ->
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
                case is_list(cell) do
                  true ->
                    List.first(cell) || create_default_cell()

                  false ->
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
end
