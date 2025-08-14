defmodule Raxol.Examples.AccessibilityDemo do
  @moduledoc """
  Demo of accessibility features in Raxol. (Refactored to use Application behaviour)

  This example demonstrates:
  - Screen reader announcements
  - High contrast mode
  - Keyboard navigation with focus management
  - Reduced motion
  - Comprehensive hints
  - Large text support
  - Theme integration
  """

  use Raxol.Core.Runtime.Application

  require Raxol.Core.Runtime.Log
  require Raxol.View.Elements
  alias Raxol.View.Elements, as: UI
  alias Raxol.Core.AccessibilityRefactored, as: AccessibilityRefactored
  alias Raxol.Core.FocusManagerRefactored, as: FocusManagerRefactored
  alias Raxol.Core.UserPreferences
  alias Raxol.Core.UXRefinementRefactored, as: UXRefinementRefactoredRefactored, as: UXRefinementRefactored
  require Raxol.Core.Renderer.View
  alias Raxol.Core.Renderer.View

  defstruct focused_element: "search_button",
            message: "Accessibility Demo. Press Tab/Shift+Tab, Enter/Space.",
            id: :accessibility_demo

  @impl Raxol.Core.Runtime.Application
  def init(_opts) do
    Raxol.Core.Runtime.Log.info("Initializing AccessibilityDemo...")

    setup_focus_and_hints()

    Accessibility.announce(
      "Accessibility demo loaded. Use Tab to navigate.",
      [priority: :high],
      UserPreferences
    )

    FocusManager.set_focus("search_button")

    initial_state = %__MODULE__{}
    {:ok, initial_state}
  end

  @impl Raxol.Core.Runtime.Application
  def update({:keyboard_event, %{key: :tab, shift: false}}, state) do
    current_focus = state.focused_element
    next_focus = FocusManager.get_next_focusable(current_focus)

    if next_focus do
      FocusManager.set_focus(next_focus)

      Accessibility.announce(
        "Focus: #{get_hint(next_focus, :basic, next_focus)}",
        [],
        UserPreferences
      )

      {:ok, %{state | focused_element: next_focus}}
    else
      first_focus = FocusManager.get_next_focusable(nil)

      if first_focus do
        FocusManager.set_focus(first_focus)

        Accessibility.announce(
          "Focus: #{get_hint(first_focus, :basic, first_focus)}",
          [],
          UserPreferences
        )

        {%{state | focused_element: first_focus}, []}
      else
        {state, []}
      end
    end
  end

  def update({:keyboard_event, %{key: :tab, shift: true}}, state) do
    current_focus = state.focused_element
    prev_focus = FocusManager.get_previous_focusable(current_focus)

    if prev_focus do
      FocusManager.set_focus(prev_focus)

      Accessibility.announce(
        "Focus: #{get_hint(prev_focus, :basic, prev_focus)}",
        [],
        UserPreferences
      )

      {:ok, %{state | focused_element: prev_focus}}
    else
      last_focus = FocusManager.get_previous_focusable(nil)

      if last_focus do
        FocusManager.set_focus(last_focus)

        Accessibility.announce(
          "Focus: #{get_hint(last_focus, :basic, last_focus)}",
          [],
          UserPreferences
        )

        {%{state | focused_element: last_focus}, []}
      else
        {state, []}
      end
    end
  end

  def update({:keyboard_event, %{key: :enter}}, state) do
    case state.focused_element do
      "search_button" ->
        Accessibility.announce(
          "Search action simulated.",
          [priority: :high],
          UserPreferences
        )

        {state, []}

      "settings_button" ->
        Accessibility.announce(
          "Settings action simulated.",
          [priority: :high],
          UserPreferences
        )

        {state, []}

      "help_button" ->
        Accessibility.announce(
          "Help action simulated.",
          [priority: :high],
          UserPreferences
        )

        {state, []}

      _ ->
        {state, []}
    end
  end

  def update({:keyboard_event, %{key: " "}}, state) do
    case state.focused_element do
      "high_contrast_toggle" ->
        toggle_accessibility_setting(:high_contrast, state)

      "reduced_motion_toggle" ->
        toggle_accessibility_setting(:reduced_motion, state)

      "large_text_toggle" ->
        toggle_accessibility_setting(:large_text, state)

      # Space on button does nothing here, use Enter
      _ ->
        {state, []}
    end
  end

  def update({:toggle, setting}, state) do
    toggle_accessibility_setting(setting, state)
  end

  def update({:activate, button_id}, state) do
    Accessibility.announce(
      "#{button_id} activated via click.",
      [priority: :high],
      UserPreferences
    )

    {state, []}
  end

  def update({:keyboard_event, event}, state) do
    # Log other key events if needed
    Raxol.Core.Runtime.Log.debug("Ignoring Keyboard Event: #{inspect(event)}")
    {state, []}
  end

  def update(msg, state) do
    Raxol.Core.Runtime.Log.debug(
      "Received unhandled update message: #{inspect(msg)}"
    )

    {state, []}
  end

  @impl Raxol.Core.Runtime.Application
  @dialyzer {:nowarn_function, view: 1}
  def view(state) do
    # --- Calculate focus position BEFORE the main component list ---
    element_registry = Process.get(:element_position_registry, %{})
    focused_position = Map.get(element_registry, state.focused_element)

    # --- Conditionally create the focus ring component ---
    focus_ring_component =
      if focused_position do
        # Raxol.View.Elements.component(
        #   Raxol.UI.Components.FocusRing,
        #   id: :focus_ring,
        #   model: state.focus_ring_model,
        #   focused_element_id: state.focused_element,
        #   focused_element_position: focused_position
        # )
        # Construct component map directly
        %{
          type: Raxol.UI.Components.FocusRing,
          id: :focus_ring,
          # Pass props directly, assuming component handles its own model state
          # model: state.focus_ring_model,
          focused_element_id: state.focused_element,
          focused_element_position: focused_position
        }
      else
        # Explicitly return nil if no position
        nil
      end

    # Raxol.View.Elements.component Raxol.UI.Components.AppContainer, id: :app_container do
    # Use AppContainer map directly as the root element
    %{
      type: Raxol.UI.Components.AppContainer,
      id: :app_container,
      children: [
        # START OF LIST
        UI.panel title: "Accessibility Demo" do
          UI.box do
            [
              # Main content area (takes up most space)
              UI.box style: %{height: "fill-1"} do
                # Layout the three main sections
                UI.row height: "100%" do
                  UI.column padding: 1 do
                    # Wrap all children in an explicit list
                    [
                      if state.show_help do
                        render_help_dialog()
                      else
                        # Form elements need to be a list too for the outer list
                        [
                          UI.row padding_bottom: 1 do
                            label_element =
                              UI.label("Username:", style: %{width: 10})

                            input_element =
                              UI.text_input(
                                id: "username_input",
                                value: state.form_data.username,
                                width: 30,
                                focus: state.focused_element == "username_input"
                              )

                            [label_element, input_element]
                          end,
                          UI.label(content: state.message),
                          UI.label(
                            content: "Focused: #{state.focused_element}"
                          ),
                          UI.button(
                            label: "Search",
                            id: "search_button",
                            focused: state.focused_element == "search_button",
                            on_click: {:activate, "search_button"}
                          ),
                          UI.button(
                            label: "Settings",
                            id: "settings_button",
                            focused: state.focused_element == "settings_button",
                            on_click: {:activate, "settings_button"}
                          ),
                          UI.button(
                            label: "Help",
                            id: "help_button",
                            focused: state.focused_element == "help_button",
                            on_click: {:activate, "help_button"}
                          ),
                          UI.checkbox(
                            label: "High Contrast",
                            id: "high_contrast_toggle",
                            checked:
                              UserPreferences.get([
                                :accessibility,
                                :high_contrast
                              ]) || false,
                            focused:
                              state.focused_element == "high_contrast_toggle",
                            on_change: {:toggle, :high_contrast}
                          ),
                          UI.checkbox(
                            label: "Reduced Motion",
                            id: "reduced_motion_toggle",
                            checked:
                              UserPreferences.get([
                                :accessibility,
                                :reduced_motion
                              ]) || false,
                            focused:
                              state.focused_element == "reduced_motion_toggle",
                            on_change: {:toggle, :reduced_motion}
                          ),
                          UI.checkbox(
                            label: "Large Text",
                            id: "large_text_toggle",
                            checked:
                              UserPreferences.get([:accessibility, :large_text]) ||
                                false,
                            focused:
                              state.focused_element == "large_text_toggle",
                            on_change: {:toggle, :large_text}
                          )
                        ]
                      end
                    ]
                  end
                end
              end,
              focus_ring_component
            ]
          end
        end
      ]
    }
  end

  @impl Raxol.Core.Runtime.Application
  def handle_event(event) do
    Raxol.Core.Runtime.Log.debug(
      "AccessibilityDemo received unhandled event (handle_event/1): #{inspect(event)}"
    )

    # Return empty list of commands
    []
  end

  @impl Raxol.Core.Runtime.Application
  def handle_message(message, state) do
    Raxol.Core.Runtime.Log.debug(
      "Received unhandled message: #{inspect(message)}"
    )

    {state, []}
  end

  @impl Raxol.Core.Runtime.Application
  def handle_tick(state) do
    {state, []}
  end

  @impl Raxol.Core.Runtime.Application
  def subscriptions(_state) do
    []
  end

  @impl Raxol.Core.Runtime.Application
  def terminate(reason, _state) do
    Raxol.Core.Runtime.Log.info(
      "Terminating AccessibilityDemo: #{inspect(reason)}"
    )

    :ok
  end

  # --- Private Helper Functions ---

  # Moved setup logic here
  defp setup_focus_and_hints do
    # Register components for focus management
    FocusManager.register_focusable("search_button", tab_order: 1)
    FocusManager.register_focusable("settings_button", tab_order: 2)
    FocusManager.register_focusable("help_button", tab_order: 3)
    FocusManager.register_focusable("high_contrast_toggle", tab_order: 4)
    FocusManager.register_focusable("reduced_motion_toggle", tab_order: 5)
    FocusManager.register_focusable("large_text_toggle", tab_order: 6)

    # Register hints using UXRefinement
    UXRefinement.register_component_hint("search_button", %{
      basic: "Search for content",
      detailed: "Search for content in the application using keywords",
      shortcuts: [{"Enter", "Execute search"}, {"Alt+S", "Focus search"}]
    })

    UXRefinement.register_component_hint("settings_button", %{
      basic: "Open settings",
      detailed: "Access application settings and preferences",
      shortcuts: [{"Enter", "Open settings"}, {"Alt+T", "Focus settings"}]
    })

    UXRefinement.register_component_hint("help_button", %{
      basic: "Get help",
      detailed: "Access help documentation and guides",
      shortcuts: [{"Enter", "Open help"}, {"Alt+H", "Focus help"}]
    })

    UXRefinement.register_component_hint("high_contrast_toggle", %{
      basic: "Toggle high contrast mode",
      detailed: "Enable or disable high contrast mode for better visibility",
      shortcuts: [{"Space", "Toggle state"}, {"Alt+C", "Focus toggle"}]
    })

    UXRefinement.register_component_hint("reduced_motion_toggle", %{
      basic: "Toggle reduced motion",
      detailed: "Enable or disable animations for reduced motion",
      shortcuts: [{"Space", "Toggle state"}, {"Alt+M", "Focus toggle"}]
    })

    UXRefinement.register_component_hint("large_text_toggle", %{
      basic: "Toggle large text",
      detailed: "Enable or disable larger text for better readability",
      shortcuts: [{"Space", "Toggle state"}, {"Alt+L", "Focus toggle"}]
    })

    # Focus ring is configured during application initialization
    # (via UXRefinement.enable_feature(:focus_ring, ...))
  end

  # Helper to toggle accessibility settings
  defp toggle_accessibility_setting(setting, state) do
    key = [:accessibility, setting]
    current_value = UserPreferences.get(key) || false
    new_value = !current_value

    # UserPreferences.put(key, new_value) # Persist the change - The Accessibility setters should handle this via Preferences

    # Use the specific setter from Accessibility module
    # These setters should ideally update UserPreferences internally
    case setting do
      :high_contrast -> Accessibility.set_high_contrast(new_value)
      :reduced_motion -> Accessibility.set_reduced_motion(new_value)
      :large_text -> Accessibility.set_large_text(new_value)
    end

    Accessibility.announce(
      "#{setting |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()} #{if new_value, do: "enabled", else: "disabled"}.",
      [],
      UserPreferences
    )

    # Return the standard update tuple
    {state, []}
  end

  # Helper to retrieve hint text (basic implementation)
  defp get_hint(component_id, level, default) do
    UXRefinement.get_component_hint(component_id, level) || default
  end

  defp render_help_dialog do
    View.box style: [border: :double, padding: 1] do
      [
        View.text("Accessibility Features", style: [:bold]),
        View.text("Screen Reader Support"),
        View.text("High Contrast Mode"),
        View.text("Keyboard Navigation"),
        View.text("Focus Management"),
        View.text("ARIA Attributes")
      ]
    end
  end
end
