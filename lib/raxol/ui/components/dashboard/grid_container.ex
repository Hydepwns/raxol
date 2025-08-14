defmodule Raxol.UI.Components.Dashboard.GridContainer do
  @moduledoc """
  Calculates layout bounds for widgets within a grid configuration.
  This module provides functions to determine the position and size of widgets
  based on a grid layout definition (columns, rows, gaps).
  """

  require Raxol.Core.Runtime.Log
  
  # Default grid dimensions and gap
  @default_cols 12
  @default_rows 12
  @default_gap 1

  @spec default_cols() :: integer()
  def default_cols, do: @default_cols

  @spec default_rows() :: integer()
  def default_rows, do: @default_rows

  @spec default_gap() :: integer()
  def default_gap, do: @default_gap

  @doc """
  Resolves the effective grid parameters (cols, rows) based on breakpoints
  defined in the grid configuration and the current parent width.

  Parameters:
    - `grid_config`: Map containing `parent_bounds: %{width: _}` and `breakpoints: %{...}`.
                   Breakpoints map should have keys like `:small`, `:medium`, `:large`,
                   with values like `%{max_width: _, cols: _, rows: _}` or just `%{cols: _, rows: _}`
                   for the largest/default breakpoint.

  Returns:
    - `%{cols: integer(), rows: integer()}`
  """
  # Handle when an :ok atom is passed
  def resolve_grid_params(:ok) do
    Raxol.Core.Runtime.Log.warning(
      "resolve_grid_params received :ok atom instead of grid_config map"
    )

    %{cols: @default_cols, rows: @default_rows}
  end

  # Handle other non-map inputs
  def resolve_grid_params(invalid_input) when not is_map(invalid_input) do
    Raxol.Core.Runtime.Log.warning(
      "Invalid input to resolve_grid_params: #{inspect(invalid_input)}"
    )

    %{cols: @default_cols, rows: @default_rows}
  end

  # Original function
  def resolve_grid_params(grid_config) do
    # Extract defined cols and rows (or use defaults)
    cols = grid_config[:cols] || @default_cols
    rows = grid_config[:rows] || @default_rows

    # If we have breakpoints defined, try to find the most appropriate one
    # based on the current parent width
    if is_map(grid_config[:breakpoints]) and is_map(grid_config[:parent_bounds]) do
      current_width = grid_config.parent_bounds.width
      breakpoints = grid_config.breakpoints

      # Extract breakpoint values as list of {max_width, cols, rows} tuples,
      # with max_width set to :infinity for any breakpoint missing max_width
      breakpoint_values =
        breakpoints
        |> Enum.map(fn {_key, value} -> value end)
        |> Enum.map(fn bpconfig ->
          {Map.get(bpconfig, :max_width, :infinity),
           Map.get(bpconfig, :cols, cols), Map.get(bpconfig, :rows, rows)}
        end)
        # Sort by max_width (putting :infinity last)
        |> Enum.sort_by(&sort_by_max_width/1)

      # Find the first breakpoint where width <= max_width or the last one if none match
      Enum.reduce_while(
        breakpoint_values,
        %{cols: cols, rows: rows},
        fn {max_width, bp_cols, bp_rows}, acc ->
          check_breakpoint_match(max_width, current_width, bp_cols, bp_rows, acc)
        end
      )
    else
      # No breakpoints, return default
      %{cols: cols, rows: rows}
    end
  end

  @spec calculate_widget_bounds(map(), any()) :: %{
          x: integer(),
          y: integer(),
          width: integer(),
          height: integer()
        }
  @doc """
  Calculates the absolute bounds for a widget within a grid layout.

  Parameters:
    - `widget_config`: Map containing at least `grid_spec: %{col: integer(), row: integer(), col_span: integer(), row_span: integer()}`.
    - `grid_config`: Map containing `parent_bounds: %{x: integer(), y: integer(), width: integer(), height: integer()}`,
      and optionally `cols: integer()`, `rows: integer()`, `gap: integer()`.

  Returns:
    - `%{x: integer(), y: integer(), width: integer(), height: integer()}` representing the absolute bounds.
  """
  # Handle cases where grid_config is :ok or not a map
  def calculate_widget_bounds(_widget_config, :ok) do
    Raxol.Core.Runtime.Log.error(
      "calculate_widget_bounds received :ok atom instead of grid_config map"
    )

    # Return a safe default bounds
    %{x: 0, y: 0, width: 10, height: 10}
  end

  def calculate_widget_bounds(_widget_config, invalid_grid_config)
      when not is_map(invalid_grid_config) do
    Raxol.Core.Runtime.Log.error(
      "Invalid grid_config in calculate_widget_bounds: #{inspect(invalid_grid_config)}"
    )

    # Return a safe default bounds
    %{x: 0, y: 0, width: 10, height: 10}
  end

  # Handle maps without parent_bounds
  def calculate_widget_bounds(
        _widget_config,
        %{parent_bounds: nil} = grid_config
      ) do
    Raxol.Core.Runtime.Log.warning(
      "calculate_widget_bounds received grid_config with nil parent_bounds: #{inspect(grid_config)}"
    )

    %{x: 0, y: 0, width: 10, height: 10}
  end

  # Original function with guard - should come first
  def calculate_widget_bounds(
        widget_config,
        %{parent_bounds: parent_bounds} = grid_config
      )
      when is_map(parent_bounds) do
    # --- Log the grid_config RECEIVED --- >
    Raxol.Core.Runtime.Log.debug(
      "[GridContainer.calculate_widget_bounds] Received: widget_id=#{Map.get(widget_config, :id, :unknown)}, grid_config=#{inspect(grid_config)}"
    )

    # --- End Log ---

    # Extract grid parameters with defaults
    # Resolve cols/rows based on breakpoints and parent width
    %{cols: cols, rows: rows} = resolve_grid_params(grid_config)
    gap = grid_config[:gap] || @default_gap

    # Check if width or height are invalid (non-numeric values like :ok)
    if not is_number(parent_bounds[:width]) or
         not is_number(parent_bounds[:height]) do
      Raxol.Core.Runtime.Log.error(
        "Invalid parent_bounds values in calculate_widget_bounds: parent_bounds=#{inspect(parent_bounds)}, container_width=#{inspect(parent_bounds[:width])}, container_height=#{inspect(parent_bounds[:height])}"
      )

      %{x: 0, y: 0, width: 10, height: 10}
    else
      container_width = parent_bounds.width
      container_height = parent_bounds.height

      # Calculate cell dimensions using the helper function
      {cell_width, cell_height} = get_cell_dimensions(grid_config)

      # --- Added Debug Logging ---
      Raxol.Core.Runtime.Log.debug("""
      [GridContainer.calculate_widget_bounds] Debug Values:
        Widget ID: #{widget_config.id}
        Grid Spec: #{inspect(widget_config.grid_spec)}
        Cols: #{cols}, Rows: #{rows}, Gap: #{gap}
        Container WxH: #{container_width}x#{container_height}
        Cell WxH: #{cell_width}x#{cell_height}
      """)

      # --- End Debug Logging ---

      # Validate parent_bounds values
      if !(is_map(parent_bounds) and
             is_number(Map.get(parent_bounds, :x)) and
             is_number(Map.get(parent_bounds, :y)) and
             is_number(container_width) and
             is_number(container_height)) do
        Raxol.Core.Runtime.Log.error(
          "Invalid parent_bounds values in calculate_widget_bounds: parent_bounds=#{inspect(parent_bounds)}, container_width=#{inspect(container_width)}, container_height=#{inspect(container_height)}"
        )

        %{x: 0, y: 0, width: 10, height: 10}
      else
        # Extract widget grid spec with defaults
        grid_spec =
          widget_config.grid_spec || %{col: 1, row: 1, width: 1, height: 1}

        # Calculate position and size including gaps
        col_start = max(1, grid_spec.col)
        row_start = max(1, grid_spec.row)

        # Handle both width/height and col_span/row_span naming conventions
        width_cells = get_width_cells(grid_spec)

        height_cells = get_height_cells(grid_spec)

        # Validate cell dimensions
        if !(is_number(cell_width) and is_number(cell_height)) do
          Raxol.Core.Runtime.Log.error(
            "Invalid cell dimensions in calculate_widget_bounds: width=#{inspect(cell_width)}, height=#{inspect(cell_height)}"
          )

          %{x: 0, y: 0, width: 10, height: 10}
        else
          x_pos =
            parent_bounds.x + (col_start - 1) * cell_width +
              (col_start - 1) * gap

          y_pos =
            parent_bounds.y + (row_start - 1) * cell_height +
              (row_start - 1) * gap

          width = width_cells * cell_width + (width_cells - 1) * gap
          height = height_cells * cell_height + (height_cells - 1) * gap

          # Return the final bounds with calculated dimensions
          %{
            x: x_pos,
            y: y_pos,
            width: width,
            height: height
          }
        end
      end
    end
  end
  
  # Catch-all clause for maps without parent_bounds
  def calculate_widget_bounds(_widget_config, %{} = grid_config) do
    Raxol.Core.Runtime.Log.warning(
      "calculate_widget_bounds received grid_config without parent_bounds: #{inspect(grid_config)}"
    )
    
    %{x: 0, y: 0, width: 10, height: 10}
  end

  @spec get_cell_dimensions(any()) :: {integer(), integer()}
  @doc """
  Calculates the dimensions of a single cell in the grid.

  Parameters:
    - `grid_config`: Map containing grid configuration including parent_bounds,
      cols, rows, and gap.

  Returns:
    - `{cell_width, cell_height}` tuple with the dimensions of a single cell.
  """
  # Handle when an :ok atom is passed (which causes the ArithmeticError)
  def get_cell_dimensions(:ok) do
    Raxol.Core.Runtime.Log.error(
      "get_cell_dimensions received :ok atom instead of grid_config map"
    )

    # Return sensible defaults
    {10, 10}
  end

  # Handle other non-map inputs
  def get_cell_dimensions(invalid_input) when not is_map(invalid_input) do
    Raxol.Core.Runtime.Log.error(
      "Invalid input to get_cell_dimensions: #{inspect(invalid_input)}"
    )

    # Return sensible defaults
    {10, 10}
  end

  # Handle maps without parent_bounds
  def get_cell_dimensions(%{parent_bounds: nil} = grid_config) do
    Raxol.Core.Runtime.Log.warning(
      "get_cell_dimensions received grid_config with nil parent_bounds: #{inspect(grid_config)}"
    )

    # Return sensible defaults
    {10, 10}
  end

  # Original function with guard to ensure parent_bounds exists and is a map
  def get_cell_dimensions(%{parent_bounds: parent_bounds} = grid_config)
      when is_map(parent_bounds) do
    # Extract grid parameters with defaults
    # Resolve cols/rows based on breakpoints and parent width
    %{cols: cols, rows: rows} = resolve_grid_params(grid_config)
    gap = grid_config[:gap] || @default_gap

    # Check for required width/height fields in parent_bounds
    with true <-
           Map.has_key?(parent_bounds, :width) and
             Map.has_key?(parent_bounds, :height),
         true <-
           is_number(parent_bounds.width) and is_number(parent_bounds.height) do
      container_width = parent_bounds.width
      container_height = parent_bounds.height

      # Calculate total gap space
      total_horizontal_gap = max(0, cols - 1) * gap
      total_vertical_gap = max(0, rows - 1) * gap

      # Calculate available space for cells
      available_width = max(0, container_width - total_horizontal_gap)
      available_height = max(0, container_height - total_vertical_gap)

      # Calculate base cell dimensions (use floating-point division and round)
      cell_width = calculate_cell_width(cols, available_width)
      cell_height = calculate_cell_height(rows, available_height)

      {cell_width, cell_height}
    else
      _ ->
        Raxol.Core.Runtime.Log.warning(
          "Invalid parent_bounds structure in get_cell_dimensions: #{inspect(parent_bounds)}"
        )

        # Return sensible defaults
        {10, 10}
    end
  end
  
  # Catch-all clause for maps without parent_bounds
  def get_cell_dimensions(%{} = grid_config) do
    Raxol.Core.Runtime.Log.warning(
      "get_cell_dimensions received grid_config without parent_bounds: #{inspect(grid_config)}"
    )
    
    # Return sensible defaults
    {10, 10}
  end

  defp get_width_cells(grid_spec) when is_map_key(grid_spec, :width) do
    max(1, grid_spec.width)
  end

  defp get_width_cells(grid_spec) when is_map_key(grid_spec, :col_span) do
    max(1, grid_spec.col_span)
  end

  defp get_width_cells(_grid_spec), do: 1

  defp get_height_cells(grid_spec) when is_map_key(grid_spec, :height) do
    max(1, grid_spec.height)
  end

  defp get_height_cells(grid_spec) when is_map_key(grid_spec, :row_span) do
    max(1, grid_spec.row_span)
  end

  defp get_height_cells(_grid_spec), do: 1

  # Helper functions for pattern matching refactoring

  defp sort_by_max_width({:infinity, _c, _r}), do: 1_000_000
  defp sort_by_max_width({max_width, _c, _r}), do: max_width

  defp check_breakpoint_match(:infinity, _current_width, bp_cols, bp_rows, _acc) do
    {:halt, %{cols: bp_cols, rows: bp_rows}}
  end

  defp check_breakpoint_match(max_width, current_width, bp_cols, bp_rows, acc) 
       when current_width <= max_width do
    {:halt, %{cols: bp_cols, rows: bp_rows}}
  end

  defp check_breakpoint_match(_max_width, _current_width, _bp_cols, _bp_rows, acc) do
    {:cont, acc}
  end

  defp calculate_cell_width(cols, available_width) when cols > 0 do
    round(available_width / cols)
  end

  defp calculate_cell_width(_cols, available_width), do: available_width

  defp calculate_cell_height(rows, available_height) when rows > 0 do
    round(available_height / rows)
  end

  defp calculate_cell_height(_rows, available_height), do: available_height
end
