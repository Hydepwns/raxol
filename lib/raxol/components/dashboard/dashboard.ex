defmodule Raxol.Components.Dashboard.Dashboard do
  @moduledoc """
  A component responsible for rendering a grid-based dashboard layout.
  Manages widget placement, drag/drop, and resizing.
  """
  alias Raxol.Components.Dashboard.GridContainer
  # Import View DSL for box, text etc.
  import Raxol.View
  require Logger
  alias Raxol.Components.Dashboard.WidgetContainer
  # Add aliases for the new widget components
  alias Raxol.Components.Dashboard.Widgets.InfoWidget
  alias Raxol.Components.Dashboard.Widgets.TextInputWidget

  # --- Model ---
  defmodule Model do
    @moduledoc """
    State for the Dashboard component.
    """
    # List of widget configurations (%{id: _, type: _, title: _, grid_spec: %{}})
    defstruct widgets: [],
              # Grid config (%{parent_bounds: _, cols: _, rows: _, gap: _})
              grid_config: %{},
              # State for active drag operation
              dragging: nil,
              # State for active resize operation
              resizing: nil

    # Add other necessary state fields (e.g., focus)
  end

  # --- Public API (Example - might change based on component behaviour) ---

  @doc """
  Initializes the Dashboard state. Requires grid configuration.
  """
  def init(widgets, grid_config)
      when is_list(widgets) and is_map(grid_config) do
    {:ok, %Model{widgets: widgets, grid_config: grid_config}}
  end

  # User-specific config dir
  @layout_file Path.expand("~/.raxol/dashboard_layout.bin")

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
          Map.take(w, [:id, :type, :title, :grid_spec, :component_opts, :data])
        end)

      # Serialize the layout data
      binary_data = :erlang.term_to_binary(layout_data)
      # Write to file
      File.write(layout_file, binary_data)
      Logger.info("Dashboard layout saved to #{layout_file}")
      :ok
    rescue
      e ->
        Logger.error(
          "Failed to save dashboard layout to #{layout_file}: #{inspect(e)}"
        )

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
        # Read binary data
        {:ok, binary_data} = File.read(layout_file)
        # Deserialize
        layout_data = :erlang.binary_to_term(binary_data)

        Logger.info("Dashboard layout loaded from #{layout_file}")
        layout_data
      rescue
        e ->
          Logger.error(
            "Failed to load dashboard layout from #{layout_file}: #{inspect(e)}"
          )

          []
      end
    else
      Logger.info("No saved dashboard layout found at #{layout_file}")
      []
    end
  end

  @doc """
  Initializes the Dashboard state from a saved layout.
  If no saved layout exists, returns default widgets with the given grid configuration.

  This function loads widget configurations using load_layout/0 and initializes
  the dashboard model with those widgets and the provided grid_config.

  Returns {:ok, model} on success, or {:error, reason} on failure.
  """
  def init_from_saved_layout(default_widgets, grid_config)
      when is_list(default_widgets) and is_map(grid_config) do
    # Try to load saved widgets from file
    loaded_widgets = load_layout()

    # If we have loaded widgets, use them - otherwise use defaults
    widgets =
      if loaded_widgets && length(loaded_widgets) > 0 do
        Logger.info("Initializing dashboard from saved layout with #{length(loaded_widgets)} widgets")
        loaded_widgets
      else
        Logger.info("No saved layout found, initializing dashboard with #{length(default_widgets)} default widgets")
        default_widgets
      end

    # Verify widgets are valid before initializing
    if validate_widgets(widgets) do
      {:ok, %Model{widgets: widgets, grid_config: grid_config}}
    else
      Logger.error("Invalid widget configurations in saved layout, using defaults")
      {:ok, %Model{widgets: default_widgets, grid_config: grid_config}}
    end
  end

  @doc """
  Validates a list of widget configurations to ensure they can be properly rendered.
  Returns true if widgets are valid, false otherwise.
  """
  def validate_widgets(widgets) when is_list(widgets) do
    # Check that all widgets have required fields
    Enum.all?(widgets, fn widget ->
      required_fields = [:id, :type, :title, :grid_spec]
      required_grid_fields = [:col, :row, :width, :height]

      has_required_fields = Enum.all?(required_fields, &Map.has_key?(widget, &1))
      has_grid_fields = widget[:grid_spec] && Enum.all?(required_grid_fields, &Map.has_key?(widget.grid_spec, &1))

      valid_type = widget[:type] in [:chart, :treemap, :info, :text_input, :image]

      has_required_fields && has_grid_fields && valid_type
    end)
  end

  # Default implementation for empty list
  def validate_widgets([]), do: true
  # Handle nil case
  def validate_widgets(nil), do: false

  @doc """
  Renders the dashboard based on the current state.
  Requires props map: %{dashboard_model: %Model{}, app_text: String.t()}
  """
  def render(props) do
    Logger.debug("[Dashboard.render] Starting render... Props received: #{inspect(props)}")
    %{
      dashboard_model: %Model{} = model,
      # Extract grid_config directly from props (passed by Runtime)
      grid_config: grid_config,
      # Extract app state needed by widgets
      app_text: app_text
    } = props

    # Build a list of Raxol.View elements for each widget
    widget_views =
      Enum.map(model.widgets, fn widget_config ->
        # --- Log the grid_config BEING PASSED --- >
        Logger.debug(
          "[Dashboard.render] Passing to GridContainer.calculate_widget_bounds: widget_id=#{widget_config.id}, grid_config=#{inspect(grid_config)}"
        )
        # --- End Log ---

        # Calculate bounds using GridContainer
        bounds =
          GridContainer.calculate_widget_bounds(
            widget_config,
            grid_config # Use grid_config from props
          )

        # Handle plugin widgets vs container widgets differently
        case widget_config.type do
          # Plugin widgets: Return the config map directly with bounds included
          :chart ->
            box widget_config: Map.put(widget_config, :bounds, bounds) do
              []
            end

          :treemap ->
            box widget_config: Map.put(widget_config, :bounds, bounds) do
              []
            end

          :image ->
            box widget_config: Map.put(widget_config, :bounds, bounds) do
              []
            end

          # Standard widgets: Render content and wrap in WidgetContainer
          :info ->
            widget_content = InfoWidget.render(%{widget_config: widget_config})
            WidgetContainer.render(%{
              bounds: bounds,
              widget_config: widget_config,
              content: widget_content
            })

          :text_input ->
            widget_content =
              TextInputWidget.render(%{
                widget_config: widget_config,
                app_text: app_text # Pass app_text needed by this widget
              })
            WidgetContainer.render(%{
              bounds: bounds,
              widget_config: widget_config,
              content: widget_content
            })

          # Fallback for unknown standard widget types (wrap in container with error)
          _ ->
            widget_content = text("Unknown Widget Type: #{widget_config.type}")
            WidgetContainer.render(%{
               bounds: bounds,
               widget_config: widget_config,
               content: widget_content
            })
        end
      end)

    # Return the list of View elements (mix of WidgetContainers and plugin maps)
    widget_views
  end

  @doc """
  Updates the dashboard state based on incoming events.
  Handles mouse events for drag/drop and resize.
  """
  def update(event, %Model{} = model) do
    # Use grid_config from the dashboard model
    grid_config = model.grid_config

    case event do
      # --- Mouse Event Handling (Moved from MyApp) ---
      %{type: :mouse, event_type: :mouse_down, x: x, y: y} ->
        case find_widget_and_bounds_at(x, y, model.widgets, grid_config) do
          {widget, bounds} ->
            if is_in_resize_handle?(x, y, bounds) do
              Logger.debug(
                "[Dashboard] Mouse Down on resize handle for widget #{widget.id} at (#{x}, #{y})"
              )

              resizing_state = %{
                widget_id: widget.id,
                start_mouse: %{x: x, y: y},
                start_spec: widget.grid_spec
              }

              %{model | resizing: resizing_state, dragging: nil}
            else
              Logger.debug(
                "[Dashboard] Mouse Down on widget #{widget.id} at (#{x}, #{y}) - Starting Drag"
              )

              offset = %{x: x - bounds.x, y: y - bounds.y}

              dragging_state = %{
                widget_id: widget.id,
                start_mouse: %{x: x, y: y},
                start_spec: widget.grid_spec,
                offset: offset
              }

              %{model | dragging: dragging_state, resizing: nil}
            end

          # Clicked outside any widget
          nil ->
            model
        end

      %{type: :mouse, event_type: :mouse_drag, x: x, y: y} ->
        cond do
          # Resizing a widget
          model.resizing ->
            %{widget_id: widget_id, start_mouse: start_mouse, start_spec: start_spec} = model.resizing

            # Calculate delta movement in pixels
            delta_x = x - start_mouse.x
            delta_y = y - start_mouse.y

            # Resize logic
            {cell_width, cell_height} = GridContainer.get_cell_dimensions(grid_config)

            # Convert pixel delta to grid units (with minimum sizes)
            delta_col = max(0, round(delta_x / cell_width))
            delta_row = max(0, round(delta_y / cell_height))

            # Calculate new width/height (clamped to grid bounds)
            new_width = min(grid_config.cols, max(1, start_spec.width + delta_col))
            new_height = min(grid_config.rows, max(1, start_spec.height + delta_row))

            new_spec = %{start_spec | width: new_width, height: new_height}
            current_widget = Enum.find(model.widgets, &(&1.id == widget_id))

            if new_spec != current_widget.grid_spec do
              Logger.debug(
                "[Dashboard] Resizing widget #{widget_id} to width=#{new_width}, height=#{new_height}"
              )

              new_widgets =
                Enum.map(model.widgets, fn w ->
                  if w.id == widget_id, do: %{w | grid_spec: new_spec}, else: w
                end)

              %{model | widgets: new_widgets}
            else
              # No change in grid dimensions
              model
            end

          # Dragging a widget
          model.dragging ->
            %{widget_id: widget_id, start_spec: start_spec, offset: offset} =
              model.dragging

            target_x = x - offset.x
            target_y = y - offset.y

            {new_col, new_row} =
              coords_to_grid_cell(target_x, target_y, grid_config)

            new_spec = %{start_spec | col: new_col, row: new_row}
            current_widget = Enum.find(model.widgets, &(&1.id == widget_id))

            if new_spec != current_widget.grid_spec do
              Logger.debug(
                "[Dashboard] Dragging widget #{widget_id} to col=#{new_col}, row=#{new_row}"
              )

              new_widgets =
                Enum.map(model.widgets, fn w ->
                  if w.id == widget_id, do: %{w | grid_spec: new_spec}, else: w
                end)

              %{model | widgets: new_widgets}
            else
              # No change in grid position
              model
            end

          # Not dragging or resizing
          true ->
            model
        end

      %{type: :mouse, event_type: :mouse_up, x: x, y: y} ->
        cond do
          model.resizing ->
            Logger.debug(
              "[Dashboard] Mouse Up, ending resize for widget #{model.resizing.widget_id} at (#{x}, #{y})"
            )

            # Save layout after resize
            new_model = %{model | resizing: nil}
            save_layout(new_model.widgets)
            new_model

          model.dragging ->
            Logger.debug(
              "[Dashboard] Mouse Up, ending drag for widget #{model.dragging.widget_id} at (#{x}, #{y})"
            )

            # Save layout after drag
            new_model = %{model | dragging: nil}
            save_layout(new_model.widgets)
            new_model

          # No drag/resize was active
          true ->
            model
        end

      # Ignore other event types for now
      _ ->
        model
    end
  end

  @doc """
  Handles updates to the dashboard and ensures layout persistence.
  This is a wrapper around update/2 that will save the layout when significant changes occur.
  Returns both the updated model and a boolean indicating if a layout save was triggered.

  Use this function in preference to update/2 when automatic layout persistence is desired.
  """
  def handle_update(event, %Model{} = model) do
    # Track if this is a resize or drag completion event
    save_needed = case event do
      # Mouse up after drag or resize should trigger save
      %{type: :mouse, event_type: :mouse_up} ->
        model.dragging != nil || model.resizing != nil

      # Other significant events could be added here
      _ -> false
    end

    # Call the regular update function to perform the actual update
    updated_model = update(event, model)

    # If this was a significant change, save the layout
    if save_needed do
      Logger.debug("[Dashboard] Saving layout after significant change (drag/resize completed)")
      save_layout(updated_model.widgets)
      {updated_model, true}
    else
      {updated_model, false}
    end
  end

  @doc """
  Updates a specific widget's configuration and persists the change to layout.
  This function is used for programmatic widget updates (not from mouse events).

  Returns {:ok, updated_model} on success, or {:error, reason} on failure.
  """
  def update_widget(%Model{} = model, widget_id, update_fn) when is_function(update_fn, 1) do
    # Find the widget to update
    case Enum.find_index(model.widgets, fn w -> w.id == widget_id end) do
      nil ->
        {:error, "Widget with ID #{widget_id} not found"}

      index ->
        # Apply the update function to the widget
        updated_widgets = List.update_at(model.widgets, index, update_fn)

        # Create updated model
        updated_model = %{model | widgets: updated_widgets}

        # Save the layout
        case save_layout(updated_widgets) do
          :ok ->
            {:ok, updated_model}

          error ->
            Logger.error("[Dashboard] Failed to save layout after widget update: #{inspect(error)}")
            {:ok, updated_model} # Still return updated model even if save failed
        end
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

  defp is_in_resize_handle?(_x, _y, bounds)
       when bounds.width < 1 or bounds.height < 1 do
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

    approx_col =
      if cell_width > 0,
        do: div(max(0, x - parent_bounds.x), cell_width + gap) + 1,
        else: 1

    approx_row =
      if cell_height > 0,
        do: div(max(0, y - parent_bounds.y), cell_height + gap) + 1,
        else: 1

    final_col = max(1, min(approx_col, cols))
    final_row = max(1, min(approx_row, rows))

    {final_col, final_row}
  end
end
