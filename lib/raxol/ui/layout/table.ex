defmodule Raxol.UI.Layout.Table do
  @moduledoc """
  Handles measurement and positioning logic for Table elements within the LayoutEngine.
  """

  require Raxol.Core.Runtime.Log

  @doc """
  Measures the required space for a table and returns a single positioned table element.
  """
  def measure_and_position(%{type: :table, attrs: attrs} = _element, space, acc) do
    attrs =
      cond do
        is_list(attrs) -> Map.new(attrs)
        is_map(attrs) -> attrs
        true -> %{}
      end

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
          width = extract_dim(col_conf, :width, 0, 10)

          case width do
            w when is_integer(w) -> w
            _ -> 10
          end
        end)
      else
        # Fallback if :columns is empty/missing
        # Determine fallback_num_cols based on original_data structure
        fallback_num_cols =
          cond do
            original_data != [] and is_list(hd(original_data)) ->
              hd(original_data) |> length()

            original_data != [] and is_map(hd(original_data)) ->
              hd(original_data) |> map_size()

            true ->
              0
          end

        if fallback_num_cols > 0 do
          Enum.map(0..(fallback_num_cols - 1), fn col_index ->
            # Note: headers will be [] if columns_config is empty
            header_width =
              if headers != [],
                do: String.length(Enum.at(headers, col_index, "")),
                else: 0

            # Use original_data for fallback calculation
            max_data_width =
              Enum.reduce(original_data, 0, fn data_item, max_w ->
                # Simplified cell_content extraction for when columns_config is empty.
                cell_content =
                  cond do
                    is_map(data_item) ->
                      # Attempt to get the nth key if data_item is a map.
                      # This relies on Map.keys ordering, which can be fragile.
                      all_keys = Map.keys(data_item)

                      if col_index < length(all_keys) do
                        Map.get(data_item, Enum.at(all_keys, col_index), "")
                        |> to_string()
                      else
                        # Not enough keys for this col_index
                        ""
                      end

                    is_list(data_item) ->
                      Enum.at(data_item, col_index, "") |> to_string()

                    true ->
                      # data_item is neither a map nor a list, or other unexpected structure.
                      ""
                  end

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

    Raxol.Core.Runtime.Log.debug(
      "[Layout.Table] Measured table: W=#{final_width}, H=#{final_height}, ColWidths=#{inspect(col_widths)}"
    )

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

    [positioned_table | acc]
  end

  # Fallback for invalid table data?
  def measure_and_position(element, _space, acc) do
    Raxol.Core.Runtime.Log.warning(
      "Layout.Table: Received unexpected element: #{inspect(element)}"
    )

    acc
  end

  defp extract_dim(attrs, key, tuple_index, default) do
    cond do
      is_map(attrs) and Map.has_key?(attrs, key) ->
        Map.get(attrs, key)

      is_tuple(attrs) and tuple_size(attrs) > tuple_index ->
        elem(attrs, tuple_index)

      true ->
        default
    end
  end
end
