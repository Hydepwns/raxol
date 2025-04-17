defmodule Raxol.Examples.UXRefinementDemo do
  use Raxol.App
  alias Raxol.View
  # removed: @behaviour Raxol.Core.Runtime.Application

  @moduledoc """
  Demo example showcasing the User Experience Refinement components.

  This example demonstrates:
  1. Focus management with keyboard navigation
  2. Contextual hints for different components
  3. Visual focus indication
  4. Accessibility support

  Run this example with:
  ```
  $ mix run -e "Raxol.Examples.UXRefinementDemo.run()"
  ```
  """

  import Raxol.View,
    except: [row: 2, column: 1, button: 1, text_input: 1, label: 2, space: 1]

  import Raxol.View.Components,
    only: [button: 1, text_input: 1, label: 2, space: 1]

  import Raxol.View.Layout, only: [row: 2]
  alias Raxol.Core.UXRefinement
  alias Raxol.Core.FocusManager
  # alias Raxol.Core.KeyboardNavigator # Module seems to be missing
  alias Raxol.Components.HintDisplay
  alias Raxol.Components.FocusRing
  alias Raxol.View.Layout
  require Logger
  require Raxol.View

  @doc """
  Run the UX Refinement demo application.
  """
  def run do
    IO.puts("Starting UX Refinement Demo...")

    # Start the runtime with this module as the application
    # Ensure Raxol.Runtime is started if it's not already running as part of the main app
    # Runtime.start_link(%{initial_component: __MODULE__})
    Raxol.Runtime.run(__MODULE__, [])

    # Placeholder state for demonstration
    _initial_state = %{
      current_view: :main,
      focus_id: "button_1",
      username: "",
      password: "",
      focused_component: "username_input",
      show_help: false,
      focus_ring_model: FocusRing.init(%{animation: :pulse})
    }

    # Enable UX refinement features
    _ = UXRefinement.enable_feature(:keyboard_nav)
    _ = UXRefinement.enable_feature(:focus_management)
    _ = UXRefinement.enable_feature(:hints)
    _ = UXRefinement.enable_feature(:response_optimization)

    # Configure the focus ring appearance
    FocusRing.configure(
      style: :dotted,
      color: :cyan,
      animation: :pulse,
      offset: 1
    )

    # Initialize keyboard navigation
    # KeyboardNavigator.init()
    # KeyboardNavigator.configure(vim_keys: true)

    # Register hints for components
    _ =
      UXRefinement.register_hint(
        "username_input",
        "Enter your username (letters and numbers only)"
      )

    _ =
      UXRefinement.register_hint(
        "password_input",
        "Enter a secure password (minimum 8 characters)"
      )

    _ = UXRefinement.register_hint("login_button", "Press Enter to log in")

    _ =
      UXRefinement.register_hint(
        "reset_button",
        "Press Enter to reset the form"
      )

    _ =
      UXRefinement.register_hint(
        "help_button",
        "Press Enter to open the help dialog"
      )

    # Register focusable components
    FocusManager.register_focusable("username_input", 1,
      announce: "Username input field. Enter your username."
    )

    FocusManager.register_focusable("password_input", 2,
      announce: "Password input field. Enter your password."
    )

    FocusManager.register_focusable("login_button", 3,
      group: :buttons,
      announce: "Login button"
    )

    FocusManager.register_focusable("reset_button", 4,
      group: :buttons,
      announce: "Reset button"
    )

    FocusManager.register_focusable("help_button", 5,
      group: :buttons,
      announce: "Help button"
    )

    # Set initial focus
    FocusManager.set_initial_focus("username_input")

    # Mock element positions for the focus ring
    # In a real app, these would be determined by the layout system
    element_registry = %{
      "username_input" => {10, 5, 30, 3},
      "password_input" => {10, 9, 30, 3},
      "login_button" => {10, 13, 10, 3},
      "reset_button" => {22, 13, 10, 3},
      "help_button" => {34, 13, 10, 3}
    }

    Process.put(:element_position_registry, element_registry)
  end

  @doc """
  Placeholder init/1 callback to satisfy the behaviour.
  """
  def init(_opts) do
    # Initialize the app state
    initial_state = %{
      username: "",
      password: "",
      focused_component: "username_input",
      show_help: false,
      focus_ring_model: FocusRing.init(%{animation: :pulse})
    }

    # Return state directly or {state, commands}
    # Or {initial_state, []}
    initial_state
  end

  @doc """
  Render the application UI.
  """
  @dialyzer {:nowarn_function, view: 1}
  def view(model) do
    # Call the local render helper function
    rendered_view = render(model, [])
    rendered_view
  end

  # This is a local helper function, not part of the Application behaviour
  @dialyzer {:nowarn_function, render: 2}
  def render(model, _opts) do
    focused = FocusManager.get_focused_element()

    # Main layout
    # Use View.panel macro directly
    rendered_panel =
      View.panel background: :default, height: "100%", width: "100%" do
        # Layout the three main sections
        Layout.row height: "100%" do
          Layout.column padding: 1 do
            if model.show_help do
              render_help_dialog()
            else
              # Form elements
              row(padding_bottom: 1) do
                label("Username:", width: 10)

                text_input(
                  id: "username_input",
                  value: model.username,
                  width: 30,
                  focus: focused == "username_input"
                )
              end

              row(padding_bottom: 1) do
                label("Password:", width: 10)

                text_input(
                  id: "password_input",
                  value: model.password,
                  width: 30,
                  password: true,
                  focus: focused == "password_input"
                )
              end

              row(padding_top: 1) do
                button(
                  id: "login_button",
                  label: "Login",
                  width: 10,
                  focus: focused == "login_button"
                )

                space(width: 2)

                button(
                  id: "reset_button",
                  label: "Reset",
                  width: 10,
                  focus: focused == "reset_button"
                )

                space(width: 2)

                button(
                  id: "help_button",
                  label: "Help",
                  width: 10,
                  focus: focused == "help_button"
                )
              end
            end

            # Render the focus ring for the focused element
            FocusRing.render(model.focus_ring_model)

            # Keyboard shortcut info
            row(padding_top: 2) do
              text("Tab: Next field | Shift+Tab: Previous field | Esc: Exit",
                align: :center
              )
            end

            # Hint display at the bottom
            row(bottom: 0, left: 0, width: "100%") do
              HintDisplay.render(focused)
            end
          end
        end
      end

    rendered_panel
  end

  @doc """
  Update the application state based on events.
  """
  @impl true
  def update(model, msg) do
    new_model =
      case msg do
        # Text input updates
        {:input, "username_input", value} ->
          %{model | username: value}

        {:input, "password_input", value} ->
          %{model | password: value}

        # Button clicks
        {:click, "login_button"} ->
          # In a real app, this would handle authentication
          model

        {:click, "reset_button"} ->
          %{model | username: "", password: ""}

        {:click, "help_button"} ->
          %{model | show_help: true}

        # Focus change events
        {:focus_change, _old_focus, new_focus} ->
          # Update the focus ring position
          updated_focus_ring =
            FocusRing.update(
              model.focus_ring_model,
              {:focus_change, nil, new_focus}
            )

          %{
            model
            | focused_component: new_focus,
              focus_ring_model: updated_focus_ring
          }

        # Close help dialog
        {:close_help} ->
          %{model | show_help: false}

        # Default case
        _ ->
          model
      end

    # Return {new_state, commands}
    {new_model, []}
  end

  # Private functions

  @dialyzer {:nowarn_function, render_help_dialog: 0}
  defp render_help_dialog do
    # Use View.panel macro directly
    rendered_dialog =
      View.panel title: "Help",
                 padding: 1,
                 height: 12,
                 width: 40,
                 border: true,
                 style: %{
                   position: :absolute,
                   top: "50%",
                   left: "50%",
                   transform: "translate(-50%, -50%)"
                 } do
        Layout.column do
          text("This is a demo of the UX Refinement features in Raxol.")
          text("Use Tab and Shift+Tab to navigate between form fields.")
          text("The focus ring indicates which element is focused.")
          text("Hints at the bottom provide context for each element.")

          row(padding_top: 2) do
            button(
              id: "close_help",
              label: "Close",
              width: 10,
              on_click: {:close_help}
            )
          end
        end
      end

    rendered_dialog
  end
end
