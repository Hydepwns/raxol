defmodule Raxol.Terminal.Graphics.ChartDataUtils do
  @moduledoc """
  Shared utilities for chart data processing and transformation.

  This module contains common functions used across different chart modules
  to avoid code duplication and ensure consistent data processing behavior.
  """

  @doc """
  Flattens 2D heatmap data into a list of data points.

  Takes a 2D array (list of lists) and converts it into a flat list of
  data points with x, y coordinates and values.

  ## Parameters

  - `data` - 2D array (list of rows, where each row is a list of values)

  ## Returns

  List of maps with :x, :y, :value, and :timestamp keys.

  ## Examples

      iex> data = [[1, 2], [3, 4]]
      iex> ChartDataUtils.flatten_heatmap_data(data)
      [
        %{x: 0, y: 0, value: 1, timestamp: _},
        %{x: 1, y: 0, value: 2, timestamp: _},
        %{x: 0, y: 1, value: 3, timestamp: _},
        %{x: 1, y: 1, value: 4, timestamp: _}
      ]
  """
  @spec flatten_heatmap_data(list(list(number()))) :: list(map())
  def flatten_heatmap_data(data) do
    data
    |> Enum.with_index()
    |> Enum.flat_map(fn {row, y} ->
      row
      |> Enum.with_index()
      |> Enum.map(fn {value, x} ->
        %{x: x, y: y, value: value, timestamp: System.system_time(:millisecond)}
      end)
    end)
  end

  @doc """
  Converts histogram values into data points with binning.

  Takes a list of values and creates histogram bins with counts.

  ## Parameters

  - `values` - List of numeric values to bin
  - `config` - Configuration map with optional :bins key (defaults to 10)

  ## Returns

  List of maps representing histogram bins with counts.

  ## Examples

      iex> values = [1, 2, 3, 4, 5]
      iex> config = %{bins: 3}
      iex> ChartDataUtils.histogram_data_points(values, config)
      [
        %{bin: 0, start: 1.0, end: 2.33, count: 2, timestamp: _},
        %{bin: 1, start: 2.33, end: 3.67, count: 2, timestamp: _},
        %{bin: 2, start: 3.67, end: 5.0, count: 1, timestamp: _}
      ]
  """
  @spec histogram_data_points(list(number()), map()) :: list(map())
  def histogram_data_points(values, config)
      when is_list(values) and is_map(config) do
    bins = Map.get(config, :bins, 10)
    {min_val, max_val} = Enum.min_max(values)
    bin_width = (max_val - min_val) / bins

    # Create histogram bins
    Enum.map(0..(bins - 1), fn i ->
      bin_start = min_val + i * bin_width
      bin_end = bin_start + bin_width
      bin_values = Enum.filter(values, &(&1 >= bin_start and &1 < bin_end))

      %{
        bin: i,
        start: bin_start,
        end: bin_end,
        count: length(bin_values),
        timestamp: System.system_time(:millisecond)
      }
    end)
  end

  def histogram_data_points([], _config), do: []
end
