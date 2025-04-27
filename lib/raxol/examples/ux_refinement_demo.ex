defmodule Raxol.Examples.UXRefinementDemo do
  use Raxol.Core.Runtime.Application
  # Remove use Component
  # use Raxol.UI.Components.Base.Component
  # Removed conflicting behaviour
  # @behaviour Raxol.UI.Components.Base.Component

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

  import Raxol.Core.Renderer.View,
    except: [row: 2, column: 1, button: 1, text_input: 1, label: 2, space: 1]

  alias Raxol.Core.UXRefinement
  alias Raxol.Core.FocusManager
  alias Raxol.Components.FocusRing
  alias Raxol.Core.Runtime.Command
  alias Raxol.View.Elements, as: UI
  require Logger

  require Raxol.View.Elements

  defstruct [
    # Focus state
    current_view: :main,
    focus_id: "button_1",
    username: "",
    password: "",
    focused_component: "username_input",
    show_help: false,
    focus_ring_model: Raxol.Components.FocusRing.init(%{animation: :pulse})
  ]

  @doc """
  Run the UX Refinement demo application.
  """
  def run do
    Logger.info("Starting UX Refinement Demo...")

    # Ensure Raxol.Runtime is started if it's not already running as part of the main app
    # Updated to use the new Lifecycle module
    Raxol.Core.Runtime.Lifecycle.start_application(__MODULE__, [])

    # Placeholder state for demonstration
    _initial_state = %{
      current_view: :main,
      focus_id: "button_1",
      username: "",
      password: "",
      focused_component: "username_input",
      show_help: false,
      focus_ring_model: Raxol.Components.FocusRing.init(%{animation: :pulse})
    }

    # Enable UX refinement features
    _ = UXRefinement.enable_feature(:keyboard_nav)
    _ = UXRefinement.enable_feature(:focus_management)
    _ = UXRefinement.enable_feature(:hints)
    _ = UXRefinement.enable_feature(:response_optimization)

    # Configure the focus ring appearance
    # FocusRing.configure(
    #   style: :dotted,
    #   color: :cyan,
    #   animation: :pulse,
    #   offset: 1
    # )

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

    # Start Raxol with the demo application using Lifecycle
    Raxol.Core.Runtime.Lifecycle.start_application(__MODULE__, %{
        form_data: %{username: "", password: ""},
        focused_field: :username,
        show_help: false,
        focus_ring_model: Raxol.Components.FocusRing.init(%{animation: :pulse})
      }
    )

    # Example: Configure focus ring after startup (if needed)
    # This logic should likely be part of the application's init or update flow
    # Commenting out as FocusRing.configure/1 is removed
    # FocusRing.configure(
    #   Raxol.Core.Runtime.Application.get_state(), # Needs access to state
    #   animation: :blink,
    #   color: :cyan
    # )
  end

  @doc """
  Placeholder init/1 callback to satisfy the behaviour.
  """
  @impl true
  def init(_opts) do
    # Example initialization, focusing the first field
    {:ok, %{
      form_data: %{username: "", password: ""},
      focused_field: :username,
      show_help: false,
      # Initialize FocusRing component state
      focus_ring_model: Raxol.Components.FocusRing.init(%{animation: :pulse})
    }}
  end

  @doc """
  Render the application UI.
  """
  @dialyzer {:nowarn_function, view: 1}
  @impl Raxol.Core.Runtime.Application
  def view(model) do
    focused_id = model.focused_component
    all_hints = get_hints_for(focused_id)

    # --- Calculate focus position BEFORE the main component list ---
    element_registry = Process.get(:element_position_registry, %{})
    focused_position = Map.get(element_registry, focused_id)

    # --- Conditionally create the focus ring component ---
    focus_ring_component =
      if focused_position do
        # Raxol.View.Elements.component(
        #   Raxol.Components.FocusRing,
        #   id: :focus_ring,
        #   model: model.focus_ring_model,
        #   focused_element_id: focused_id,
        #   focused_element_position: focused_position
        # )
        # Construct component map directly
        %{
          type: Raxol.Components.FocusRing,
          id: :focus_ring,
          # Pass props directly, assuming component handles its own model state
          # model: model.focus_ring_model,
          focused_element_id: focused_id,
          focused_element_position: focused_position
        }
      else
        nil # Explicitly return nil if no position
      end

    # Raxol.View.Elements.component Raxol.Components.AppContainer, id: :app_container do
    # Use AppContainer map directly as the root element
    %{
      type: Raxol.Components.AppContainer,
      id: :app_container,
      children: [
        # START OF LIST
        Raxol.View.Elements.panel title: "Login Form" do
          UI.box do
            [
              # Main content area (takes up most space)
              UI.box style: %{height: "fill-1"} do
                # Layout the three main sections
                Raxol.View.Elements.row height: "100%" do
                  Raxol.View.Elements.column padding: 1 do
                    # Wrap all children in an explicit list
                    [
                      if model.show_help do
                        render_help_dialog()
                      else
                        # Form elements need to be a list too for the outer list
                        [
                          Raxol.View.Elements.row padding_bottom: 1 do
                            label_element = Raxol.View.Elements.label(content: "Username:", style: %{width: 10})

                            input_element =
                              Raxol.View.Elements.text_input(
                                id: "username_input",
                                value: model.form_data.username,
                                width: 30,
                                focus: focused_id == "username_input"
                              )

                            [label_element, input_element]
                          end,
                          Raxol.View.Elements.row padding_bottom: 1 do
                            label_element = Raxol.View.Elements.label(content: "Password:", style: %{width: 10})

                            input_element =
                              Raxol.View.Elements.text_input(
                                id: "password_input",
                                value: model.form_data.password,
                                width: 30,
                                password: true,
                                focus: focused_id == "password_input"
                              )

                            [label_element, input_element]
                          end,
                          Raxol.View.Elements.row padding_top: 1 do
                            login_button =
                              Raxol.View.Elements.button(
                                id: "login_button",
                                label: "Login",
                                width: 10,
                                focus: focused_id == "login_button"
                              )

                            space_element = Raxol.View.Elements.label(content: " ")

                            reset_button =
                              Raxol.View.Elements.button(
                                id: "reset_button",
                                label: "Reset",
                                width: 10,
                                focus: focused_id == "reset_button"
                              )

                            space_element2 = Raxol.View.Elements.label(content: " ")

                            help_button =
                              Raxol.View.Elements.button(
                                id: "help_button",
                                label: "Help",
                                width: 10,
                                focus: focused_id == "help_button"
                              )

                            [login_button, space_element, reset_button, space_element2, help_button]
                          end
                        ]
                      end
                    ]
                  end
                end
              end,

              # Hint display at the bottom
              # Raxol.View.Elements.component(
              #   Raxol.Components.HintDisplay,
              #   id: :hint_display,
              #   hints: all_hints,
              #   position: :bottom
              #   # Style can be added here if needed
              # )
              # Construct component map directly
              %{
                type: Raxol.Components.HintDisplay,
                id: :hint_display,
                hints: all_hints,
                position: :bottom
                # Style can be added here if needed
              },

              # Add the pre-calculated focus ring component (will be nil if not needed)
              focus_ring_component
            ]
          end
        end
      ]
    }
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
          %{model | form_data: %{model.form_data | username: value}}

        {:input, "password_input", value} ->
          %{model | form_data: %{model.form_data | password: value}}

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
    # Use the panel macro directly
    rendered_dialog =
      Raxol.View.Elements.panel title: "Help",
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
        Raxol.View.Elements.column do
          [
            Raxol.View.Elements.label(content: "This is a demo of the UX Refinement features in Raxol."),
            Raxol.View.Elements.label(content: "Use Tab and Shift+Tab to navigate between form fields."),
            Raxol.View.Elements.label(content: "The focus ring indicates which element is focused."),
            Raxol.View.Elements.label(content: "Hints at the bottom provide context for each element."),

            Raxol.View.Elements.row padding_top: 2 do
              [
                 Raxol.View.Elements.button(
                   id: "close_help",
                   label: "Close",
                   width: 10,
                   on_click: {:close_help}
                 )
              ]
            end
          ] # End list of children for column
        end
      end

    rendered_dialog
  end

  # --- Placeholder Hint Function ---
  defp get_hints_for(_focused_component_id), do: []

  # Correct arity for Application behaviour
  @impl Raxol.Core.Runtime.Application
  def handle_event(_event) do
    # State is managed by Dispatcher, just return commands
    []
  end

  # Correct arity for Application behaviour
  @impl Raxol.Core.Runtime.Application
  def handle_message(_msg, state), do: {state, []}

  # Correct arity for Application behaviour
  @impl Raxol.Core.Runtime.Application
  def handle_tick(_tick) do
    # State is managed by Dispatcher, just return commands
    []
  end

  @impl Raxol.Core.Runtime.Application
  def subscriptions(_state), do: []

  @impl Raxol.Core.Runtime.Application
  def terminate(_reason, _state), do: :ok
end
