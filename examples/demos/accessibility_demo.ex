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

  # Use the Application behaviour
  use Raxol.Core.Runtime.Application

  # Add necessary aliases and requires
  require Raxol.Core.Runtime.Log
  require Raxol.View.Elements
  alias Raxol.View.Elements, as: UI
  alias Raxol.Core.Accessibility
  alias Raxol.Core.FocusManager
  alias Raxol.Core.UserPreferences
  # Re-added alias for hints
  alias Raxol.Core.UXRefinement

  # Define application state
  # Initial focus
  defstruct focused_element: "search_button",
            message: "Accessibility Demo. Press Tab/Shift+Tab, Enter/Space.",
            # Store accessibility settings in state for display? Or read from UserPreferences?
            # Reading directly from UserPreferences in view/update might be simpler.
            id: :accessibility_demo

  # --- Application Behaviour Callbacks ---

  @impl Raxol.Core.Runtime.Application
  def init(_opts) do
    Raxol.Core.Runtime.Log.info("Initializing AccessibilityDemo...")

    # Perform initial setup (moved from setup_demo_ui)
    setup_focus_and_hints()

    # Make an initial announcement
    Accessibility.announce("Accessibility demo loaded. Use Tab to navigate.",
      priority: :high
    )

    # Set initial focus (handled by initial state struct)
    # Ensure FocusManager knows the initial focus
    FocusManager.set_focus("search_button")

    initial_state = %__MODULE__{}
    {:ok, initial_state}
  end

  @impl Raxol.Core.Runtime.Application
  def update({:keyboard_event, %{key: :tab, shift: false}}, state) do
    # Handle Tab: Move focus forward
    current_focus = state.focused_element
    next_focus = FocusManager.get_next_focusable(current_focus)

    if next_focus do
      FocusManager.set_focus(next_focus)

      Accessibility.announce(
        "Focus: #{get_hint(next_focus, :basic, next_focus)}"
      )

      {:ok, %{state | focused_element: next_focus}}
    else
      # Cycle focus back to the first element
      first_focus = FocusManager.get_first_focusable()

      if first_focus do
        FocusManager.set_focus(first_focus)

        Accessibility.announce(
          "Focus: #{get_hint(first_focus, :basic, first_focus)}"
        )

        {%{state | focused_element: first_focus}, []}
      else
        # No focusable elements
        {state, []}
      end
    end
  end

  def update({:keyboard_event, %{key: :tab, shift: true}}, state) do
    # Handle Shift+Tab: Move focus backward
    current_focus = state.focused_element
    prev_focus = FocusManager.get_previous_focusable(current_focus)

    if prev_focus do
      FocusManager.set_focus(prev_focus)

      Accessibility.announce(
        "Focus: #{get_hint(prev_focus, :basic, prev_focus)}"
      )

      {:ok, %{state | focused_element: prev_focus}}
    else
      # Cycle focus back to the last element
      last_focus = FocusManager.get_last_focusable()

      if last_focus do
        FocusManager.set_focus(last_focus)

        Accessibility.announce(
          "Focus: #{get_hint(last_focus, :basic, last_focus)}"
        )

        {%{state | focused_element: last_focus}, []}
      else
        # No focusable elements
        {state, []}
      end
    end
  end

  def update({:keyboard_event, %{key: :enter}}, state) do
    # Handle Enter: Activate focused button
    case state.focused_element do
      "search_button" ->
        Accessibility.announce("Search action simulated.", priority: :high)
        {state, []}

      "settings_button" ->
        Accessibility.announce("Settings action simulated.", priority: :high)
        {state, []}

      "help_button" ->
        Accessibility.announce("Help action simulated.", priority: :high)
        {state, []}

      # Enter on checkbox does nothing here, use Space
      _ ->
        {state, []}
    end
  end

  # Check for space bar
  def update({:keyboard_event, %{key: " "}}, state) do
    # Handle Space: Toggle focused checkbox
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

  # Handle custom messages from UI elements (if added later)
  def update({:toggle, setting}, state) do
    toggle_accessibility_setting(setting, state)
  end

  def update({:activate, button_id}, state) do
    Accessibility.announce("#{button_id} activated via click.", priority: :high)
    {state, []}
  end

  def update({:keyboard_event, event}, state) do
    # Log other key events if needed
    Raxol.Core.Runtime.Log.debug("Ignoring Keyboard Event: #{inspect(event)}")
    {state, []}
  end

  def update(msg, state) do
    Raxol.Core.Runtime.Log.debug("Received unhandled update message: #{inspect(msg)}")
    {state, []}
  end

  @impl Raxol.Core.Runtime.Application
  def view(state) do
    # Add on_click/on_change handlers
    UI.box id: state.id, border: :rounded, padding: 1 do
      UI.column do
        [
          UI.label(content: state.message),
          UI.label(content: "Focused: #{state.focused_element}"),
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
              UserPreferences.get([:accessibility, :high_contrast]) || false,
            focused: state.focused_element == "high_contrast_toggle",
            on_change: {:toggle, :high_contrast}
          ),
          UI.checkbox(
            label: "Reduced Motion",
            id: "reduced_motion_toggle",
            checked:
              UserPreferences.get([:accessibility, :reduced_motion]) || false,
            focused: state.focused_element == "reduced_motion_toggle",
            on_change: {:toggle, :reduced_motion}
          ),
          UI.checkbox(
            label: "Large Text",
            id: "large_text_toggle",
            checked:
              UserPreferences.get([:accessibility, :large_text]) || false,
            focused: state.focused_element == "large_text_toggle",
            on_change: {:toggle, :large_text}
          )
        ]
      end
    end
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
    Raxol.Core.Runtime.Log.debug("Received unhandled message: #{inspect(message)}")
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
    Raxol.Core.Runtime.Log.info("Terminating AccessibilityDemo: #{inspect(reason)}")
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
      "#{setting |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()} #{if new_value, do: "enabled", else: "disabled"}."
    )

    # Return the standard update tuple
    {state, []}
  end

  # Helper to retrieve hint text (basic implementation)
  defp get_hint(component_id, level, default) do
    UXRefinement.get_component_hint(component_id, level) || default
  end
end
