defmodule Raxol.UI.CellManager do
  @moduledoc """
  Handles cell operations, clipping, merging, and coordinate management.
  """

  @doc """
  Filters out cells with invalid coordinates.
  """
  def filter_valid_cells(cells) do
    Enum.filter(cells, fn {x, y, _char, _fg, _bg, _attrs} ->
      # Filter out cells with negative or invalid coordinates
      x >= 0 and y >= 0
    end)
  end

  @doc """
  Clips cells to specified bounds.
  """
  def clip_cells_to_bounds(cells, nil), do: cells

  def clip_cells_to_bounds(cells, {min_x, min_y, max_x, max_y}) do
    Enum.filter(cells, fn {x, y, _char, _fg, _bg, _attrs} ->
      x >= min_x and x <= max_x and y >= min_y and y <= max_y
    end)
  end

  @doc """
  Merges two cell lists, with the second list taking precedence at overlapping coordinates.
  """
  def merge_cells(base_cells, overlay_cells) do
    base_cells
    |> build_cell_map()
    |> overlay_cells(overlay_cells)
    |> Map.values()
  end

  @doc """
  Clips coordinates to valid bounds.
  """
  def clip_coordinates(x, y, width, height) do
    {max(0, x), max(0, y), max(0, width), max(0, height)}
  end

  @doc """
  Ensures a value is a list.
  """
  def ensure_list(value) when is_list(value), do: value
  def ensure_list(value), do: [value]

  # Helper to build a map of cells by coordinate
  defp build_cell_map(cells) do
    Enum.reduce(cells, %{}, fn {x, y, c, fg, bg, attrs}, acc ->
      Map.put(acc, {x, y}, {x, y, c, fg, bg, attrs})
    end)
  end

  # Helper to overlay cells onto a cell map
  defp overlay_cells(cell_map, overlay_cells) do
    Enum.reduce(overlay_cells, cell_map, fn {x, y, c, fg, bg, attrs}, acc ->
      Map.put(acc, {x, y}, {x, y, c, fg, bg, attrs})
    end)
  end
end
