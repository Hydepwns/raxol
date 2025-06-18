defmodule Raxol.UI.Layout.Table do
  @moduledoc '''
  Handles measurement and positioning logic for Table elements within the LayoutEngine.
  '''

  require Raxol.Core.Runtime.Log

  @doc '''
  Measures the required space for a table and returns a single positioned table element.
  '''
  def measure_and_position(%{attrs: attrs} = _table_element, space, acc) do
    # Extract attributes passed from the View/Component via Elements.table/1
    # Use :data attribute
    original_data = Map.get(attrs, :data, [])
    # Get column config
    columns_config = Map.get(attrs, :columns, [])

    # Extract headers from the columns config
    headers = Enum.map(columns_config, fn col -> Map.get(col, :header, "") end)

    num_cols = length(columns_config)
    # Use length of original data
    num_rows = length(original_data)

    # Column width calculation using :columns config preferentially
    col_widths =
      if num_cols > 0 do
        Enum.map(columns_config, fn col_conf ->
          # Use explicit width from config, fallback calculation if needed
          # Add padding
          # Default width if not specified
          Map.get(col_conf, :width, 10)
        end)
      else
        # Fallback if :columns is empty/missing (less robust)
        fallback_num_cols =
          if headers != [],
            do: length(headers),
            else: hd(original_data) |> then(&length(&1)) || 0

        if fallback_num_cols > 0 do
          Enum.map(0..(fallback_num_cols - 1), fn col_index ->
            header_width =
              if headers != [],
                do: String.length(Enum.at(headers, col_index, "")),
                else: 0

            # Use original_data for fallback calculation
            max_data_width =
              Enum.reduce(original_data, 0, fn data_item, max_w ->
                # Extract cell data based on column key for fallback
                # This assumes data_item is a map and column config has :key
                # TODO: This fallback might need refinement based on actual data structure
                key = columns_config |> Enum.at(col_index) |> Map.get(:key)
                cell_content = Map.get(data_item, key, "") |> to_string()
                max(String.length(cell_content), max_w)
              end)

            # Add 2 for padding
            max(header_width, max_data_width) + 2
          end)
        else
          # No columns found
          []
        end
      end

    # Calculate total width (sum of cols + separators)
    # " | "
    separator_width = if num_cols > 1, do: (num_cols - 1) * 3, else: 0
    total_content_width = Enum.sum(col_widths) + separator_width
    # Clamp width to available space
    final_width = min(total_content_width, space.width)

    # Calculate height (header + separator + data rows)
    header_height = if headers != [], do: 1, else: 0
    separator_height = if headers != [], do: 1, else: 0
    data_height = num_rows
    total_content_height = header_height + separator_height + data_height
    # Clamp height to available space
    final_height = min(total_content_height, space.height)

    # --- Logging ---
    Raxol.Core.Runtime.Log.debug(
      "[Layout.Table] Measured table: W=#{final_width}, H=#{final_height}, ColWidths=#{inspect(col_widths)}"
    )

    # ---------------

    # Create the single positioned table element for the Renderer
    positioned_table = %{
      # Keep original type or set to :table? Let's use :table
      type: :table,
      x: space.x,
      y: space.y,
      width: final_width,
      height: final_height,
      # Pass original attributes, headers, data, and calculated widths
      # The renderer will need this info.
      attrs:
        Map.merge(attrs, %{
          # Ensure component_type is present
          _component_type: Map.get(attrs, :component_type, :table),
          # Pass the extracted headers
          _headers: headers,
          # Pass the original data
          _data: original_data,
          # Pass calculated widths
          _col_widths: col_widths
          # Keep other original attrs like _scroll_top if passed
        })
    }

    # --- Logging ---
    Raxol.Core.Runtime.Log.debug(
      "[Layout.Table] Returning positioned element: #{inspect(positioned_table)}"
    )

    # ---------------

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

  defp get_column_value(row, %{key: key}) when is_function(key, 1),
    do: key.(row)

  defp get_column_value(row, %{key: key}) when is_atom(key),
    do: Map.get(row, key)

  defp get_column_value(row, _), do: ""
end
