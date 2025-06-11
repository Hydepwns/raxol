defmodule Raxol.UI.Components.Dashboard.Dashboard do
  @moduledoc """
  A component responsible for rendering a grid-based dashboard layout.
  Manages widget placement, drag/drop, and resizing.
  """
  # Removed unused WidgetContainer alias
  # alias Raxol.UI.Components.Dashboard.WidgetContainer
  # Removed unused InfoWidget alias
  # alias Raxol.UI.Components.Dashboard.Widgets.InfoWidget
  # Comment out alias to temporarily disabled widget
  # alias Raxol.UI.Components.Dashboard.Widgets.TextInputWidget
  use Raxol.UI.Components.Base.Component
  require Raxol.View.Elements
  require Raxol.Core.Runtime.Log
  alias Raxol.View.Elements, as: UI
  # Add alias
  alias Raxol.UI.Components.Dashboard.LayoutPersistence

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
              resizing: nil,
              layout: [],
              id: :dashboard

    # Add other necessary state fields (e.g., focus)
  end

  # --- Public API (Example - might change based on component behaviour) ---

  @spec init(map()) :: Model.t()
  @impl Raxol.UI.Components.Base.Component
  def init(props) do
    # Initialize with widgets and layout from props
    # Note: Widgets themselves need to be initialized elsewhere (e.g., Application init)
    # This component assumes widgets are passed in as initialized state maps
    %Model{
      id: props[:id] || :dashboard,
      widgets: props[:widgets] || %{},
      layout: props[:layout] || []
    }
  end

  @spec init_from_saved_layout(list(), map()) :: {:ok, Model.t()} | {:error, any()}
  @doc """
  Initializes the Dashboard state from a saved layout.
  If no saved layout exists, returns default widgets with the given grid configuration.

  This function loads widget configurations using `LayoutPersistence.load_layout/0` and initializes
  the dashboard model with those widgets and the provided grid_config.

  Returns {:ok, model} on success, or {:error, reason} on failure.
  """
  def init_from_saved_layout(default_widgets, grid_config)
      when is_list(default_widgets) and is_map(grid_config) do
    # Try to load saved widgets from file
    loaded_widgets = LayoutPersistence.load_layout()

    # If we have loaded widgets, use them - otherwise use defaults
    # Check if loaded_widgets is a non-empty list
    widgets =
      if is_list(loaded_widgets) && loaded_widgets != [] do
        Raxol.Core.Runtime.Log.info(
          "Initializing dashboard from saved layout with #{length(loaded_widgets)} widgets"
        )

        loaded_widgets
      else
        Raxol.Core.Runtime.Log.info(
          "No saved layout found, initializing dashboard with #{length(default_widgets)} default widgets"
        )

        default_widgets
      end

    # Verify widgets are valid before initializing
    if validate_widgets(widgets) do
      {:ok, %Model{widgets: widgets, grid_config: grid_config}}
    else
      Raxol.Core.Runtime.Log.error(
        "Invalid widget configurations in saved layout, using defaults"
      )

      {:ok, %Model{widgets: default_widgets, grid_config: grid_config}}
    end
  end

  @spec validate_widgets(list() | nil) :: boolean()
  @doc """
  Validates a list of widget configurations to ensure they can be properly rendered.
  Returns true if widgets are valid, false otherwise.
  """
  def validate_widgets(widgets) when is_list(widgets) do
    # Check that all widgets have required fields
    Enum.all?(widgets, fn widget ->
      required_fields = [:id, :type, :title, :grid_spec]
      required_grid_fields = [:col, :row, :width, :height]

      has_required_fields =
        Enum.all?(required_fields, &Map.has_key?(widget, &1))

      has_grid_fields =
        widget[:grid_spec] &&
          Enum.all?(required_grid_fields, &Map.has_key?(widget.grid_spec, &1))

      valid_type =
        widget[:type] in [:chart, :treemap, :info, :text_input, :image]

      has_required_fields && has_grid_fields && valid_type
    end)
  end

  # Default implementation for empty list
  def validate_widgets([]), do: true
  # Handle nil case
  def validate_widgets(nil), do: false

  @spec update(term(), Model.t()) :: {Model.t(), list()}
  @impl Raxol.UI.Components.Base.Component
  def update(msg, state) do
    # Route messages to child widgets or handle dashboard-specific updates
    # Example: {:widget_msg, widget_id, child_msg}
    case msg do
      {:widget_msg, widget_id, child_msg} ->
        case Map.fetch(state.widgets, widget_id) do
          {:ok, _widget_state} ->
            # Assuming widget has an update/2 function (not standard Component)
            # This needs refinement based on how widgets handle updates
            # If widgets follow Component behaviour, we'd send event/command
            # {new_widget_state, commands} = WidgetModule.update(child_msg, widget_state)
            # new_widgets = Map.put(state.widgets, widget_id, new_widget_state)
            # {state | widgets: new_widgets}, commands
            Raxol.Core.Runtime.Log.debug(
              "Routing msg to widget #{widget_id}: #{inspect(child_msg)}"
            )

            # Placeholder: update widget state
            {state, []}

          :error ->
            Raxol.Core.Runtime.Log.error(
              "Dashboard received msg for unknown widget: #{widget_id}"
            )

            {state, []}
        end

      _ ->
        Raxol.Core.Runtime.Log.debug("Dashboard received message: #{inspect(msg)}")
        {state, []}
    end
  end

  @spec handle_event(term(), map(), Model.t()) :: {Model.t(), list()}
  @impl Raxol.UI.Components.Base.Component
  def handle_event(event, _props, state) do
    # Placeholder: Handle events, potentially focus related for widgets
    Raxol.Core.Runtime.Log.debug("Dashboard received event: #{inspect(event)}")
    {state, []}
  end

  @spec render(Model.t(), map()) :: any()
  @impl Raxol.UI.Components.Base.Component
  def render(state, _props) do
    # Get grid config and layout from state
    # Expects %{cols: _, rows: _, gap: _}
    grid_config = state.grid_config
    # Expects list of %{id: _, col: _, row: _, width: _, height: _}
    layout_specs = state.layout

    # Define the main container using box (placeholder for grid)
    UI.box id: state.id,
           border: :single,
           style: %{padding: Map.get(grid_config, :gap, 1)} do
      # Iterate through the layout specs to place widgets
      # NOTE: This will just render widgets sequentially inside the box, not in a grid
      Enum.map(layout_specs, fn grid_spec ->
        widget_id = grid_spec.id

        case Map.fetch(state.widgets, widget_id) do
          {:ok, widget_state} ->
            # Assuming widget_state is the full state map for the child component
            # and it follows the Component behaviour
            # Need module to call render
            widget_module = Map.get(widget_state, :module)

            if widget_module do
              # Place the widget in its container (placeholder for grid_item)
              UI.box title:
                       Map.get(widget_state, :title, "Widget #{widget_id}"),
                     border: :rounded,
                     # Add some margin for spacing
                     style: %{margin: 1} do
                # Recursively render the child widget
                # Passing down relevant props or an empty map if none needed
                widget_module.render(widget_state, %{})
              end
            else
              # Error case: widget state doesn't specify its module
              UI.box title: "Error" do
                UI.label(
                  content: "Error: Module missing for widget #{widget_id}"
                )
              end
            end

          :error ->
            # Error case: widget ID from layout not found in widget state map
            # Render an error message in its place
            UI.box title: "Error" do
              UI.label(content: "Error: Widget '#{widget_id}' not found!")
            end
        end
      end)
    end
  end
end
