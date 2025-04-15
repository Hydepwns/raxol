defmodule Raxol.MyApp do
  @moduledoc """
  A simple example Raxol application that displays typed text and an image on keypress.
  """
  use Raxol.App
  alias Raxol.Components.Dashboard.Dashboard

  require Logger

  # --- Model Definition ---
  defmodule Model do
    @enforce_keys [:width, :height, :dashboard_model]
    defstruct width: 80,
              height: 24,
              text: "",
              dashboard_model: nil
  end

  # --- App Implementation ---

  @impl Raxol.App
  def init(_opts) do
    initial_width = 80
    initial_height = 24

    # Load saved layout or use default
    loaded_widgets = Dashboard.load_layout()
    initial_widgets =
      if loaded_widgets == [] do
        # Define default layout if load failed or no file exists
        Logger.debug("[MyApp.init] Using default widget layout.")
        [
          %{id: :w1, type: :info, title: "Widget 1", grid_spec: %{col: 1, row: 1, col_span: 6, row_span: 3}},
          %{id: :w2, type: :text_input, title: "Text Input", grid_spec: %{col: 1, row: 4, col_span: 12, row_span: 6}},
          %{
            id: :chart1,
            type: :chart,
            title: "Sales Data (Q1)", # Keep title for WidgetContainer
            grid_spec: %{col: 7, row: 1, col_span: 6, row_span: 3},
            # Add data for the chart
            data: [
              {"Jan", 120},
              {"Feb", 210},
              {"Mar", 180}
            ],
            # Add component-specific options
            component_opts: %{
              type: :bar,
              title: "Quarterly Sales", # Title for the chart itself
              x_axis_label: "Month",
              y_axis_label: "Revenue (k)"
            }
          },
          %{
            id: :tree1,
            type: :treemap,
            title: "Project Categories", # Keep title for WidgetContainer
            grid_spec: %{col: 1, row: 10, col_span: 12, row_span: 3},
            # Add data for the treemap
            data: %{
              name: "Projects",
              children: [
                %{name: "Frontend", value: 45, children: [%{name: "UI/UX", value: 20}, %{name: "Components", value: 25}]},
                %{name: "Backend", value: 55, children: [%{name: "API", value: 30}, %{name: "Database", value: 15}, %{name: "Infra", value: 10}]}
              ]
            },
            # Add component-specific options
            component_opts: %{
              title: "Project Breakdown", # Title for the treemap itself
              color_scheme: :category10 # Example option
            }
          }
        ]
      else
        Logger.debug("[MyApp.init] Using loaded widget layout.")
        loaded_widgets
      end

    # Define initial grid config for the dashboard, including breakpoints
    initial_grid_config = %{
      parent_bounds: %{x: 0, y: 0, width: initial_width, height: initial_height},
      gap: 1,
      breakpoints: %{
        small:  %{max_width: 59, cols: 4, rows: 12}, # Example: 4 columns for small screens
        medium: %{max_width: 99, cols: 8, rows: 12}, # Example: 8 columns for medium screens
        large:  %{cols: 12, rows: 12}                # Default/Fallback for large screens
      }
      # Note: Explicit cols/rows here will be ignored if breakpoints are used
    }

    # Initialize the Dashboard component's state
    {:ok, dashboard_model} = Dashboard.init(initial_widgets, initial_grid_config)

    {:ok,
     %Model{
       width: initial_width,
       height: initial_height,
       dashboard_model: dashboard_model
     }}
  end

  @impl Raxol.App
  def update(event, model) do
    # Logger.debug("[MyApp] Received event: #{inspect(event)}")

    # Delegate relevant events to the Dashboard component
    # (Assuming Dashboard.update/2 exists and handles events appropriately)
    new_dashboard_model =
      if function_exported?(Dashboard, :update, 2) do
        # Pass the event and the *current* dashboard model
        Dashboard.update(event, model.dashboard_model)
      else
        model.dashboard_model # No update function yet
      end

    # Update the app model with the potentially updated dashboard model
    model = %{model | dashboard_model: new_dashboard_model}

    # Handle app-specific events AFTER potentially updating the dashboard state
    case event do
      # Handle key events: append character if modifiers list is empty and key is an integer (char code)
      %{type: :key, modifiers: [], key: char} when is_integer(char) ->
        # App-specific logic: update text field
        %{model | text: model.text <> <<char::utf8>>}

      # Handle backspace key (typically no modifiers)
      %{type: :key, modifiers: [], key: :backspace} ->
        new_text =
          if String.length(model.text) > 0 do
            String.slice(model.text, 0..-2//-1)
          else
            ""
          end
        # App-specific logic: update text field
        %{model | text: new_text}

      # Handle 'q' key to quit
      %{type: :key, key: :q} ->
        {:stop, :normal, model}

      # Handle resize events - Update both app model and dashboard grid config
      %{type: :resize, width: w, height: h} ->
        Logger.debug("[MyApp] Received resize event: #{w}x#{h}")
        # Update grid config within the dashboard model
        updated_grid_config = %{model.dashboard_model.grid_config |
          parent_bounds: %{x: 0, y: 0, width: w, height: h}
        }
        updated_dashboard_model = %{model.dashboard_model | grid_config: updated_grid_config}
        %{model | width: w, height: h, dashboard_model: updated_dashboard_model}

      # Handle paste message from Runtime
      {:paste_text, content} when is_binary(content) ->
        Logger.debug("[MyApp] Received paste_text: #{content}")
        # App-specific logic: update text field
        %{model | text: model.text <> content}

      # Default case for events not handled by app-specific logic (e.g., mouse events handled by Dashboard)
      _ ->
        # Logger.debug("[MyApp] Event not handled by app-specific logic: #{inspect(event)}")
        model
    end
  end

  @impl Raxol.App
  def render(model) do
    # Delegate rendering to the Dashboard component, passing the necessary app state
    Dashboard.render(%{dashboard_model: model.dashboard_model, app_text: model.text})
  end

  # Remove widget rendering helpers, now handled by Dashboard
  # defp box_style(bounds) do ... end
  # defp render_widget(widget_config, model) do ... end

  # Remove grid/widget helper functions, these should move to Dashboard
  # defp find_widget_and_bounds_at(x, y, widgets, grid_config) do ... end
  # defp is_in_resize_handle?(x, y, bounds) do ... end
  # defp coords_to_grid_cell(x, y, grid_config) do ... end

  # Private helper to mimic ImagePlugin's sequence generation (Commented out)
  # defp generate_iterm_image_sequence(base64_data, params) do
  #   # ... implementation ...
  # end
end
