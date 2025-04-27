defmodule Raxol.Examples.AccessibilityDemo do
  @moduledoc """
  Demo of accessibility features in Raxol.

  This example demonstrates:
  - Screen reader announcements
  - High contrast mode
  - Keyboard navigation with focus management
  - Reduced motion
  - Comprehensive hints
  - Large text support
  - Theme integration
  """

  alias Raxol.Core.UXRefinement
  alias Raxol.Core.FocusManager
  alias Raxol.Core.UserPreferences

  @doc """
  Start the accessibility demo.

  ## Examples

      iex> Raxol.Examples.AccessibilityDemo.run()
      :ok
  """
  def run do
    # Initialize UX refinement
    UXRefinement.init()

    # Enable required features
    _ = UXRefinement.enable_feature(:focus_management)
    _ = UXRefinement.enable_feature(:keyboard_navigation)
    _ = UXRefinement.enable_feature(:hints)
    _ = UXRefinement.enable_feature(:accessibility)

    # Setup the demo UI
    setup_demo_ui()

    # Main event loop
    event_loop()

    :ok
  end

  # Private functions

  defp setup_demo_ui do
    # Register components for focus management
    FocusManager.register_focusable("search_button", tab_order: 1)
    FocusManager.register_focusable("settings_button", tab_order: 2)
    FocusManager.register_focusable("help_button", tab_order: 3)
    FocusManager.register_focusable("high_contrast_toggle", tab_order: 4)
    FocusManager.register_focusable("reduced_motion_toggle", tab_order: 5)
    FocusManager.register_focusable("large_text_toggle", tab_order: 6)

    # Register hints
    UXRefinement.register_component_hint("search_button", %{
      basic: "Search for content",
      detailed: "Search for content in the application using keywords",
      examples: "Type keywords like 'settings' or 'help'",
      shortcuts: [
        {"Enter", "Execute search"},
        {"Alt+S", "Focus search"}
      ]
    })

    UXRefinement.register_component_hint("settings_button", %{
      basic: "Open settings",
      detailed: "Access application settings and preferences",
      shortcuts: [
        {"Enter", "Open settings"},
        {"Alt+T", "Focus settings"}
      ]
    })

    UXRefinement.register_component_hint("help_button", %{
      basic: "Get help",
      detailed: "Access help documentation and guides",
      shortcuts: [
        {"Enter", "Open help"},
        {"Alt+H", "Focus help"}
      ]
    })

    UXRefinement.register_component_hint("high_contrast_toggle", %{
      basic: "Toggle high contrast mode",
      detailed: "Enable or disable high contrast mode for better visibility",
      shortcuts: [
        {"Space", "Toggle state"},
        {"Alt+C", "Focus toggle"}
      ]
    })

    UXRefinement.register_component_hint("reduced_motion_toggle", %{
      basic: "Toggle reduced motion",
      detailed: "Enable or disable animations for reduced motion",
      shortcuts: [
        {"Space", "Toggle state"},
        {"Alt+M", "Focus toggle"}
      ]
    })

    UXRefinement.register_component_hint("large_text_toggle", %{
      basic: "Toggle large text",
      detailed: "Enable or disable larger text for better readability",
      shortcuts: [
        {"Space", "Toggle state"},
        {"Alt+L", "Focus toggle"}
      ]
    })

    # Configure the focus ring - Needs update based on FocusRing API
    # FocusRing.configure(
    #   style: :dotted,
    #   color: :cyan,
    #   animation: :pulse,
    #   offset: 1
    # )

    # Make an initial announcement
    # UXRefinement.announce("Accessibility demo loaded. Use Tab to navigate between components.", priority: :high)

    # Set initial focus
    FocusManager.set_focus("search_button")
  end

  defp event_loop do
    # In a real application, this would be a proper event loop
    # For this demo, we'll simulate some events

    # Simulate tab navigation
    Process.sleep(1000)
    simulate_tab_press()

    # Simulate activating a button
    Process.sleep(1000)
    simulate_enter_press()

    # Simulate toggling high contrast
    Process.sleep(1000)
    simulate_toggle_high_contrast()

    # Simulate toggling reduced motion
    Process.sleep(1000)
    simulate_toggle_reduced_motion()

    # Simulate toggling large text
    Process.sleep(1000)
    simulate_toggle_large_text()

    # Simulate showing a hint
    Process.sleep(1000)
    show_current_hint()

    # Display current theme information
    Process.sleep(1000)
    show_current_theme_info()

    # End the demo
    Process.sleep(3000)

    # UXRefinement.announce("Demo complete. Thank you for exploring the accessibility features.",
    #                       priority: :high, interrupt: true)
  end

  defp simulate_tab_press do
    current_focus = FocusManager.get_current_focus()
    next_focus = FocusManager.get_next_focusable(current_focus)

    if next_focus do
      FocusManager.set_focus(next_focus)
      # UXRefinement.announce("Moved focus to #{next_focus}")
    end
  end

  defp simulate_enter_press do
    current_focus = FocusManager.get_current_focus()

    case current_focus do
      "search_button" ->
        # UXRefinement.announce("Search activated", priority: :high)
        :ok

      "settings_button" ->
        # UXRefinement.announce("Settings opened", priority: :high)
        :ok

      "help_button" ->
        # UXRefinement.announce("Help opened", priority: :high)
        :ok

      _ ->
        nil
    end
  end

  defp simulate_toggle_high_contrast do
    # Read using UserPreferences
    current_state = UserPreferences.get(pref_key(:high_contrast)) || false
    # Use specific setter
    Raxol.Core.Accessibility.set_high_contrast(not current_state)
    IO.puts("Simulated toggle high contrast -> #{not current_state}")
    show_current_theme_info()
  end

  defp simulate_toggle_reduced_motion do
    # Read using UserPreferences
    current_state = UserPreferences.get(pref_key(:reduced_motion)) || false
    # Use specific setter
    Raxol.Core.Accessibility.set_reduced_motion(not current_state)
    IO.puts("Simulated toggle reduced motion -> #{not current_state}")
    show_current_theme_info()
  end

  defp simulate_toggle_large_text do
    # Read using UserPreferences
    current_state = UserPreferences.get(pref_key(:large_text)) || false
    # Use specific setter
    Raxol.Core.Accessibility.set_large_text(not current_state)
    IO.puts("Simulated toggle large text -> #{not current_state}")
    show_current_theme_info()
  end

  defp show_current_hint do
    current_focus = FocusManager.get_current_focus()

    if current_focus do
      # Get the basic hint
      hint = UXRefinement.get_hint(current_focus)

      if hint do
        # In a real app, this would be displayed on screen
        # UXRefinement.announce("Hint: #{hint}", priority: :low)
      end

      # Get detailed hint
      detailed_hint = UXRefinement.get_component_hint(current_focus, :detailed)

      if detailed_hint do
        # In a real app, this would be displayed when requested
        Process.sleep(1500)
        # UXRefinement.announce("More info: #{detailed_hint}", priority: :low)
      end
    end
  end

  defp show_current_theme_info do
    # Read using UserPreferences
    high_contrast = UserPreferences.get(pref_key(:high_contrast)) || false
    reduced_motion = UserPreferences.get(pref_key(:reduced_motion)) || false
    large_text = UserPreferences.get(pref_key(:large_text)) || false

    # Get base theme ID (assuming a preference key like 'ui.theme', default to :default)
    base_theme_id = UserPreferences.get("ui.theme") || :default
    # Fetch the base theme struct
    base_theme = Raxol.UI.Theming.Theme.get(base_theme_id) || Raxol.UI.Theming.Theme.default_theme()

    # Get the active variant identifier (:default or :high_contrast)
    active_variant_id = Raxol.Core.Accessibility.ThemeIntegration.get_active_variant()

    # Get the variant overrides from the theme struct
    variant_overrides = Map.get(base_theme.variants, active_variant_id, %{})

    # Deep merge the overrides onto the base theme to get the final active theme
    # NOTE: Needs a deep merge utility. Assuming Map.merge for shallow merge for now.
    # A proper implementation might require a utility function.
    active_theme_struct = Map.merge(base_theme, variant_overrides)

    IO.puts("\n--- Current Theme Info ---")
    IO.inspect(active_theme_struct, label: "Active Theme (#{active_variant_id})")
    IO.puts("High Contrast:  #{high_contrast}")
    IO.puts("Reduced Motion: #{reduced_motion}")
    IO.puts("Large Text:     #{large_text}")
    IO.puts("--------------------------\n")
  end

  # Helper to mimic internal pref_key logic if needed
  defp pref_key(key), do: "accessibility.#{key}"
end
