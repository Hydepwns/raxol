defmodule Raxol.Components.Dashboard.GridContainer do
  @moduledoc """
  Calculates layout bounds for widgets within a grid configuration.
  This module provides functions to determine the position and size of widgets
  based on a grid layout definition (columns, rows, gaps).
  """

  require Logger

  # Default grid dimensions and gap
  @default_cols 12
  @default_rows 12
  @default_gap 1

  def default_cols, do: @default_cols
  def default_rows, do: @default_rows
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
  def resolve_grid_params(grid_config) do
    parent_width = grid_config.parent_bounds.width
    breakpoints = grid_config[:breakpoints] || %{}

    # Find the first matching breakpoint based on max_width, ordered smallest to largest
    # Assume breakpoint keys imply order, or explicitly sort if needed.
    # A common pattern is :small, :medium, :large
    # Consider sorting if order isn't guaranteed
    breakpoint_keys = Map.keys(breakpoints)

    effective_params =
      Enum.find_value(breakpoint_keys, fn key ->
        breakpoint_data = breakpoints[key]
        max_width = breakpoint_data[:max_width]

        if !is_nil(max_width) and parent_width <= max_width do
          # Found a matching breakpoint with max_width
          %{
            cols: breakpoint_data[:cols] || @default_cols,
            rows: breakpoint_data[:rows] || @default_rows
          }
        else
          # Continue searching
          nil
        end
      end)

    # If no max_width breakpoint matched, use the last/default one (e.g., :large)
    # or fall back to module defaults if no breakpoints defined at all.
    # Assuming :large is the default/fallback key
    effective_params ||
      case Map.get(breakpoints, :large) do
        nil ->
          %{cols: @default_cols, rows: @default_rows}

        large_bp ->
          %{
            cols: large_bp[:cols] || @default_cols,
            rows: large_bp[:rows] || @default_rows
          }
      end
  end

  @doc """
  Calculates the absolute bounds for a single widget based on its grid spec
  and the overall grid configuration.

  Parameters:
    - `widget_config`: Map containing at least `grid_spec: %{col: integer(), row: integer(), col_span: integer(), row_span: integer()}`.
    - `grid_config`: Map containing `parent_bounds: %{x: integer(), y: integer(), width: integer(), height: integer()}`,
      and optionally `cols: integer()`, `rows: integer()`, `gap: integer()`.

  Returns:
    - `%{x: integer(), y: integer(), width: integer(), height: integer()}` representing the absolute bounds.
  """
  def calculate_widget_bounds(widget_config, grid_config) do
    # --- Log the grid_config RECEIVED --- >
    Logger.debug(
      "[GridContainer.calculate_widget_bounds] Received: widget_id=#{Map.get(widget_config, :id, :unknown)}, grid_config=#{inspect(grid_config)}"
    )
    # --- End Log ---

    # Extract grid parameters with defaults
    parent_bounds = grid_config.parent_bounds
    # Resolve cols/rows based on breakpoints and parent width
    %{cols: cols, rows: rows} = resolve_grid_params(grid_config)
    gap = grid_config[:gap] || @default_gap

    container_width = parent_bounds.width
    container_height = parent_bounds.height

    # --- Calculation logic (moved from previous implementation) ---
    # Calculate total gap space
    total_horizontal_gap = max(0, cols - 1) * gap
    total_vertical_gap = max(0, rows - 1) * gap

    # Calculate available space for cells
    available_width = max(0, container_width - total_horizontal_gap)
    available_height = max(0, container_height - total_vertical_gap)

    # Calculate base cell dimensions (use floating-point division and round)
    cell_width =
      if cols > 0, do: round(available_width / cols), else: available_width

    cell_height =
      if rows > 0, do: round(available_height / rows), else: available_height

    # --- Added Debug Logging ---
    Logger.debug("""
    [GridContainer.calculate_widget_bounds] Debug Values:
      Widget ID: #{widget_config.id}
      Grid Spec: #{inspect(widget_config.grid_spec)}
      Cols: #{cols}, Rows: #{rows}, Gap: #{gap}
      Container WxH: #{container_width}x#{container_height}
      Total Gap HxV: #{total_horizontal_gap}x#{total_vertical_gap}
      Available WxH: #{available_width}x#{available_height}
      Cell WxH: #{cell_width}x#{cell_height}
    """)
    # --- End Debug Logging ---

    # Extract widget grid spec with defaults
    grid_spec =
      widget_config.grid_spec || %{col: 1, row: 1, col_span: 1, row_span: 1}

    # Calculate position and size including gaps
    col_start = max(1, grid_spec.col)
    row_start = max(1, grid_spec.row)
    col_span = max(1, grid_spec.col_span)
    row_span = max(1, grid_spec.row_span)

    x_pos =
      parent_bounds.x + (col_start - 1) * cell_width + (col_start - 1) * gap

    y_pos =
      parent_bounds.y + (row_start - 1) * cell_height + (row_start - 1) * gap

    width = col_span * cell_width + (col_span - 1) * gap
    height = row_span * cell_height + (row_span - 1) * gap

    # Clamp size to container bounds just in case
    final_width = max(0, min(width, parent_bounds.x + container_width - x_pos))

    final_height =
      max(0, min(height, parent_bounds.y + container_height - y_pos))

    # --- End of calculation logic ---

    %{x: x_pos, y: y_pos, width: final_width, height: final_height}
  end
end
