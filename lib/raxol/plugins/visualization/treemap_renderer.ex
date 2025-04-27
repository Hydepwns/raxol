defmodule Raxol.Plugins.Visualization.TreemapRenderer do
  @moduledoc """
  Handles rendering logic for treemap visualizations within the VisualizationPlugin.
  Uses a squarified layout algorithm.
  """

  require Logger
  alias Raxol.Terminal.Cell
  alias Raxol.UI.Style
  alias Raxol.Plugins.Visualization.DrawingUtils

  @doc """
  Public entry point for rendering treemap content.
  Handles bounds checking, error handling, and calls the internal layout/drawing logic.
  Expects bounds map: %{width: w, height: h}.
  """
  def render_treemap_content(data, opts, %{width: width, height: height} = bounds, _state) do
    title = Map.get(opts, :title, "Treemap")

    # Basic validation for bounds and data
    if width < 1 or height < 1 or is_nil(data) or not is_map(data) or map_size(data) == 0 do
      Logger.warning(
        "[TreemapRenderer] Invalid data or bounds too small for treemap: #{inspect(bounds)}, data: #{inspect(data)}"
      )
      if width > 0 and height > 0 do
        DrawingUtils.draw_box_with_text("!", bounds)
      else
        [] # Return empty grid if bounds are zero/negative
      end
    else
      try do
        # Calculate layout
        total_value = Map.get(data, :value, 1) # Default to 1 if root value missing
        node_rects = layout_treemap_nodes(data, bounds, 0, total_value)

        # Draw the nodes based on the calculated rectangles
        draw_treemap_nodes(node_rects, title, bounds)
      rescue
        e ->
          stacktrace = __STACKTRACE__
          Logger.error(
            "[TreemapRenderer] Error rendering treemap: #{inspect(e)}\nStacktrace: #{inspect(stacktrace)}"
          )
          DrawingUtils.draw_box_with_text("[Render Error]", bounds)
      end
    end
  end

  # --- Private Treemap Layout Logic (Squarified) ---

  @doc false
  # Recursive helper to calculate treemap node rectangles using squarified approach.
  # Returns a flat list: [%{x:, y:, width:, height:, name:, value:, depth:}, ...]
  defp layout_treemap_nodes(node, %{x: bx, y: by, width: bw, height: bh} = bounds, depth, total_value_for_level) do
    children = Map.get(node, :children, [])

    # Base case: Leaf node or area too small
    if Enum.empty?(children) or bw < 1 or bh < 1 do
      if bw > 0 and bh > 0 do
        [
          %{ x: bx, y: by, width: bw, height: bh,
             name: Map.get(node, :name, "Unknown"),
             value: Map.get(node, :value, 0),
             depth: depth
           }
        ]
      else
        [] # Skip nodes with zero area
      end
    else
      # Ensure children have positive values for layout
      valid_children = Enum.filter(children, fn c -> Map.get(c, :value, 0) > 0 end)
      children_total_value = Enum.sum(Enum.map(valid_children, &Map.get(&1, :value, 0)))

      if children_total_value <= 0 do
         # If no valid children, treat as leaf node
         if bw > 0 and bh > 0 do
           [%{ x: bx, y: by, width: bw, height: bh,
                name: node.name <> " (No Child Values)", value: node.value, depth: depth }]
         else
           []
         end
      else
         # Use squarified layout algorithm
         squarify(valid_children, children_total_value, bounds, depth + 1, [])
      end
    end
  end

  # Squarified layout main loop
  defp squarify([], _total_value, _bounds, _depth, acc_rects), do: acc_rects
  defp squarify(children, total_value, %{width: bw, height: bh} = bounds, depth, acc_rects) do
    if bw < 1 or bh < 1 do
      acc_rects # Stop if remaining area is too small
    else
      # Determine split direction (lay out along the shorter side)
      horizontal = bw >= bh
      fixed_dimension = if horizontal, do: bh, else: bw

      # Find the best row of children to lay out
      {row, rest_children} = find_best_row(children, total_value, fixed_dimension)
      row_value = Enum.sum(Enum.map(row, &Map.get(&1, :value, 0)))
      row_proportion = row_value / total_value

      # Calculate bounds for the current row and the remaining area
      if horizontal do
        # Lay out horizontally (split width)
        row_width = max(1, round(bw * row_proportion))
        row_bounds = %{bounds | width: row_width}
        remaining_bounds = %{bounds | x: bounds.x + row_width, width: max(0, bw - row_width)}

        # Layout the row and recurse on the rest
        new_rects = layout_row(row, row_value, row_bounds, depth, false) # Split vertically within the row
        squarify(rest_children, total_value - row_value, remaining_bounds, depth, acc_rects ++ new_rects)
      else
        # Lay out vertically (split height)
        row_height = max(1, round(bh * row_proportion))
        row_bounds = %{bounds | height: row_height}
        remaining_bounds = %{bounds | y: bounds.y + row_height, height: max(0, bh - row_height)}

        # Layout the row and recurse on the rest
        new_rects = layout_row(row, row_value, row_bounds, depth, true) # Split horizontally within the row
        squarify(rest_children, total_value - row_value, remaining_bounds, depth, acc_rects ++ new_rects)
      end
    end
  end

  # Finds the row of children that minimizes the maximum aspect ratio
  defp find_best_row(children, total_value, fixed_dimension) do
     # Iterate through possible row lengths, calculating aspect ratio
     best_row = Enum.slice(children, 0, 1) # Start with first child
     min_max_aspect_ratio = calculate_max_aspect_ratio(best_row, total_value, fixed_dimension)

     find_best_row_recursive(children, total_value, fixed_dimension, best_row, min_max_aspect_ratio, 1)
  end

  defp find_best_row_recursive(_children, _total, _fixed_dim, best_row, _min_ratio, index) when index >= length(_children), do: {best_row, Enum.slice(_children, index..-1)}
  defp find_best_row_recursive(children, total_value, fixed_dimension, best_row, min_max_aspect_ratio, index) do
      current_row = Enum.slice(children, 0, index + 1)
      current_aspect_ratio = calculate_max_aspect_ratio(current_row, total_value, fixed_dimension)

      if current_aspect_ratio < min_max_aspect_ratio do
         # This row is better, continue with it
         find_best_row_recursive(children, total_value, fixed_dimension, current_row, current_aspect_ratio, index + 1)
      else
         # Previous row was better, stop here
         {best_row, Enum.slice(children, index..-1)}
      end
  end

  # Calculates the maximum aspect ratio for a given row of children
  defp calculate_max_aspect_ratio(row, total_value, fixed_dimension) do
    row_value = Enum.sum(Enum.map(row, &Map.get(&1, :value, 0)))
    scale_factor = row_value / total_value
    row_dimension = fixed_dimension * scale_factor

    Enum.map(row, fn child ->
       child_value = Map.get(child, :value, 0)
       child_proportion = child_value / row_value
       child_dimension = row_dimension * child_proportion
       # Aspect ratio: max(fixed/child, child/fixed)
       max(fixed_dimension / child_dimension, child_dimension / fixed_dimension)
    end) |> Enum.max()
  end

  # Lays out a single row/column of nodes recursively
  defp layout_row([], _row_value, _bounds, _depth, _split_vertically), do: []
  defp layout_row([child | rest], row_value, current_bounds, depth, split_vertically) do
     child_value = Map.get(child, :value, 0)

     if child_value <= 0 do
        # Skip zero-value children
        layout_row(rest, row_value, current_bounds, depth, split_vertically)
     else
        proportion = child_value / row_value
        if split_vertically do
           # Calculate height, width is fixed
           child_height = max(1, round(current_bounds.height * proportion))
           child_bounds = %{current_bounds | height: child_height}
           next_bounds = %{current_bounds | y: current_bounds.y + child_height, height: max(0, current_bounds.height - child_height)}
           # Layout this child and recurse
           layout_treemap_nodes(child, child_bounds, depth, child_value) ++
             layout_row(rest, row_value - child_value, next_bounds, depth, split_vertically)
        else
           # Calculate width, height is fixed
           child_width = max(1, round(current_bounds.width * proportion))
           child_bounds = %{current_bounds | width: child_width}
           next_bounds = %{current_bounds | x: current_bounds.x + child_width, width: max(0, current_bounds.width - child_width)}
           # Layout this child and recurse
           layout_treemap_nodes(child, child_bounds, depth, child_value) ++
             layout_row(rest, row_value - child_value, next_bounds, depth, split_vertically)
        end
     end
  end

  # --- Private Treemap Drawing ---

  @doc false
  # Draws the treemap nodes onto a grid based on calculated rectangles.
  defp draw_treemap_nodes(node_rects, title, %{width: width, height: height} = bounds) do
     # Create base grid
     grid = List.duplicate(List.duplicate(Cell.new(" "), width), height)
     grid_with_title = DrawingUtils.draw_text_centered(grid, 0, title)

     # Define a color palette (adjust as needed)
     color_palette = [:red, :green, :yellow, :blue, :magenta, :cyan, :white]
     num_colors = length(color_palette)

     # Draw each node rectangle onto the grid
     Enum.reduce(node_rects, grid_with_title, fn node_rect, acc_grid ->
        %{x: nx, y: ny, width: nw, height: nh, name: name, value: value, depth: depth} = node_rect

        # Choose color based on depth
        color = Enum.at(color_palette, rem(depth - 1, num_colors))
        text_color = DrawingUtils.get_contrasting_text_color(color)
        style = Style.new(fg: color)

        # Draw the border
        bordered_grid = DrawingUtils.draw_box_borders(acc_grid, ny, nx, nw, nh, style)

        # Draw label inside (if space allows)
        label = "#{name}\n#{value}" # Multi-line label
        label_lines = String.split(label, "\n")

        if nw > 2 and nh > length(label_lines) do
           Enum.reduce(Enum.with_index(label_lines), bordered_grid, fn {line, line_idx}, inner_grid ->
              # Center text horizontally, place vertically
              text_len = String.length(line)
              start_x = nx + 1 + max(0, div(nw - 2 - text_len, 2))
              start_y = ny + 1 + line_idx
              # Ensure text stays within bounds
              if start_y < ny + nh - 1 do
                 DrawingUtils.draw_text(inner_grid, start_y, start_x, String.slice(line, 0, nw - 2), style)
              else
                 inner_grid # Not enough vertical space for this line
              end
           end)
        else
           bordered_grid # Not enough space for label
        end
     end)
  end

end
