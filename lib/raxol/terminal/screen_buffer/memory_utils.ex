defmodule Raxol.Terminal.ScreenBuffer.MemoryUtils do
  @moduledoc """
  Handles memory usage calculations for the terminal screen buffer.

  This module provides utilities for estimating memory consumption of buffer components,
  including cells, scrollback, selection state, and other buffer elements.
  """

  @doc """
  Gets the estimated memory usage of the screen buffer.
  """
  def get_memory_usage(%{cells: cells, scrollback: scrollback, selection: selection,
                        scroll_region: scroll_region, damage_regions: damage_regions}) do
    # Calculate memory usage for main cells grid
    cells_usage = calculate_cells_memory_usage(cells)

    # Calculate memory usage for scrollback
    scrollback_usage = calculate_cells_memory_usage(scrollback)

    # Calculate memory usage for other components
    # 4 integers * 8 bytes
    selection_usage = if selection, do: 32, else: 0
    # 2 integers * 8 bytes
    scroll_region_usage = if scroll_region, do: 16, else: 0
    # 4 integers * 8 bytes per region
    damage_regions_usage = length(damage_regions) * 32

    # Base struct overhead and other fields
    # Rough estimate for struct overhead and other fields
    base_usage = 256

    cells_usage + scrollback_usage + selection_usage + scroll_region_usage +
      damage_regions_usage + base_usage
  end

  # Private helper to calculate memory usage for a grid of cells
  defp calculate_cells_memory_usage(cells) when is_list(cells) do
    total_cells =
      Enum.reduce(cells, 0, fn row, acc ->
        acc + length(row)
      end)

    # Rough estimate: each cell is about 64 bytes (including overhead)
    total_cells * 64
  end

  defp calculate_cells_memory_usage(_), do: 0
end
