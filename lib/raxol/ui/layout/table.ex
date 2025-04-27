defmodule Raxol.UI.Layout.Table do
  @moduledoc """
  Handles measurement and positioning logic for Table elements within the LayoutEngine.
  """

  require Logger

  @doc """
  Measures the required space for a table and returns a single positioned table element.
  """
  def measure_and_position(%{attrs: attrs} = _table_element, space, acc) do
    # Extract attributes passed from the View/Component via Elements.table/1
    original_data = Map.get(attrs, :data, [])       # Use :data attribute
    columns_config = Map.get(attrs, :columns, []) # Get column config

    # Extract headers from the columns config
    headers = Enum.map(columns_config, fn col -> Map.get(col, :header, "") end)

    num_cols = length(columns_config)
    num_rows = length(original_data) # Use length of original data

    # Column width calculation using :columns config preferentially
    col_widths =
      if num_cols > 0 do
        Enum.map(columns_config, fn col_conf ->
          # Use explicit width from config, fallback calculation if needed
          # Add padding
          Map.get(col_conf, :width, 10) # Default width if not specified
        end)
      else
        # Fallback if :columns is empty/missing (less robust)
        fallback_num_cols = if headers != [], do: length(headers), else: (hd(original_data) |> then(&length(&1)) || 0)
        if fallback_num_cols > 0 do
          Enum.map(0..(fallback_num_cols - 1), fn col_index ->
            header_width = if headers != [], do: String.length(Enum.at(headers, col_index, "")), else: 0
            # Use original_data for fallback calculation
            max_data_width = Enum.reduce(original_data, 0, fn data_item, max_w ->
              # Extract cell data based on column key for fallback
              # This assumes data_item is a map and column config has :key
              # TODO: This fallback might need refinement based on actual data structure
              key = columns_config |> Enum.at(col_index) |> Map.get(:key)
              cell_content = Map.get(data_item, key, "") |> to_string()
              max(String.length(cell_content), max_w)
            end)
            max(header_width, max_data_width) + 2 # Add 2 for padding
          end)
        else
          [] # No columns found
        end
      end

    # Calculate total width (sum of cols + separators)
    separator_width = if num_cols > 1, do: (num_cols - 1) * 3, else: 0 # " | "
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
    Logger.debug(
      "[Layout.Table] Measured table: W=#{final_width}, H=#{final_height}, ColWidths=#{inspect col_widths}"
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
          _component_type: Map.get(attrs, :component_type, :table), # Ensure component_type is present
          _headers: headers, # Pass the extracted headers
          _data: original_data, # Pass the original data
          _col_widths: col_widths # Pass calculated widths
          # Keep other original attrs like _scroll_top if passed
        })
    }

    # --- Logging ---
    Logger.debug("[Layout.Table] Returning positioned element: #{inspect positioned_table}")
    # ---------------

    [positioned_table | acc]
  end

  # Fallback for invalid table data?
  def measure_and_position(element, _space, acc) do
    Logger.warning("Layout.Table: Received unexpected element: #{inspect(element)}")
    acc
  end
end
