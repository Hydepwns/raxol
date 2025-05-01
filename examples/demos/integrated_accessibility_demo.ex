defmodule Raxol.Examples.IntegratedAccessibilityDemo do
  @moduledoc """
  An integrated demo showcasing Raxol's accessibility features working together
  with color system, animation framework, and internationalization.
  """

  require Logger
  require Raxol.View.Elements
  alias Raxol.Core.UserPreferences
  alias Raxol.Core.I18n
  alias Raxol.View.Elements, as: UI
  alias Raxol.Docs.TutorialViewer

  @demo_sections [
    :welcome,
    :color_system,
    :animation,
    :internationalization,
    :user_preferences,
    :keyboard_shortcuts,
    :tutorials
  ]

  @available_themes [:standard, :dark, :light, :solarized_dark, :solarized_light] # Example themes
  @available_locales ["en", "es", "fr", "de"] # Example locales

  # Define the struct based on @initial_state fields
  defstruct active_section: :welcome,
            theme: :standard,
            high_contrast: false,
            reduced_motion: false,
            locale: "en",
            animation_speed: :normal,
            preferences_saved: false,
            focus_index: 0,
            sections: @demo_sections, # Use the module attribute defined above
            sample_animation: nil,
            loading_progress: 0,
            animation_frame: 0, # Added for animation section
            shortcuts: %{ # Corresponds to @initial_state.shortcuts
              "Alt+H" => "Toggle High Contrast",
              "Alt+M" => "Toggle Reduced Motion",
              "Alt+T" => "Switch Theme",
              "Alt+L" => "Switch Language",
              "Alt+S" => "Save Preferences",
              "Ctrl+Q" => "Exit Demo"
            }

  # Keep the Application behaviour implementation
  @behaviour Raxol.Core.Runtime.Application

  @impl Raxol.Core.Runtime.Application
  def init(_opts) do
    # Initialize state using the default values from defstruct
    # In a real app, you might load preferences here.
    # initial_state = %__MODULE__{} # Uses defaults from defstruct
    # Load preferences, falling back to defaults
    initial_state = %__MODULE__{
      theme: UserPreferences.get("demo.theme") || :standard, # Use get/1 and || for default
      locale: UserPreferences.get("demo.locale") || "en", # Use get/1 and || for default
      high_contrast: UserPreferences.get("demo.high_contrast") || false, # Use get/1 and || for default
      reduced_motion: UserPreferences.get("demo.reduced_motion") || false # Use get/1 and || for default
    }
    {initial_state, []}
  end

  @impl Raxol.Core.Runtime.Application
  def update(msg, state) do
    # Handle messages sent via :send_update from handle_event
    new_state =
      case msg do
        :toggle_high_contrast ->
          %{state | high_contrast: not state.high_contrast}

        :toggle_reduced_motion ->
          %{state | reduced_motion: not state.reduced_motion}

        :navigate_prev_section ->
          navigate_section(state, -1)

        :navigate_next_section ->
          navigate_section(state, 1)

        :switch_theme ->
          cycle_option(state, :theme, @available_themes)

        :switch_language ->
          cycle_option(state, :locale, @available_locales)

        :save_preferences ->
          # Logger.info("Preferences saved (simulated).")
          # %{state | preferences_saved: true}
          UserPreferences.set("demo.theme", state.theme)
          UserPreferences.set("demo.locale", state.locale)
          UserPreferences.set("demo.high_contrast", state.high_contrast)
          UserPreferences.set("demo.reduced_motion", state.reduced_motion)
          Logger.info("Preferences saved via UserPreferences.")
          %{state | preferences_saved: true} # Keep flag for UI feedback

        :advance_animation_frame ->
          new_frame = rem(state.animation_frame + 1, 100) # Simple counter 0-99
          %{state | animation_frame: new_frame}

        # Handle other messages if needed
        _ ->
          state
      end

    {new_state, []} # Return updated state and potentially new commands
  end

  # Helper function to cycle through a list of options
  defp cycle_option(state, key, options) do
    current_value = Map.get(state, key)
    current_index = Enum.find_index(options, &(&1 == current_value))

    if is_nil(current_index) do
      Logger.warning("Could not find index for current \#{key}: \#{current_value}")
      state
    else
      num_options = Enum.count(options)
      new_index = rem(current_index + 1 + num_options, num_options)
      new_value = Enum.at(options, new_index)
      Map.put(state, key, new_value)
    end
  end

  # Helper function for section navigation
  defp navigate_section(state, direction) do
    sections = state.sections
    current_index = Enum.find_index(sections, &(&1 == state.active_section))

    if is_nil(current_index) do
      # Should not happen if active_section is always valid
      Logger.warning("Could not find index for active section: \#{state.active_section}")
      state # Return unchanged state
    else
      num_sections = Enum.count(sections)
      # Calculate new index with wrap-around
      new_index = rem(current_index + direction + num_sections, num_sections)
      new_active_section = Enum.at(sections, new_index)
      %{state | active_section: new_active_section}
    end
  end

  @impl Raxol.Core.Runtime.Application
  def handle_event(event) do
    # State is managed by Dispatcher in this arity
    # Return list of commands based on event

    case event do
      # Handle Ctrl+Q for exiting
      {:key, ~c"q", [:control]} ->
        [{:shutdown, :user_quit}]

      # Handle Alt+H to toggle high contrast
      {:key, ~c"h", [:alt]} ->
        [{:send_update, :toggle_high_contrast}]

      # Handle Alt+M to toggle reduced motion
      {:key, ~c"m", [:alt]} ->
        [{:send_update, :toggle_reduced_motion}]

      # Handle Arrow Up for previous section
      {:key, :arrow_up, []} ->
        [{:send_update, :navigate_prev_section}]

      # Handle Arrow Down for next section
      {:key, :arrow_down, []} ->
        [{:send_update, :navigate_next_section}]

      # Handle Alt+T to switch theme
      {:key, ~c"t", [:alt]} ->
        [{:send_update, :switch_theme}]

      # Handle Alt+L to switch language
      {:key, ~c"l", [:alt]} ->
        [{:send_update, :switch_language}]

      # Handle Alt+S to save preferences (marks as saved for now)
      {:key, ~c"s", [:alt]} ->
        [{:send_update, :save_preferences}]

      # Ignore other events for now
      _ ->
        []
    end
  end

  @impl Raxol.Core.Runtime.Application
  def handle_message(_msg, state), do: {state, []}

  @impl Raxol.Core.Runtime.Application
  def handle_tick({:animation_tick, _timestamp}) do
    # State is managed by Dispatcher in this arity
    # Return a command to update the animation frame
    [{:send_update, :advance_animation_frame}]
  end
  def handle_tick(_) do
    # Ignore other ticks if any
    []
  end

  @impl Raxol.Core.Runtime.Application
  def subscriptions(_state) do
    # Request a tick every 100ms, tagged with :animation_tick
    [tick: {100, :animation_tick}]
  end

  @impl Raxol.Core.Runtime.Application
  def terminate(_reason, _state), do: :ok

  @impl Raxol.Core.Runtime.Application
  def view(state) do
    # Use Raxol.View.Elements DSL to build the view
    # Display active section and basic status information
    UI.box(direction: :column, padding: 1, border: :rounded) do
      # Top section: Active Section Name and Status
      UI.box(direction: :row, justify: :between) do
        UI.label("Active Section: #{state.active_section}")
        UI.box(direction: :row, gap: 2) do
          UI.label("[Theme: #{state.theme}]")
          UI.label("[Locale: #{state.locale}]")
          UI.label("[HC: #{state.high_contrast}]")
          UI.label("[RM: #{state.reduced_motion}]")
          UI.label("[Saved: #{state.preferences_saved}]")
        end
      end

      UI.label(String.duplicate("─", 80))

      # Main Content Area - Render based on active section
      UI.box(grow: 1, padding: {1, 0, 0, 0}) do
        render_section_content(state)
      end

      UI.label(String.duplicate("─", 80))

      # Footer: Basic instructions
      UI.label("Use ↑/↓ to navigate sections. Ctrl+Q to quit.")
    end
  end

  # --- Section Rendering Helpers ---

  defp render_section_content(state) do
    case state.active_section do
      :welcome -> render_welcome_section(state)
      :color_system -> render_color_system_section(state)
      :animation -> render_animation_section(state)
      :internationalization -> render_internationalization_section(state)
      :user_preferences -> render_user_preferences_section(state)
      :keyboard_shortcuts -> render_keyboard_shortcuts_section(state)
      :tutorials -> TutorialViewer()
      _ -> UI.label("Unknown section: \#{state.active_section}")
    end
  end

  defp render_welcome_section(_state) do
    UI.box(direction: :column, align: :center, gap: 1) do
      UI.label("Welcome to the Integrated Accessibility Demo!", style: :bold)
      UI.label("This demo showcases how various Raxol features work together.")
      UI.label("Navigate using the Up/Down arrow keys.")
      UI.label("Use shortcuts (Alt+H, Alt+M, etc.) to change settings.")
    end
  end

  defp render_color_system_section(state) do
    alias Raxol.Core.ColorSystem # Required for getting theme colors

    # Get color based on theme/accessibility settings
    get_color = fn role -> ColorSystem.get(role, %{theme: state.theme, high_contrast: state.high_contrast}) end

    UI.box(direction: :column, align: :start, gap: 1, width: :fill) do
      UI.label("Color System Features", style: :bold)
      UI.label("This section shows how elements adapt to the current theme and accessibility settings.")
      UI.label("Current Theme: \#{state.theme} | High Contrast: \#{state.high_contrast}")
      UI.label("Use Alt+T to cycle themes, Alt+H to toggle high contrast.")
      UI.label(String.duplicate("─", 80))

      UI.label("Sample Semantic Colors:")
      UI.box(direction: :row, gap: 2, padding: {1, 0, 0, 0}) do
        # Example boxes using semantic color roles
        UI.box(width: 15, height: 3, border: :single, style: [bg: get_color.(:primary)]) do
          UI.label(content: "Primary", align: :center, style: [fg: get_color.(:on_primary)])
        end
        UI.box(width: 15, height: 3, border: :single, style: [bg: get_color.(:secondary)]) do
          UI.label(content: "Secondary", align: :center, style: [fg: get_color.(:on_secondary)])
        end
        UI.box(width: 15, height: 3, border: :single, style: [bg: get_color.(:accent)]) do
          UI.label(content: "Accent", align: :center, style: [fg: get_color.(:on_accent)])
        end
        UI.box(width: 15, height: 3, border: :single, style: [bg: get_color.(:background)]) do
          UI.label(content: "Background", align: :center, style: [fg: get_color.(:text)])
        end
      end
    end
  end

  defp render_animation_section(state) do
    percentage = state.animation_frame # Frame is 0-99

    UI.box(direction: :column, align: :center, gap: 1) do
      UI.label(content: "Animation Example (Progress Bar)", style: :bold)
      UI.label(content: "Demonstrates timer ticks and respects Reduced Motion.")
      UI.label(content: "Reduced Motion: #{state.reduced_motion} (Toggle: Alt+M)")
      UI.label(content: " ")

      if state.reduced_motion do
        # Reduced Motion: Show text only
        UI.label(content: "Progress: #{percentage}%")
      else
        # Normal Motion: Show progress bar
        bar_width = 40 # Fixed width for the bar
        filled_width = round(bar_width * percentage / 100)
        empty_width = bar_width - filled_width

        filled_char = "█"
        empty_char = "░"

        bar = String.duplicate(filled_char, filled_width) <> String.duplicate(empty_char, empty_width)

        UI.box(direction: :row, gap: 1) do
          UI.label("[#{bar}]")
          UI.label("#{percentage}%")
        end
      end
    end
  end

  defp render_internationalization_section(state) do
    # Use I18n.t/2 for translations
    t = fn key -> I18n.t(key, locale: state.locale) end

    UI.box(direction: :column, align: :start, gap: 1, width: :fill) do
      UI.label(t.("demo.i18n.settings"), style: :bold)
      UI.label("Current Locale: #{state.locale}")
      UI.label("(Translations via Raxol.Core.I18n)")
      UI.label(String.duplicate("─", 80))

      UI.label(t.("demo.i18n.welcome"))
      UI.label(t.("demo.i18n.description"))
    end
  end

  defp render_user_preferences_section(state) do
    UI.box(direction: :column, align: :start, gap: 1, width: :fill) do
      UI.label("User Preferences Management", style: :bold)
      UI.label("This section shows the current preference settings managed by the application state.")
      UI.label("Preferences are loaded on startup and saved using Raxol.Core.UserPreferences.")
      UI.label(String.duplicate("─", 80))

      UI.label(content: "Current Settings (Loaded at start):")
      UI.label(~s"  Theme:          #{state.theme}")
      UI.label(~s"  Locale:         #{state.locale}")
      UI.label(~s"  High Contrast:  #{state.high_contrast}")
      UI.label(~s"  Reduced Motion: #{state.reduced_motion}")
      UI.label(String.duplicate("─", 80))

      UI.label(content: "Use shortcuts (Alt+T, Alt+L, Alt+H, Alt+M) to change settings.")
      UI.label(content: "Press Alt+S to simulate saving these preferences.")
      UI.label(content: "Preferences Saved Status: \#{state.preferences_saved}", style: (if state.preferences_saved, do: :bold))
    end
  end

  defp render_keyboard_shortcuts_section(state) do
    UI.box(direction: :column, align: :start, gap: 1, width: :fill) do
      UI.label("Keyboard Shortcut Overview", style: :bold)
      UI.label("Available shortcuts in this demo:")
      UI.label(String.duplicate("─", 80))

      # Iterate over the shortcuts map and display them
      Enum.map(state.shortcuts, fn {key, description} ->
        UI.box(direction: :row, width: :fill, justify: :between) do
          UI.label(key, width: 15)
          UI.label(description)
        end
      end)
    end
  end
end
