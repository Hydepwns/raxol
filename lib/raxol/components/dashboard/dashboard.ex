defmodule Raxol.Components.Dashboard.Dashboard do
  @moduledoc """
  A component responsible for rendering a grid-based dashboard layout.
  Manages widget placement, drag/drop, and resizing.
  """
  alias Raxol.Components.Dashboard.GridContainer
  import Raxol.View # Import View DSL for box, text etc.
  require Logger
  alias Raxol.Components.Dashboard.WidgetContainer
  # Add aliases for the new widget components
  alias Raxol.Components.Dashboard.Widgets.InfoWidget
  alias Raxol.Components.Dashboard.Widgets.TextInputWidget
  alias Raxol.Components.Dashboard.Widgets.ChartWidget
  alias Raxol.Components.Dashboard.Widgets.TreeMapWidget

  # --- Model ---
  defmodule Model do
    @moduledoc """
    State for the Dashboard component.
    """
    defstruct widgets: [],       # List of widget configurations (%{id: _, type: _, title: _, grid_spec: %{}})
              grid_config: %{}, # Grid config (%{parent_bounds: _, cols: _, rows: _, gap: _})
              dragging: nil,    # State for active drag operation
              resizing: nil     # State for active resize operation
              # Add other necessary state fields (e.g., focus)
  end

  # --- Public API (Example - might change based on component behaviour) ---

  @doc """
  Initializes the Dashboard state. Requires grid configuration.
  """
  def init(widgets, grid_config) when is_list(widgets) and is_map(grid_config) do
    {:ok, %Model{widgets: widgets, grid_config: grid_config}}
  end

  @layout_file Path.expand("~/.raxol/dashboard_layout.bin") # User-specific config dir

  @doc """
  Saves the current widget layout (list of widget configs) to a file.
  """
  def save_layout(widgets) when is_list(widgets) do
    layout_file = @layout_file
    try do
      # Ensure directory exists
      :ok = File.mkdir_p(Path.dirname(layout_file))
      # Save the relevant parts: id, type, title, grid_spec, and component_opts
      layout_data =
        Enum.map(widgets, fn w ->
          Map.take(w, [:id, :type, :title, :grid_spec, :component_opts])
        end)
      # Serialize the layout data
      binary_data = :erlang.term_to_binary(layout_data)
      # Write to file
      File.write(layout_file, binary_data)
      Logger.info("Dashboard layout saved to #{layout_file}")
      :ok
    rescue
      e ->
        Logger.error("Failed to save dashboard layout to #{layout_file}: #{inspect(e)}")
        {:error, e}
    end
  end

  @doc """
  Loads the widget layout from the file.
  Returns the list of widget configurations or an empty list if load fails.
  """
  def load_layout do
    layout_file = @layout_file
    if File.exists?(layout_file) do
      try do
        case File.read(layout_file) do
          {:ok, binary_data} ->
            layout_data = :erlang.binary_to_term(binary_data)
            # Basic validation: check if it's a list
            if is_list(layout_data) do
              Logger.info("Dashboard layout loaded from #{layout_file}")
              layout_data
            else
              Logger.warning("Invalid layout data format in #{layout_file}, using default.")
              [] # Return empty list on invalid format
            end
          {:error, reason} ->
            Logger.error("Failed to read layout file #{layout_file}: #{reason}")
            [] # Return empty list on read error
        end
      rescue
        e ->
          Logger.error("Failed to deserialize layout data from #{layout_file}: #{inspect(e)}")
          [] # Return empty list on deserialization error
      end
    else
      Logger.info("Layout file #{layout_file} not found, using default layout.")
      [] # Return empty list if file doesn't exist
    end
  end

  @doc """
  Renders the dashboard based on the current state.
  Requires props map: %{dashboard_model: %Model{}, app_text: String.t()}
  """
  def render(props) do
    %{
      dashboard_model: %Model{} = model,
      app_text: app_text # Extract app state needed by widgets
    } = props

    # Build a list of Raxol.View elements for each widget
    widget_views =
      Enum.map(model.widgets, fn widget_config ->
        # Calculate bounds using GridContainer
        bounds = GridContainer.calculate_widget_bounds(widget_config, model.grid_config)

        # Generate the widget content. This is either a View structure (for standard widgets)
        # or a data structure (for chart/treemap).
        widget_content =
          case widget_config.type do
            :info ->
              InfoWidget.render(%{widget_config: widget_config})
            :text_input ->
              TextInputWidget.render(%{widget_config: widget_config, app_text: app_text})
            :chart ->
              # Initialize the widget state and get the render data structure
              # Note: We init here just to get the structure; state isn't persisted across renders this way.
              # A more robust approach might involve storing initialized widget states.
              widget_state = ChartWidget.init(%{widget_config: widget_config})
              ChartWidget.render_data_structure(widget_state)
            :treemap ->
              # Initialize the widget state and get the render data structure
              widget_state = TreeMapWidget.init(%{widget_config: widget_config})
              TreeMapWidget.render_data_structure(widget_state)
            _ ->
              # Placeholder for unknown widget types
              text("Unknown Widget Type: #{widget_config.type}")
          end

        # Render the container, passing bounds, config, and content
        WidgetContainer.render(%{
          bounds: bounds,
          widget_config: widget_config,
          content: widget_content
        })
      end)

    # Return the list of View elements (which are now WidgetContainers)
    widget_views
  end

  @doc """
  Updates the dashboard state based on incoming events.
  Handles mouse events for drag/drop and resize.
  """
  def update(event, %Model{} = model) do
    grid_config = model.grid_config # Use grid_config from the dashboard model

    case event do
      # --- Mouse Event Handling (Moved from MyApp) ---
      %{type: :mouse, event_type: :mouse_down, x: x, y: y} ->
        case find_widget_and_bounds_at(x, y, model.widgets, grid_config) do
          {widget, bounds} ->
            if is_in_resize_handle?(x, y, bounds) do
              Logger.debug("[Dashboard] Mouse Down on resize handle for widget #{widget.id} at (#{x}, #{y})")
              resizing_state = %{
                widget_id: widget.id,
                start_mouse: %{x: x, y: y},
                start_spec: widget.grid_spec
              }
              %{model | resizing: resizing_state, dragging: nil}
            else
              Logger.debug("[Dashboard] Mouse Down on widget #{widget.id} at (#{x}, #{y}) - Starting Drag")
              offset = %{x: x - bounds.x, y: y - bounds.y}
              dragging_state = %{
                widget_id: widget.id,
                start_mouse: %{x: x, y: y},
                start_spec: widget.grid_spec,
                offset: offset
              }
              %{model | dragging: dragging_state, resizing: nil}
            end
          nil -> model # Clicked outside any widget
        end

      %{type: :mouse, event_type: :mouse_drag, x: x, y: y} ->
        cond do
          model.resizing ->
            %{widget_id: widget_id, start_spec: start_spec} = model.resizing
            {target_col, target_row} = coords_to_grid_cell(x, y, grid_config)
            new_col_span = max(1, target_col - start_spec.col + 1)
            new_row_span = max(1, target_row - start_spec.row + 1)
            new_spec = %{start_spec | col_span: new_col_span, row_span: new_row_span}
            current_widget = Enum.find(model.widgets, &(&1.id == widget_id))
            if new_spec != current_widget.grid_spec do
              Logger.debug("[Dashboard] Resizing widget #{widget_id} to span=(#{new_col_span}, #{new_row_span})")
              new_widgets = Enum.map(model.widgets, fn w ->
                if w.id == widget_id, do: %{w | grid_spec: new_spec}, else: w
              end)
              %{model | widgets: new_widgets}
            else
              model # No change in grid spec
            end

          model.dragging ->
            %{widget_id: widget_id, start_spec: start_spec, offset: offset} = model.dragging
            target_x = x - offset.x
            target_y = y - offset.y
            {new_col, new_row} = coords_to_grid_cell(target_x, target_y, grid_config)
            new_spec = %{start_spec | col: new_col, row: new_row}
            current_widget = Enum.find(model.widgets, &(&1.id == widget_id))
            if new_spec != current_widget.grid_spec do
              Logger.debug("[Dashboard] Dragging widget #{widget_id} to col=#{new_col}, row=#{new_row}")
              new_widgets = Enum.map(model.widgets, fn w ->
                if w.id == widget_id, do: %{w | grid_spec: new_spec}, else: w
              end)
              %{model | widgets: new_widgets}
            else
              model # No change in grid position
            end

          true -> model # Not dragging or resizing
        end

      %{type: :mouse, event_type: :mouse_up, x: x, y: y} ->
        cond do
          model.resizing ->
            Logger.debug("[Dashboard] Mouse Up, ending resize for widget #{model.resizing.widget_id} at (#{x}, #{y})")
            # Save layout after resize
            new_model = %{model | resizing: nil}
            save_layout(new_model.widgets)
            new_model
          model.dragging ->
            Logger.debug("[Dashboard] Mouse Up, ending drag for widget #{model.dragging.widget_id} at (#{x}, #{y})")
            # Save layout after drag
            new_model = %{model | dragging: nil}
            save_layout(new_model.widgets)
            new_model
          true -> model # No drag/resize was active
        end

      # Ignore other event types for now
      _ -> model
    end
  end

  # --- Internal Helpers ---

  # Remove the placeholder render_widget_content function
  # defp render_widget_content(widget_config) do ... end

  # --- Helper Functions (Moved from MyApp) ---

  defp find_widget_and_bounds_at(x, y, widgets, grid_config) do
    Enum.find_value(widgets, fn widget ->
      bounds = GridContainer.calculate_widget_bounds(widget, grid_config)
      if x >= bounds.x && x < bounds.x + bounds.width &&
         y >= bounds.y && y < bounds.y + bounds.height do
        {widget, bounds}
      else
        nil
      end
    end)
  end

  defp is_in_resize_handle?(_x, _y, bounds) when bounds.width < 1 or bounds.height < 1 do
    false
  end
  defp is_in_resize_handle?(x, y, bounds) do
    handle_x = bounds.x + bounds.width - 1
    handle_y = bounds.y + bounds.height - 1
    x == handle_x && y == handle_y
  end

  defp coords_to_grid_cell(x, y, grid_config) do
    parent_bounds = grid_config.parent_bounds
    # Resolve effective cols/rows based on current width
    %{cols: cols, rows: rows} = GridContainer.resolve_grid_params(grid_config)
    gap = grid_config[:gap] || GridContainer.default_gap()

    container_width = parent_bounds.width
    container_height = parent_bounds.height

    total_horizontal_gap = max(0, cols - 1) * gap
    total_vertical_gap = max(0, rows - 1) * gap

    available_width = max(0, container_width - total_horizontal_gap)
    available_height = max(0, container_height - total_vertical_gap)

    cell_width = if cols > 0, do: div(available_width, cols), else: 1
    cell_height = if rows > 0, do: div(available_height, rows), else: 1

    approx_col = if cell_width > 0, do: div(max(0, x - parent_bounds.x), cell_width + gap) + 1, else: 1
    approx_row = if cell_height > 0, do: div(max(0, y - parent_bounds.y), cell_height + gap) + 1, else: 1

    final_col = max(1, min(approx_col, cols))
    final_row = max(1, min(approx_row, rows))

    {final_col, final_row}
  end

end
