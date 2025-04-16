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
    # Use fixed initial dimensions for now
    initial_width = 80
    initial_height = 24

    # Load layout, or use defaults
    loaded_widgets = Dashboard.load_layout()

    Logger.debug(
      "[MyApp.init] Result of Dashboard.load_layout(): #{inspect(loaded_widgets)}"
    )

    # Use loaded layout if available, otherwise defaults
    initial_widgets =
      if loaded_widgets != [] and is_list(loaded_widgets) do # Check if list and not empty
        Logger.debug(
          "[MyApp.init] Saved layout found, using #{length(loaded_widgets)} widgets."
        )
        loaded_widgets
      else
        Logger.debug(
          "[MyApp.init] No saved layout found or layout was invalid, using default widgets."
        )
        # Define default widgets if no layout is loaded
        [
          %{
            id: :w1,
            type: :info,
            title: "Widget 1",
            grid_spec: %{row: 1, col: 1, col_span: 6, row_span: 3}
          },
          %{
            id: :w2,
            type: :text_input,
            title: "Text Input",
            grid_spec: %{row: 4, col: 1, col_span: 12, row_span: 6}
          },
          %{
            id: :chart1,
            type: :chart,
            title: "Sales Data (Q1)",
            grid_spec: %{row: 1, col: 7, col_span: 6, row_span: 3},
            # Add data for the chart
            data: [
              %{label: "Jan", value: 12},
              %{label: "Feb", value: 19},
              %{label: "Mar", value: 3}
            ],
            # Add component-specific options
            component_opts: %{
              type: :bar,
              # Title for the chart itself
              title: "Quarterly Sales",
              x_axis_label: "Month",
              y_axis_label: "Revenue (k)"
            }
          },
          %{
            id: :tree1,
            type: :treemap,
            # Keep title for WidgetContainer
            title: "Project Categories",
            grid_spec: %{row: 10, col: 1, col_span: 12, row_span: 3},
            # Add data for the treemap
            data: %{
              name: "Projects",
              children: [
                %{
                  name: "Frontend",
                  value: 45,
                  children: [
                    %{name: "UI/UX", value: 20},
                    %{name: "Components", value: 25}
                  ]
                },
                %{
                  name: "Backend",
                  value: 55,
                  children: [
                    %{name: "API", value: 30},
                    %{name: "Database", value: 15},
                    %{name: "Infra", value: 10}
                  ]
                }
              ]
            },
            # Add component-specific options
            component_opts: %{
              # Title for the treemap itself
              title: "Project Breakdown",
              # Example option
              color_scheme: :category10
            }
          },
          # Add an image widget for testing
          %{
            id: :img1,
            # Assuming :image is the correct type
            type: :image,
            title: "Test Image",
            grid_spec: %{row: 14, col: 1, col_span: 6, row_span: 4},
            component_opts: %{
              # Corrected path
              path: "assets/static/images/logo.png"
            }
          }
        ]
      end

    # Define initial grid config for the dashboard, including breakpoints
    initial_grid_config = %{
      parent_bounds: %{x: 0, y: 0, width: initial_width, height: initial_height},
      gap: 1,
      breakpoints: %{
        # Example: 4 columns for small screens
        small: %{max_width: 59, cols: 4, rows: 12},
        # Example: 8 columns for medium screens
        medium: %{max_width: 99, cols: 8, rows: 12},
        # Default/Fallback for large screens
        large: %{cols: 12, rows: 12}
      }
      # Note: Explicit cols/rows here will be ignored if breakpoints are used
    }

    # Initialize the Dashboard component's state
    Logger.debug("[MyApp.init] Calling Dashboard.init with widgets: #{inspect(initial_widgets)} and config: #{inspect(initial_grid_config)}")
    {:ok, dashboard_model} =
      Dashboard.init(initial_widgets, initial_grid_config)
    Logger.debug("[MyApp.init] Dashboard.init returned: {:ok, #{inspect(dashboard_model)}}") # Assuming success

    model = %Model{
      width: initial_width,
      height: initial_height,
      text: "",
      dashboard_model: dashboard_model
    }

    Logger.debug("[MyApp.init] Initialization complete. Returning model: #{inspect(model)}")

    {:ok, model}
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
        # No update function yet
        model.dashboard_model
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

      # Handle resize events - Update both app model and dashboard grid config
      %{type: :resize, width: w, height: h} ->
        Logger.debug("[MyApp] Received resize event: #{w}x#{h}")
        # Update grid config within the dashboard model
        updated_grid_config = %{
          model.dashboard_model.grid_config
          | parent_bounds: %{x: 0, y: 0, width: w, height: h}
        }

        updated_dashboard_model = %{
          model.dashboard_model
          | grid_config: updated_grid_config
        }

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
  def render(props) do
    Logger.debug("[MyApp.render] Starting render... Props received: #{inspect(props)}")
    # Extract model and grid_config from props
    %{model: model, grid_config: grid_config} = props

    # Delegate rendering to the Dashboard component, passing the necessary state
    Dashboard.render(%{
      dashboard_model: model.dashboard_model,
      grid_config: grid_config, # Pass grid_config down
      app_text: model.text
    })
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
