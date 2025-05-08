defmodule Raxol.Plugins.Visualization.TreemapRenderer do
  @moduledoc """
  Handles rendering logic for treemap visualizations within the VisualizationPlugin.
  Uses a squarified layout algorithm.
  """

  require Logger
  alias Raxol.Terminal.Cell
  alias Raxol.Plugins.Visualization.DrawingUtils
  alias Raxol.Style

  @doc """
  Public entry point for rendering treemap content.
  Handles bounds checking, error handling, and calls the internal layout/drawing logic.
  Expects bounds map: %{width: w, height: h}.
  """
  def render_treemap_content(
        data,
        opts,
        %{width: width, height: height} = bounds,
        _state
      ) do
    title = Map.get(opts, :title, "Treemap")

    # Basic validation for bounds and data
    if width < 1 or height < 1 or is_nil(data) or not is_map(data) or
         map_size(data) == 0 do
      Logger.warning(
        "[TreemapRenderer] Invalid data or bounds too small for treemap: #{inspect(bounds)}, data: #{inspect(data)}"
      )

      if width > 0 and height > 0 do
        DrawingUtils.draw_box_with_text("!", bounds)
      else
        # Return empty grid if bounds are zero/negative
        []
      end
    else
      try do
        # Calculate layout
        # Default to 1 if root value missing
        total_value = Map.get(data, :value, 1)
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
  defp layout_treemap_nodes(
         node,
         %{x: bx, y: by, width: bw, height: bh} = bounds,
         depth,
         _total_value_for_level
       ) do
    children = Map.get(node, :children, [])

    # Base case: Leaf node or area too small
    if Enum.empty?(children) or bw < 1 or bh < 1 do
      if bw > 0 and bh > 0 do
        [
          %{
            x: bx,
            y: by,
            width: bw,
            height: bh,
            name: Map.get(node, :name, "Unknown"),
            value: Map.get(node, :value, 0),
            depth: depth
          }
        ]
      else
        # Skip nodes with zero area
        []
      end
    else
      # Ensure children have positive values for layout
      valid_children =
        Enum.filter(children, fn c -> Map.get(c, :value, 0) > 0 end)

      children_total_value =
        Enum.sum(Enum.map(valid_children, &Map.get(&1, :value, 0)))

      if children_total_value <= 0 do
        # If no valid children, treat as leaf node
        if bw > 0 and bh > 0 do
          [
            %{
              x: bx,
              y: by,
              width: bw,
              height: bh,
              name: node.name <> " (No Child Values)",
              value: node.value,
              depth: depth
            }
          ]
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

  defp squarify(
         children,
         total_value,
         %{width: bw, height: bh} = bounds,
         depth,
         acc_rects
       ) do
    if bw < 1 or bh < 1 do
      # Stop if remaining area is too small
      acc_rects
    else
      # Determine split direction (lay out along the shorter side)
      horizontal = bw >= bh
      fixed_dimension = if horizontal, do: bh, else: bw

      # Find the best row of children to lay out
      {row, rest_children} =
        find_best_row(children, total_value, fixed_dimension)

      row_value = Enum.sum(Enum.map(row, &Map.get(&1, :value, 0)))
      row_proportion = row_value / total_value

      # Calculate bounds for the current row and the remaining area
      if horizontal do
        # Lay out horizontally (split width)
        row_width = max(1, round(bw * row_proportion))
        row_bounds = %{bounds | width: row_width}

        remaining_bounds = %{
          bounds
          | x: bounds.x + row_width,
            width: max(0, bw - row_width)
        }

        # Layout the row and recurse on the rest
        # Split vertically within the row
        new_rects = layout_row(row, row_value, row_bounds, depth, false)

        squarify(
          rest_children,
          total_value - row_value,
          remaining_bounds,
          depth,
          acc_rects ++ new_rects
        )
      else
        # Lay out vertically (split height)
        row_height = max(1, round(bh * row_proportion))
        row_bounds = %{bounds | height: row_height}

        remaining_bounds = %{
          bounds
          | y: bounds.y + row_height,
            height: max(0, bh - row_height)
        }

        # Layout the row and recurse on the rest
        # Split horizontally within the row
        new_rects = layout_row(row, row_value, row_bounds, depth, true)

        squarify(
          rest_children,
          total_value - row_value,
          remaining_bounds,
          depth,
          acc_rects ++ new_rects
        )
      end
    end
  end

  # Finds the row of children that minimizes the maximum aspect ratio
  defp find_best_row(children, total_value, fixed_dimension) do
    # Iterate through possible row lengths, calculating aspect ratio
    # Start with first child
    best_row = Enum.slice(children, 0, 1)

    min_max_aspect_ratio =
      calculate_max_aspect_ratio(best_row, total_value, fixed_dimension)

    find_best_row_recursive(
      children,
      total_value,
      fixed_dimension,
      best_row,
      min_max_aspect_ratio,
      1
    )
  end

  defp find_best_row_recursive(
         [],
         _total,
         _fixed_dim,
         best_row,
         _min_ratio,
         _index
       ) do
    # Base case: No more children left to process
    {best_row, []}
  end

  defp find_best_row_recursive(
         [_head | tail] = children,
         total,
         fixed_dim,
         best_row,
         min_ratio,
         index
       ) do
    current_row = Enum.slice(children, 0..index)
    _current_row_sum = Enum.sum(Enum.map(current_row, & &1.value))

    # Calculate aspect ratio for the current row
    ratio = calculate_max_aspect_ratio(current_row, total, fixed_dim)

    # If current ratio is worse than the best found so far, the previous row was best
    if ratio < min_ratio do
      # Return the best row found and the remaining children
      {best_row, children}
    else
      # Current row is potentially better, continue recursion
      find_best_row_recursive(
        tail,
        total,
        fixed_dim,
        current_row,
        ratio,
        index + 1
      )
    end
  end

  # Handle case when index exceeds length (should be covered by first clause, but added for clarity)
  # Rename _children to children where used
  defp find_best_row_recursive(
         children,
         _total,
         _fixed_dim,
         best_row,
         _min_ratio,
         index
       )
       when index >= length(children),
       do: {best_row, Enum.slice(children, index..-1)}

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
    end)
    |> Enum.max()
  end

  # Lays out a single row/column of nodes recursively
  defp layout_row([], _row_value, _bounds, _depth, _split_vertically), do: []

  defp layout_row(
         [child | rest],
         row_value,
         current_bounds,
         depth,
         split_vertically
       ) do
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

        next_bounds = %{
          current_bounds
          | y: current_bounds.y + child_height,
            height: max(0, current_bounds.height - child_height)
        }

        # Layout this child and recurse
        layout_treemap_nodes(child, child_bounds, depth, child_value) ++
          layout_row(
            rest,
            row_value - child_value,
            next_bounds,
            depth,
            split_vertically
          )
      else
        # Calculate width, height is fixed
        child_width = max(1, round(current_bounds.width * proportion))
        child_bounds = %{current_bounds | width: child_width}

        next_bounds = %{
          current_bounds
          | x: current_bounds.x + child_width,
            width: max(0, current_bounds.width - child_width)
        }

        # Layout this child and recurse
        layout_treemap_nodes(child, child_bounds, depth, child_value) ++
          layout_row(
            rest,
            row_value - child_value,
            next_bounds,
            depth,
            split_vertically
          )
      end
    end
  end

  # --- Private Treemap Drawing ---

  @doc false
  # Draws the treemap nodes onto a grid based on calculated rectangles.
  defp draw_treemap_nodes(
         node_rects,
         title,
         %{width: width, height: height} = _bounds
       ) do
    # Base case: no nodes to draw
    if Enum.empty?(node_rects), do: []

    # Create base grid
    grid = List.duplicate(List.duplicate(Cell.new(" "), width), height)
    grid_with_title = DrawingUtils.draw_text_centered(grid, 0, title)

    # Define a color palette (adjust as needed)
    color_palette = [:red, :green, :yellow, :blue, :magenta, :cyan, :white]
    num_colors = length(color_palette)

    # Draw each node rectangle onto the grid
    Enum.reduce(node_rects, grid_with_title, fn node_rect, acc_grid ->
      %{
        x: nx,
        y: ny,
        width: nw,
        height: nh,
        name: name,
        value: _value,
        depth: depth
      } = node_rect

      # Choose color based on depth
      color = Enum.at(color_palette, rem(depth - 1, num_colors))
      # TODO: Add border style based on focus/selection?
      style = Style.new(bg: color)

      # Draw filled rectangle using put_cell
      grid_with_rect = draw_filled_rectangle(acc_grid, nx, ny, nw, nh, style)

      # Add label if space allows
      label = to_string(name)
      label_len = String.length(label)

      if nw >= label_len and nh >= 1 do
        # Calculate center position like draw_text_centered/3
        text_len = String.length(label)

        # Assuming acc_grid dimensions are still valid for nx, nw. This might be fragile.
        # If grid dimensions change, this needs recalculation.
        # Need grid width to calculate centering. Let's assume nw is sufficient proxy.
        start_x = nx + max(0, div(nw - text_len, 2))
        # Truncate text to fit remaining width
        truncated_text = String.slice(label, 0, max(0, nx + nw - start_x))

        text_style = Style.new(fg: :black, bg: color)

        # Call draw_text/4 directly with calculated position and style
        DrawingUtils.draw_text(
          grid_with_rect,
          ny + div(nh, 2),
          start_x,
          truncated_text,
          text_style
        )
      else
        grid_with_rect
      end
    end)
  end

  # Helper to draw a filled rectangle
  defp draw_filled_rectangle(grid, x, y, width, height, style) do
    Enum.reduce(y..(y + height - 1), grid, fn current_y, acc_grid ->
      Enum.reduce(x..(x + width - 1), acc_grid, fn current_x, inner_acc_grid ->
        # Get background char from style or default to space
        bg_char = Map.get(style.attrs, :bg_char, " ")
        cell = %{Raxol.Terminal.Cell.new(bg_char) | style: style}
        DrawingUtils.put_cell(inner_acc_grid, current_y, current_x, cell)
      end)
    end)
  end
end
