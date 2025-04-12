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
  alias Raxol.Core.Accessibility
  alias Raxol.Core.FocusManager
  alias Raxol.Components.FocusRing

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
    _ = UXRefinement.enable_feature(:focus_ring)
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

    # Configure focus ring with animation
    FocusRing.configure(
      style: :solid,
      color: :blue,
      animation: :pulse,
      transition_effect: :fade
    )

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
    # Get the current state
    high_contrast_enabled = Accessibility.high_contrast_enabled?()

    # Toggle the state
    new_state = !high_contrast_enabled

    # Apply the change
    Accessibility.set_high_contrast(new_state)

    # Announce the change
    _message =
      if new_state do
        "High contrast mode enabled. Colors have been adjusted for better visibility."
      else
        "High contrast mode disabled. Standard color scheme restored."
      end

    # UXRefinement.announce(_message, priority: :medium)
  end

  defp simulate_toggle_reduced_motion do
    # Get the current state
    reduced_motion_enabled = Accessibility.reduced_motion_enabled?()

    # Toggle the state
    new_state = !reduced_motion_enabled

    # Apply the change
    Accessibility.set_reduced_motion(new_state)

    # Announce the change
    _message =
      if new_state do
        "Reduced motion enabled. Animations have been minimized."
      else
        "Reduced motion disabled. Standard animations restored."
      end

    # UXRefinement.announce(_message, priority: :medium)
  end

  defp simulate_toggle_large_text do
    # Get the current state
    large_text_enabled = Accessibility.large_text_enabled?()

    # Toggle the state
    new_state = !large_text_enabled

    # Apply the change
    Accessibility.set_large_text(new_state)

    # Announce the change
    _message =
      if new_state do
        "Large text enabled. Text size increased to #{Accessibility.get_text_scale()} times normal size."
      else
        "Large text disabled. Standard text size restored."
      end

    # UXRefinement.announce(_message, priority: :medium)
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
    # Get current accessibility settings
    high_contrast = Accessibility.high_contrast_enabled?()
    reduced_motion = Accessibility.reduced_motion_enabled?()
    large_text = Accessibility.large_text_enabled?()

    # Get color scheme
    colors = Accessibility.get_color_scheme()

    # Format color values for announcement
    background_color = format_color_for_announcement(colors.background)
    foreground_color = format_color_for_announcement(colors.foreground)

    # Create message about current theme
    _theme_message =
      "Current theme settings: " <>
        "High contrast is #{if high_contrast, do: "enabled", else: "disabled"}. " <>
        "Reduced motion is #{if reduced_motion, do: "enabled", else: "disabled"}. " <>
        "Large text is #{if large_text, do: "enabled", else: "disabled"}. " <>
        "Using #{background_color} background and #{foreground_color} text."

    # Announce theme information (UXRefinement.announce is undefined)
    # UXRefinement.announce(_theme_message, priority: :medium) # Function undefined
  end

  defp format_color_for_announcement(color) do
    case color do
      :black -> "black"
      :white -> "white"
      :red -> "red"
      :green -> "green"
      :blue -> "blue"
      :yellow -> "yellow"
      :cyan -> "cyan"
      :magenta -> "magenta"
      {:rgb, r, g, b} -> "RGB color #{r}, #{g}, #{b}"
      _ -> "custom color"
    end
  end
end
