defmodule Raxol.UI.Layout.Table do
  @moduledoc """
  Handles measurement and positioning logic for Table elements within the LayoutEngine.
  """

  import Raxol.Guards

  require Raxol.Core.Runtime.Log

  @doc """
  Measures the required space for a table and returns a single positioned table element.
  """
  def measure_and_position(%{attrs: attrs} = _table_element, space, acc) do
    {final_width, final_height, col_widths, headers, original_data} =
      calculate_table_dimensions(attrs, space)

    positioned_table =
      build_positioned_table(
        attrs,
        space,
        final_width,
        final_height,
        col_widths,
        headers,
        original_data
      )

    [positioned_table | acc]
  end

  # Fallback for invalid table data?
  def measure_and_position(element, _space, acc) do
    Raxol.Core.Runtime.Log.warning(
      "Layout.Table: Received unexpected element: #{inspect(element)}"
    )

    acc
  end

  def measure(attrs_map, available_space) do
    # Extract table configuration
    columns = Map.get(attrs_map, :columns, [])
    data = Map.get(attrs_map, :data, [])
    headers = Enum.map(columns, &Map.get(&1, :header, ""))

    # Calculate column widths
    col_widths = calculate_column_widths(columns, data)

    # Calculate total width including separators
    separator_width =
      if length(col_widths) > 1, do: (length(col_widths) - 1) * 3, else: 0

    total_width = Enum.sum(col_widths) + separator_width

    # Calculate height (header + separator + data rows)
    # Header + separator line
    header_height = if headers != [], do: 2, else: 0
    data_height = length(data)
    total_height = header_height + data_height

    %{
      width: min(total_width, available_space.width),
      height: min(total_height, available_space.height)
    }
  end

  defp calculate_column_widths(columns, data) do
    Enum.map(columns, fn column ->
      # Get explicit width if specified
      case Map.get(column, :width) do
        width when is_integer(width) -> width
        :auto -> calculate_auto_width(column, data)
        _ -> calculate_auto_width(column, data)
      end
    end)
  end

  defp calculate_auto_width(column, data) do
    header_width = String.length(Map.get(column, :header, ""))

    # Calculate max width from data
    data_width =
      data
      |> Enum.map(fn row ->
        value = get_column_value(row, column)
        String.length(to_string(value))
      end)
      |> Enum.max(fn -> 0 end)

    # Add padding
    max(header_width, data_width) + 2
  end

  defp get_column_value(row, %{key: key}) when function?(key, 1),
    do: key.(row)

  defp get_column_value(row, %{key: key}) when atom?(key),
    do: Map.get(row, key)

  defp get_column_value(_row, _), do: ""

  defp get_cell_content_fallback(data_item, col_index) do
    case data_item do
      %{} when map_size(data_item) > 0 ->
        Map.get(data_item, col_index, "") |> to_string()

      _list when is_list(data_item) ->
        Enum.at(data_item, col_index, "") |> to_string()

      _ ->
        to_string(data_item)
    end
  end

  defp calculate_column_widths_with_fallback([], _headers, original_data) do
    fallback_num_cols = get_fallback_column_count(original_data)
    calculate_fallback_widths(fallback_num_cols, original_data)
  end

  defp calculate_column_widths_with_fallback(
         columns_config,
         _headers,
         original_data
       ) do
    Enum.map(columns_config, fn col_conf ->
      case Map.get(col_conf, :width) do
        width when is_integer(width) -> width
        :auto -> calculate_auto_width(col_conf, original_data)
        _ -> calculate_auto_width(col_conf, original_data)
      end
    end)
  end

  defp get_fallback_column_count(original_data) do
    case original_data do
      [] -> 0
      [first_row | _] -> length(first_row)
    end
  end

  defp calculate_fallback_widths(0, _original_data), do: []

  defp calculate_fallback_widths(fallback_num_cols, original_data) do
    # Calculate max width across all rows for each column
    Enum.map(0..(fallback_num_cols - 1), fn col_index ->
      max_data_width =
        Enum.reduce(original_data, 0, fn data_item, max_w ->
          cell_content = get_cell_content_fallback(data_item, col_index)
          max(String.length(cell_content), max_w)
        end)

      max_data_width + 2
    end)
  end

  defp calculate_table_dimensions(attrs, space) do
    original_data = Map.get(attrs, :data, [])
    columns_config = Map.get(attrs, :columns, [])
    headers = Enum.map(columns_config, fn col -> Map.get(col, :header, "") end)

    col_widths =
      calculate_column_widths_with_fallback(
        columns_config,
        headers,
        original_data
      )

    # Use actual number of columns from col_widths for calculations
    num_cols = length(col_widths)
    num_rows = length(original_data)

    # Calculate width
    separator_width = if num_cols > 1, do: (num_cols - 1) * 3, else: 0
    total_content_width = Enum.sum(col_widths) + separator_width
    final_width = min(total_content_width, space.width)

    # Calculate height
    header_height = if headers != [], do: 1, else: 0
    separator_height = if headers != [], do: 1, else: 0
    data_height = num_rows
    total_content_height = header_height + separator_height + data_height
    final_height = min(total_content_height, space.height)

    Raxol.Core.Runtime.Log.debug(
      "[Layout.Table] Measured table: W=#{final_width}, H=#{final_height}, ColWidths=#{inspect(col_widths)}"
    )

    {final_width, final_height, col_widths, headers, original_data}
  end

  defp build_positioned_table(
         attrs,
         space,
         final_width,
         final_height,
         col_widths,
         headers,
         original_data
       ) do
    positioned_table = %{
      type: :table,
      x: space.x,
      y: space.y,
      width: final_width,
      height: final_height,
      attrs:
        Map.merge(attrs, %{
          _component_type: Map.get(attrs, :component_type, :table),
          _headers: headers,
          _data: original_data,
          _col_widths: col_widths
        })
    }

    Raxol.Core.Runtime.Log.debug(
      "[Layout.Table] Returning positioned element: #{inspect(positioned_table)}"
    )

    positioned_table
  end
end
