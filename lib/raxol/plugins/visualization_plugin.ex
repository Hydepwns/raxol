defmodule Raxol.Plugins.VisualizationPlugin do
  @moduledoc """
  Plugin responsible for rendering visualization components like charts and treemaps.
  It receives data structures from the view rendering pipeline and outputs
  actual terminal cells.
  """
  @behaviour Raxol.Plugins.Plugin

  # Removed unused aliases
  # alias Contex.{Dataset, Plot}
  # alias Contex.BarChart

  require Logger

  # Corrected: Suppress Dialyzer warning for handle_cells/3
  @dialyzer {:nowarn_function, handle_cells: 3}

  # Add a module attribute for the cache
  @layout_cache_size 50

  # Add a module attribute for chart thresholds
  @max_chart_data_points 100
  @chart_sampling_threshold 500

  defstruct name: "visualization",
            version: "0.1.0",
            description: "Renders chart and treemap visualizations.",
            enabled: true,
            config: %{},
            dependencies: [],
            # Match manager API
            api_version: "1.0.0"

  # Add to the state structure
  defmodule State do
    defstruct [
      :cache_timeout,
      :layout_cache,
      :last_chart_hash,
      :last_treemap_hash,
      :cleanup_ref,
      # Add the standard plugin fields
      name: "visualization",
      version: "0.1.0",
      description: "Renders chart and treemap visualizations.",
      enabled: true,
      config: %{},
      dependencies: [],
      api_version: "1.0.0"
    ]
  end

  @impl true
  def init(config \\ %{}) do
    # Initialize state with cache structures
    schedule_cache_cleanup()

    plugin_state = struct(__MODULE__, config)

    {:ok,
     %State{
       cache_timeout: :timer.minutes(5),
       layout_cache: %{},
       last_chart_hash: nil,
       last_treemap_hash: nil,
       cleanup_ref: nil
     }}
  end

  @doc """
  Render chart content to terminal cells. Used for benchmarking and testing.
  """
  def render_chart_content(data, opts, bounds, state) do
    render_chart_content_internal(data, opts, bounds, state)
  end

  @doc """
  Render treemap content to terminal cells. Used for benchmarking and testing.
  """
  def render_treemap_content(data, opts, bounds, state) do
    render_treemap_content_internal(data, opts, bounds, state)
  end

  @impl true
  def handle_cells(cell, _emulator_state, plugin_state) do
    case cell do
      # Handle Chart Placeholder
      %{
        type: :placeholder,
        value: :chart,
        data: data,
        opts: opts,
        bounds: bounds
      } ->
        Logger.debug(
          "[VisualizationPlugin] Handling :chart placeholder. Bounds: #{inspect(bounds)}"
        )

        chart_cells = render_chart_content_internal(data, opts, bounds, plugin_state)
        # Return :ok, state (unchanged), replacement cells, empty commands
        {:ok, plugin_state, chart_cells, []}

      # Handle TreeMap Placeholder
      %{
        type: :placeholder,
        value: :treemap,
        data: data,
        opts: opts,
        bounds: bounds
      } ->
        Logger.debug(
          "[VisualizationPlugin] Handling :treemap placeholder. Bounds: #{inspect(bounds)}"
        )

        treemap_cells = render_treemap_content_internal(data, opts, bounds, plugin_state)
        # Return :ok, state (unchanged), replacement cells, empty commands
        {:ok, plugin_state, treemap_cells, []}

      # Handle Image Placeholder
      %{
        type: :placeholder,
        value: :image,
        data: data,
        opts: opts,
        bounds: bounds
      } ->
        Logger.debug(
          "[VisualizationPlugin] Handling :image placeholder. Bounds: #{inspect(bounds)}"
        )

        image_cells = render_image_content(data, opts, bounds)
        # Return :ok, state (unchanged), replacement cells, empty commands
        {:ok, plugin_state, image_cells, []}

      # Decline other cells
      _ ->
        {:cont, plugin_state}
    end
  end

  # --- Private Helpers ---

  # Renamed from render_chart_to_cells
  defp render_chart_content_internal(data, opts, bounds, state) do
    # Default to :bar chart if type is not specified or unknown
    # chart_type = Map.get(opts, :type, :bar) # Keep for future use if supporting other types
    title = Map.get(opts, :title, "Chart")
    # Remove unused key lookups for now
    # x_key = Map.get(opts, :x_key, :label)
    # y_key = Map.get(opts, :y_key, :value)
    # x_label = Map.get(opts, :x_axis_label, nil)
    # y_label = Map.get(opts, :y_axis_label, nil)

    # Ensure bounds are valid for rendering
    if bounds.width < 5 or bounds.height < 3 do
      Logger.warning(
        "[VisualizationPlugin] Bounds too small for chart rendering: #{inspect(bounds)}"
      )

      # Wrap in list for consistency removed, function does it
      draw_box_with_text("!", bounds)
    else
      try do
        # Compute cache key
        cache_key = compute_cache_key(data, bounds)

        # Check if we have a cached result
        case Map.get(state.layout_cache, cache_key) do
          nil ->
            # No cache hit, perform the rendering
            # First, sample the data if it's too large
            sampled_data = sample_chart_data(data)

            # Store metrics about this operation
            data_length = length(data)
            sampled_length = length(sampled_data)

            if data_length != sampled_length do
              # Log that we sampled the data
              Logger.debug(
                "[VisualizationPlugin] Data sampled for chart: #{data_length} -> #{sampled_length} points"
              )
            end

            # Record metrics
            start_time = System.monotonic_time(:millisecond)

            # Draw the chart with sampled data
            chart_cells = draw_tui_bar_chart(sampled_data, title, bounds)

            # Calculate rendering time
            render_time = System.monotonic_time(:millisecond) - start_time
            Raxol.Metrics.gauge("raxol.chart_render_time", render_time)
            Raxol.Metrics.increment("raxol.chart_cache_misses")

            # Update cache with the new result
            updated_cache =
              if map_size(state.layout_cache) >= @layout_cache_size do
                # Remove oldest entry if cache is full
                {_, trimmed_cache} =
                  Map.pop(
                    state.layout_cache,
                    Enum.at(Map.keys(state.layout_cache), 0)
                  )

                Map.put(trimmed_cache, cache_key, chart_cells)
              else
                Map.put(state.layout_cache, cache_key, chart_cells)
              end

            # Update state with the new cache
            new_state = %{state | layout_cache: updated_cache}
            GenServer.cast(self(), {:update_state, new_state})

            # Return the cells
            chart_cells

          cached_cells ->
            # Cache hit! Use the cached cells
            Raxol.Metrics.increment("raxol.chart_cache_hits")
            cached_cells
        end
      rescue
        e ->
          Logger.error(
            "[VisualizationPlugin] Error rendering chart: #{inspect(e)}"
          )

          # Wrap in list for consistency removed
          draw_box_with_text("[Render Error]", bounds)
      end
    end
  end

  # Add a function to sample chart data for large datasets
  defp sample_chart_data(data) when is_list(data) do
    data_length = length(data)

    cond do
      # If data is empty, return it as is
      data_length == 0 ->
        data

      # If data is small enough, return it as is
      data_length <= @max_chart_data_points ->
        data

      # If data is large but not huge, use simple sub-sampling
      data_length <= @chart_sampling_threshold ->
        # Calculate the step size to reduce to max_data_points
        step = Float.ceil(data_length / @max_chart_data_points) |> trunc()
        # Take every nth element
        Enum.take_every(data, step)

      # If data is very large, use more sophisticated sampling
      true ->
        # For very large datasets, use a window-based reduction approach

        # Group data into windows of approximately even size
        window_size =
          Float.ceil(data_length / @max_chart_data_points) |> trunc()

        data
        |> Enum.chunk_every(window_size)
        |> Enum.map(fn window ->
          # For each window, calculate representative value (e.g., mean, min, max)
          # Here we choose the maximum value in each window for better visual representation
          # but you could also use average or other statistics

          # Extract the y-values (assuming data is in {label, value} tuples)
          {label, _} = List.first(window)
          values = Enum.map(window, fn {_, value} -> value end)

          # Use the max value with the first label
          max_value = Enum.max(values)
          {label, max_value}
        end)
    end
  end

  # Handle non-list data
  defp sample_chart_data(data), do: data

  # Add private helper to compute cache key
  defp compute_cache_key(data, bounds) do
    data_hash = :erlang.phash2(data)
    bounds_hash = :erlang.phash2(bounds)
    {data_hash, bounds_hash}
  end

  # Update the render_treemap_content function to use caching
  defp render_treemap_content_internal(data, opts, bounds, state) do
    # TODO: Refine data structure assumption if needed
    # Assuming data is like: %{name: "Root", value: 100, children: [...]}
    _title = Map.get(opts, :title, "TreeMap")

    if is_nil(data) or map_size(data) == 0 or bounds.width < 1 or
         bounds.height < 1 do
      Logger.warning(
        "[VisualizationPlugin] Invalid data or bounds for treemap: #{inspect(bounds)}, data: #{inspect(data)}"
      )

      # Use simplified placeholder for very small areas
      if bounds.width > 0 and bounds.height > 0 do
        # Wrap in list, return tuple format
        [{bounds.x, bounds.y, %{char: ?#, fg: 7, bg: 0, style: %{}}}]
      else
        []
      end
    else
      try do
        # Compute cache key
        cache_key = compute_cache_key(data, bounds)

        # Check if we have a cached result
        case Map.get(state.layout_cache, cache_key) do
          nil ->
            # No cache hit, calculate layout
            # Calculate layout
            # Default to 1 if value missing
            total_value = Map.get(data, :value, 1)
            node_rects = layout_treemap_nodes(data, bounds, 0, total_value)

            # Update cache with the new result - limit cache size
            updated_cache =
              if map_size(state.layout_cache) >= @layout_cache_size do
                # Remove oldest entry if cache is full
                {_, trimmed_cache} =
                  Map.pop(
                    state.layout_cache,
                    Enum.at(Map.keys(state.layout_cache), 0)
                  )

                Map.put(trimmed_cache, cache_key, node_rects)
              else
                Map.put(state.layout_cache, cache_key, node_rects)
              end

            # Store metrics for this calculation
            layout_time = System.monotonic_time(:millisecond)
            Raxol.Metrics.gauge("raxol.treemap_layout_time", layout_time)
            Raxol.Metrics.increment("raxol.treemap_cache_misses")

            # Update state with the new cache
            new_state = %{state | layout_cache: updated_cache}
            GenServer.cast(self(), {:update_state, new_state})

            # Color palette for treemap depths
            # Same as bars, could be different
            color_palette = [2, 3, 4, 5, 6, 1]
            num_colors = Enum.count(color_palette)

            # Draw node boxes
            Enum.flat_map(node_rects, fn node_rect ->
              # Use depth for color variation, cycle through palette
              fg_color =
                Enum.at(color_palette, rem(node_rect.depth, num_colors))

              # Combine name and value for the label
              label = "#{node_rect.name} (#{node_rect.value})"
              # Pass color to draw_box_with_text
              # draw_box_with_text already returns a list of cell tuples
              draw_box_with_text(label, node_rect, fg: fg_color)
            end)

          cached_rects ->
            # Cache hit! Use the cached rectangles
            Raxol.Metrics.increment("raxol.treemap_cache_hits")

            # Color palette for treemap depths
            color_palette = [2, 3, 4, 5, 6, 1]
            num_colors = Enum.count(color_palette)

            # Draw node boxes from cached layout
            Enum.flat_map(cached_rects, fn node_rect ->
              # Use depth for color variation, cycle through palette
              fg_color =
                Enum.at(color_palette, rem(node_rect.depth, num_colors))

              # Combine name and value for the label
              label = "#{node_rect.name} (#{node_rect.value})"
              # Pass color to draw_box_with_text
              draw_box_with_text(label, node_rect, fg: fg_color)
            end)
        end
      rescue
        e ->
          Logger.error(
            "[VisualizationPlugin] Error rendering treemap: #{inspect(e)}"
          )

          # Optionally log stacktrace: :erlang.get_stacktrace()
          # Wrap in list for consistency
          draw_box_with_text("[TreeMap Render Error]", bounds)
      end
    end
  end

  # Helper to draw a simple box with text (refactored)
  # Ensure this returns the {x, y, cell_map} tuple format
  defp draw_box_with_text(text, bounds, opts \\ []) do
    width = bounds.width
    height = bounds.height
    x_start = bounds.x
    y_start = bounds.y
    fg = Keyword.get(opts, :fg, 7)
    bg = Keyword.get(opts, :bg, 0)
    # TODO: Add options for border characters

    cond do
      width < 1 or height < 1 ->
        []

      width == 1 and height == 1 ->
        # Single cell - use a block instead of #
        # Return tuple format
        [{x_start, y_start, %{char: ?█, fg: fg, bg: bg, style: %{}}}]

      # Only draw border if width >= 2 and height >= 2
      width < 2 or height < 2 ->
        # Fill area with shade if no border
        # Use color to pick shade
        shade_char = Enum.at([?·, ?░, ?▒, ?▓], rem(fg, 4))
        # Return tuple format
        for x <- x_start..(x_start + width - 1),
            y <- y_start..(y_start + height - 1) do
          {x, y, %{char: shade_char, fg: fg, bg: bg, style: %{}}}
        end

      # Draw box with border
      true ->
        # Top/Bottom borders
        top_bottom =
          for x <- x_start..(x_start + width - 1) do
            # Return tuple format
            [
              {x, y_start, %{char: ?─, fg: fg, bg: bg, style: %{}}},
              {x, y_start + height - 1,
               %{char: ?─, fg: fg, bg: bg, style: %{}}}
            ]
          end
          |> List.flatten()

        # Side borders
        sides =
          for y <- (y_start + 1)..(y_start + height - 2) do
            # Return tuple format
            [
              {x_start, y, %{char: ?│, fg: fg, bg: bg, style: %{}}},
              {x_start + width - 1, y,
               %{char: ?│, fg: fg, bg: bg, style: %{}}}
            ]
          end
          |> List.flatten()

        # Corners (overwrite previous border parts)
        corners = [
          # Return tuple format
          {x_start, y_start, %{char: ?┌, fg: fg, bg: bg, style: %{}}},
          {x_start + width - 1, y_start,
           %{char: ?┐, fg: fg, bg: bg, style: %{}}},
          {x_start, y_start + height - 1,
           %{char: ?└, fg: fg, bg: bg, style: %{}}},
          {x_start + width - 1, y_start + height - 1,
           %{char: ?┘, fg: fg, bg: bg, style: %{}}}
        ]

        # Text Handling (centered, clipped)
        max_text_width = width - 2
        max_text_height = height - 2

        # Only draw text if space allows (at least 3x3 box)
        text_cells =
          if max_text_width >= 1 and max_text_height >= 1 do
            clipped_text =
              if String.length(text) > max_text_width do
                # Improved truncation
                String.slice(text, 0, max(0, max_text_width - 1)) <> "…"
              else
                text
              end

            # Calculate centered position
            # Center vertically
            text_y = y_start + 1 + max(0, div(max_text_height - 1, 2))
            # Center horizontally
            text_x_offset =
              max(0, div(max_text_width - String.length(clipped_text), 2))

            text_x = x_start + 1 + text_x_offset

            clipped_text
            |> String.graphemes()
            |> Enum.with_index()
            |> Enum.map(fn {grapheme, i} ->
              [char_code | _] = String.to_charlist(grapheme)
              # Return tuple format
              {text_x + i, text_y,
               %{char: char_code, fg: fg, bg: bg, style: %{}}}
            end)
          else
            # No space for text
            []
          end

        # Combine, ensuring corners overwrite borders
        # Use Map for efficient overwrite based on {x, y} key
        initial_map =
          Map.new(top_bottom ++ sides, fn {x, y, c} -> {{x, y}, {x, y, c}} end)

        final_map =
          Enum.reduce(corners ++ text_cells, initial_map, fn {x, y, c}, map ->
            Map.put(map, {x, y}, {x, y, c})
          end)

        Map.values(final_map)
    end
  end

  # --- TUI TreeMap Layout --- #

  # Recursive helper to calculate treemap node rectangles
  # Returns a flat list: [%{x:, y:, width:, height:, name:, value:, depth:}, ...]
  defp layout_treemap_nodes(node, bounds, depth, _total_value) do
    # Base case: return current node if no children or area too small
    children = Map.get(node, :children, [])

    if Enum.empty?(children) or bounds.width < 1 or bounds.height < 1 do
      # Filter out nodes with zero area
      if bounds.width > 0 and bounds.height > 0 do
        [
          %{
            x: bounds.x,
            y: bounds.y,
            width: bounds.width,
            height: bounds.height,
            name: Map.get(node, :name, "Unknown"),
            value: Map.get(node, :value, 0),
            depth: depth
          }
        ]
      else
        []
      end
    else
      # --- Recursive Squarified-like Layout (Alternating Split) --- #
      # 1. Calculate total value of direct children & sort
      children_total_value =
        Enum.reduce(children, 0, fn child, acc ->
          acc + Map.get(child, :value, 0)
        end)

      sorted_children = Enum.sort_by(children, &Map.get(&1, :value, 0), :desc)

      # Avoid division by zero if total value is 0
      if children_total_value <= 0 do
        # Cannot partition based on value, just draw parent
        if bounds.width > 0 and bounds.height > 0 do
          [
            %{
              x: bounds.x,
              y: bounds.y,
              width: bounds.width,
              height: bounds.height,
              name: node.name <> " (No Child Values)",
              value: node.value,
              depth: depth
            }
          ]
        else
          []
        end
      else
        # 2. Determine split direction
        split_vertically = bounds.width >= bounds.height

        # 3. Iterate through children and layout recursively
        layout_children_recursive(
          sorted_children,
          children_total_value,
          bounds,
          depth + 1,
          split_vertically
        )
      end
    end
  end

  # Helper for recursive layout partitioning
  defp layout_children_recursive(
         children,
         remaining_value,
         current_bounds,
         depth,
         split_vertically
       ) do
    if Enum.empty?(children) or remaining_value <= 0 or current_bounds.width < 1 or
         current_bounds.height < 1 do
      []
    else
      child = hd(children)
      rest_children = tl(children)
      child_value = Map.get(child, :value, 0)

      # Skip children with zero value to avoid errors
      if child_value <= 0 do
        layout_children_recursive(
          rest_children,
          remaining_value,
          current_bounds,
          depth,
          split_vertically
        )
      else
        # Calculate proportion and dimension for this child
        proportion = child_value / remaining_value

        if split_vertically do
          # Split vertically: calculate width, height stays the same
          child_width = max(1, round(current_bounds.width * proportion))
          child_bounds = %{current_bounds | width: child_width}
          # Calculate remaining bounds for next children
          next_bounds = %{
            current_bounds
            | x: current_bounds.x + child_width,
              width: max(0, current_bounds.width - child_width)
          }

          # Recursively layout this child
          child_nodes =
            layout_treemap_nodes(child, child_bounds, depth, child_value)

          # Layout remaining children in the adjusted bounds
          child_nodes ++
            layout_children_recursive(
              rest_children,
              remaining_value - child_value,
              next_bounds,
              depth,
              split_vertically
            )
        else
          # Split horizontally: calculate height, width stays the same
          child_height = max(1, round(current_bounds.height * proportion))
          child_bounds = %{current_bounds | height: child_height}
          # Calculate remaining bounds for next children
          next_bounds = %{
            current_bounds
            | y: current_bounds.y + child_height,
              height: max(0, current_bounds.height - child_height)
          }

          # Recursively layout this child
          child_nodes =
            layout_treemap_nodes(child, child_bounds, depth, child_value)

          # Layout remaining children in the adjusted bounds
          child_nodes ++
            layout_children_recursive(
              rest_children,
              remaining_value - child_value,
              next_bounds,
              depth,
              split_vertically
            )
        end
      end
    end
  end

  # End of layout_children_recursive

  # --- Manual TUI Rendering Functions ---

  # Simplified: Takes data list directly, no Contex.BarChart struct
  defp draw_tui_bar_chart(data, title, bounds) do
    # Expect data like: [%{label: \"Jan\", value: 12}, ...]
    # Or handle tuple list: [{"Jan", 12}, ...]
    # Let's standardize on the map format for clarity.

    data =
      Enum.map(data, fn
        # Keep map format
        %{label: l, value: v} -> %{label: l, value: v}
        # Convert tuples
        {l, v} when is_binary(l) and is_number(v) -> %{label: l, value: v}
        # Ignore invalid entries
        _ -> nil
      end)
      |> Enum.reject(&is_nil(&1))

    if Enum.empty?(data) do
      Logger.warning("[VisualizationPlugin] No valid data for bar chart")
      draw_box_with_text("[No Data]", bounds)
    else
      # Extract values and labels
      labels = Enum.map(data, &Map.get(&1, :label, "?"))
      values = Enum.map(data, &Map.get(&1, :value, 0))
      max_value = Enum.max(values, fn -> 0 end)
      # Account for borders/padding
      chart_width = bounds.width - 2
      # Inner height for bars, leave space for title and labels
      chart_height = bounds.height - 4
      bar_width = max(1, div(chart_width, Enum.count(data)))

      bar_spacing =
        max(
          0,
          div(
            chart_width - Enum.count(data) * bar_width,
            max(1, Enum.count(data) - 1)
          )
        )

      if chart_width < Enum.count(data) or chart_height < 1 do
        Logger.warning(
          "[VisualizationPlugin] Chart area too small: #{chart_width}x#{chart_height}"
        )

        draw_box_with_text("[Too Small]", bounds)
      else
        # Define fractional block characters for height
        # 8 levels + space
        fractional_blocks = ~c" \"▂▃▄▅▆▇█"
        # = 8
        num_fractions = length(fractional_blocks) - 1

        # Color palette for bars
        # e.g., Red, Green, Yellow, Blue, Magenta, Cyan
        color_palette = [2, 3, 4, 5, 6, 1]
        num_colors = Enum.count(color_palette)

        # Draw the outer box (frame) first
        # Draw box with title
        box_cells = draw_box_with_text(title, bounds)

        # Draw bars inside the box
        bar_cells =
          Enum.with_index(data)
          |> Enum.flat_map(fn {item, index} ->
            value = Map.get(item, :value, 0)
            label = Map.get(item, :label, "")

            bar_x_start = bounds.x + 1 + index * (bar_width + bar_spacing)
            # Calculate bar height in fractional steps
            fractional_height =
              if max_value == 0,
                do: 0,
                else: value / max_value * chart_height * num_fractions

            full_blocks = floor(fractional_height / num_fractions)
            remainder_fraction = round(rem(fractional_height, num_fractions))
            fraction_char = Enum.at(fractional_blocks, remainder_fraction)

            fg_color = Enum.at(color_palette, rem(index, num_colors))

            # Generate bar cells
            bar_cells =
              for y_offset <- 0..(chart_height - 1),
                  x_offset <- 0..(bar_width - 1),
                  # Y grows downwards
                  current_y = bounds.y + 1 + chart_height - 1 - y_offset,
                  current_x = bar_x_start + x_offset do
                char =
                  cond do
                    y_offset < full_blocks -> ~c"█"
                    y_offset == full_blocks -> fraction_char
                    # Empty space above bar
                    true -> ~c" "
                  end

                # Return tuple format only if char is not space
                if char != ~c" " do
                  {current_x, current_y,
                   %{char: char, fg: fg_color, bg: 0, style: %{}}}
                else
                  # Will be filtered out
                  nil
                end
              end
              |> Enum.reject(&is_nil(&1))

            # Add label below bar
            # Position at bottom of chart area
            label_y = bounds.y + bounds.height - 2

            label_cells =
              if String.length(label || "") > 0 do
                # Truncate label if needed
                display_label =
                  if String.length(label) > bar_width do
                    String.slice(label, 0, bar_width - 1) <> "…"
                  else
                    label
                  end

                # Center the label under the bar
                label_x_offset =
                  div(bar_width - String.length(display_label), 2)

                String.graphemes(display_label)
                |> Enum.with_index()
                |> Enum.map(fn {char, char_index} ->
                  x = bar_x_start + label_x_offset + char_index

                  {x, label_y,
                   %{
                     char: String.to_charlist(char) |> hd(),
                     fg: 7,
                     bg: 0,
                     style: %{}
                   }}
                end)
              else
                []
              end

            # Add value above bar (if space allows)
            value_str = Integer.to_string(round(value))
            value_y = bounds.y + 1 + chart_height - 1 - full_blocks - 1

            value_cells =
              if full_blocks > 1 and String.length(value_str) <= bar_width do
                # Center the value above the bar
                value_x_offset = div(bar_width - String.length(value_str), 2)

                String.graphemes(value_str)
                |> Enum.with_index()
                |> Enum.map(fn {char, char_index} ->
                  x = bar_x_start + value_x_offset + char_index

                  {x, value_y,
                   %{
                     char: String.to_charlist(char) |> hd(),
                     fg: 7,
                     bg: 0,
                     style: %{}
                   }}
                end)
              else
                []
              end

            # Combine all cell types
            bar_cells ++ label_cells ++ value_cells
          end)

        # Add axis line at bottom (optional)
        axis_y = bounds.y + bounds.height - 3

        axis_cells =
          for x <- (bounds.x + 1)..(bounds.x + bounds.width - 2) do
            {x, axis_y, %{char: ?─, fg: 7, bg: 0, style: %{}}}
          end

        # Combine all cells, prioritizing content over box
        all_cells = box_cells ++ bar_cells ++ axis_cells

        # Use Map to ensure cells at same position don't duplicate
        cell_map =
          Map.new(all_cells, fn {x, y, cell} -> {{x, y}, {x, y, cell}} end)

        Map.values(cell_map)
      end
    end
  end

  # Placeholder for image rendering
  defp render_image_content(_data, _opts, bounds) do
    Logger.debug(
      "[VisualizationPlugin] Rendering placeholder for image at #{inspect(bounds)}"
    )

    # Use the existing box drawing helper
    # Use a different color (e.g., magenta)
    draw_box_with_text("[Image: #{bounds.width}x#{bounds.height}]", bounds,
      fg: 5
    )
  end

  # Other callbacks (can be minimal for now)
  @impl true
  def handle_input(state, _input), do: {:ok, state}
  @impl true
  # Pass output through - Corrected return type
  def handle_output(state, _output), do: {:ok, state}
  @impl true
  # Corrected return type
  def handle_mouse(state, _event, _rendered_cells), do: {:ok, state}
  @impl true
  def handle_resize(state, _w, _h), do: {:ok, state}
  @impl true
  # Corrected return type
  def cleanup(_state), do: :ok
  @impl true
  def get_api_version, do: "1.0.0"
  @impl true
  def get_dependencies, do: []

  # Add a function to handle state updates asynchronously
  def handle_cast({:update_state, new_state}, _state) do
    {:noreply, new_state}
  end

  # Add a function to clean up the cache periodically
  defp schedule_cache_cleanup do
    # Clean up every 10 minutes
    cleanup_ref = Process.send_after(self(), :cleanup_cache, :timer.minutes(10))
    cleanup_ref
  end

  def handle_info(:cleanup_cache, state) do
    # Clean up old cache entries
    new_cleanup_ref = schedule_cache_cleanup()

    Logger.debug(
      "[VisualizationPlugin] Cleaning visualization cache. Size before: #{map_size(state.layout_cache)}"
    )

    # Reset cache
    {:noreply, %{state | layout_cache: %{}, cleanup_ref: new_cleanup_ref}}
  end
end
