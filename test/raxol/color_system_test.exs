defmodule Raxol.ColorSystemTest do
  use ExUnit.Case, async: false
  import Raxol.AccessibilityTestHelpers

  alias Raxol.Core.Accessibility
  alias Raxol.Core.UserPreferences
  alias Raxol.Style.Colors.PaletteManager, as: PaletteManager
  alias Raxol.Style.Colors.System, as: ColorSystem
  alias Raxol.Animation.Framework, as: Framework
  require Raxol.Core.Runtime.Log

  setup do
    # Start UserPreferences with a test-specific name
    local_user_prefs_name = __MODULE__.UserPreferences
    user_prefs_opts = [name: local_user_prefs_name, test_mode?: true]

    # Check if UserPreferences is already started
    case start_supervised({UserPreferences, user_prefs_opts}) do
      {:ok, _pid} ->
        :ok

      {:error, {:already_started, _pid}} ->
        :ok
    end

    # Initialize ColorSystem
    ColorSystem.init()

    # Register the standard theme for testing
    standard_theme =
      Raxol.UI.Theming.Theme.new(%{
        id: :standard,
        name: "Standard",
        colors: %{
          primary: Raxol.Style.Colors.Color.from_hex("#0077CC"),
          secondary: Raxol.Style.Colors.Color.from_hex("#666666"),
          background: Raxol.Style.Colors.Color.from_hex("#FFFFFF"),
          foreground: Raxol.Style.Colors.Color.from_hex("#000000"),
          accent: Raxol.Style.Colors.Color.from_hex("#FF9900"),
          error: Raxol.Style.Colors.Color.from_hex("#CC0000"),
          success: Raxol.Style.Colors.Color.from_hex("#009900"),
          warning: Raxol.Style.Colors.Color.from_hex("#FF9900"),
          info: Raxol.Style.Colors.Color.from_hex("#0099CC"),
          surface: Raxol.Style.Colors.Color.from_hex("#F5F5F5")
        }
      })

    Raxol.UI.Theming.Theme.register(standard_theme)

    # Register the dark theme for testing
    dark_theme =
      Raxol.UI.Theming.Theme.new(%{
        id: :dark,
        name: "Dark",
        colors: %{
          primary: Raxol.Style.Colors.Color.from_hex("#90CAF9"),
          secondary: Raxol.Style.Colors.Color.from_hex("#B0BEC5"),
          background: Raxol.Style.Colors.Color.from_hex("#1E1E1E"),
          foreground: Raxol.Style.Colors.Color.from_hex("#FFFFFF"),
          accent: Raxol.Style.Colors.Color.from_hex("#4A9CD5"),
          error: Raxol.Style.Colors.Color.from_hex("#FF5555"),
          success: Raxol.Style.Colors.Color.from_hex("#50FA7B"),
          warning: Raxol.Style.Colors.Color.from_hex("#FFB86C"),
          info: Raxol.Style.Colors.Color.from_hex("#0099CC"),
          surface: Raxol.Style.Colors.Color.from_hex("#2D2D2D")
        }
      })

    Raxol.UI.Theming.Theme.register(dark_theme)

    # Reset relevant prefs before each test
    UserPreferences.set(
      "accessibility.high_contrast",
      false,
      local_user_prefs_name
    )

    Accessibility.set_high_contrast(false, local_user_prefs_name)

    UserPreferences.set(
      "accessibility.screen_reader",
      true,
      local_user_prefs_name
    )

    UserPreferences.set(
      "accessibility.silence_announcements",
      false,
      local_user_prefs_name
    )

    # Wait for preferences to be applied
    assert_receive {:preferences_applied, _}, 100

    on_exit(fn ->
      # Cleanup
      File.rm(Raxol.Core.Preferences.Persistence.preferences_path())
    end)

    :ok
  end

  describe "ColorSystem with accessibility integration" do
    test "applies high contrast mode to theme colors" do
      # Subscribe to both theme change and high contrast events
      {:ok, ref} =
        Raxol.Core.Events.Manager.subscribe([
          :theme_changed,
          :high_contrast_changed
        ])

      # Apply a theme
      ColorSystem.apply_theme(:standard)

      assert_receive {:event,
                      {:theme_changed,
                       %{theme: _theme, high_contrast: _high_contrast}}},
                     100

      # Get the primary color before high contrast
      normal_primary = ColorSystem.get_color(:primary)

      # Raxol.Core.Runtime.Log.info("[Test Log] Normal primary: #{inspect(normal_primary)}")

      # Enable high contrast mode
      Accessibility.set_high_contrast(true)
      # Wait for high contrast change to be applied
      assert_receive {:event, {:high_contrast_changed, true}}, 100

      # Get the primary color after high contrast
      high_contrast_primary = ColorSystem.get_color(:primary)

      # Raxol.Core.Runtime.Log.info("[Test Log] High contrast primary: #{inspect(high_contrast_primary)}")

      # Verify colors are different in high contrast mode
      assert normal_primary != high_contrast_primary

      # Get the background color (also after high contrast is enabled)
      background = ColorSystem.get_color(:background)

      # Cleanup subscription
      Raxol.Core.Events.Manager.unsubscribe(ref)

      # Raxol.Core.Runtime.Log.info("[Test Log] Background (post high-contrast): #{inspect(background)}")

      # Ensure Raxol.Style.Colors.Utilities is available or use the test helper's path
      _ratio =
        Raxol.Style.Colors.Utilities.contrast_ratio(
          high_contrast_primary,
          background
        )

      # Raxol.Core.Runtime.Log.info("[Test Log] Calculated contrast ratio for high_contrast_primary vs background: #{inspect(ratio_for_log)}")

      assert_sufficient_contrast(high_contrast_primary, background)
    end

    test "announces theme changes to screen readers" do
      # Initialize accessibility system for testing
      Accessibility.enable([screen_reader: true], __MODULE__.UserPreferences)

      # Ensure queue is clear before test
      Process.put(:accessibility_announcements, [])

      # Set the theme preference
      UserPreferences.set(:theme, :dark, __MODULE__.UserPreferences)

      # Manually apply the theme to trigger the event handler -> announce
      ColorSystem.apply_theme(:dark)

      # Wait a moment for the event to be processed
      Process.sleep(50)

      # Get announcements directly from the process dictionary queue
      announcements = Process.get(:accessibility_announcements, [])

      # Assert announcement was made (should contain theme name)
      assert Enum.any?(announcements, fn announcement ->
               announcement.message == "Theme changed to dark"
             end),
             "Expected announcement \"Theme changed to dark\" not found in #{inspect(announcements)}"
    end

    test "maintains user color preferences" do
      # Set a user preference for accent color
      UserPreferences.set(:accent_color, "#FF5722", __MODULE__.UserPreferences)

      # Save preferences
      UserPreferences.save!(__MODULE__.UserPreferences)

      # Reset preferences to defaults
      Process.put(:user_preferences, %{})

      # Load preferences (Not needed - loaded on init)
      # UserPreferences.load()

      # Verify preference was maintained
      # assert UserPreferences.get([:theme, :accent_color]) == "#FF5722"
      # Fixed path
      assert UserPreferences.get(:accent_color, __MODULE__.UserPreferences) ==
               "#FF5722"
    end

    test "generates accessible color scales" do
      # Generate a color scale
      scale = PaletteManager.generate_scale("#0077CC", 5)

      # Get dark background color
      dark_bg = "#121212"

      # Verify each color in the scale has sufficient contrast with the background
      Enum.each(scale, fn color ->
        ratio = calculate_contrast_ratio(color, dark_bg)

        # ratio is already a float, no need to parse
        ratio_value = ratio

        # Verify contrast is at least 3.0 (AA for large text)
        assert ratio_value >= 3.0,
               "Color #{color} has insufficient contrast with dark background (Ratio: #{ratio_value})"
      end)
    end

    test "adapts focus ring color for high contrast mode" do
      # Initialize a default focus ring state
      initial_state =
        Raxol.UI.Components.FocusRing.init(%{
          # Example position
          position: {10, 5, 20, 3},
          color: :blue,
          high_contrast: false
        })

      # Render with initial state
      initial_render = Raxol.UI.Components.FocusRing.render(initial_state, %{})
      initial_color = get_in(initial_render, [:attrs, :style, :border_color])
      assert initial_color == :blue

      # Simulate high contrast mode by updating state
      high_contrast_state = %{initial_state | high_contrast: true}

      # Render with high contrast state
      high_contrast_render =
        Raxol.UI.Components.FocusRing.render(high_contrast_state, %{})

      high_contrast_color =
        get_in(high_contrast_render, [:attrs, :style, :border_color])

      # Verify high contrast color is different (e.g., white)
      # Based on internal render logic
      assert high_contrast_color == :white
      assert high_contrast_color != initial_color
    end

    test "color system integrates with user preferences" do
      # Test theme application with different high contrast settings
      # --- Test 1: Apply dark theme without high contrast ---
      ColorSystem.apply_theme(:dark, high_contrast: false)

      # Verify standard dark theme color
      assert ColorSystem.get_color(:accent) == "#4A9CD5",
             "Expected dark theme accent color"

      refute Accessibility.get_option(
               :high_contrast,
               __MODULE__.UserPreferences,
               false
             )

      # --- Test 2: Apply dark theme WITH high contrast ---
      ColorSystem.apply_theme(:dark, high_contrast: true)

      # Verify colors returned by ColorSystem respect high contrast
      accent = ColorSystem.get_color(:accent)
      background = ColorSystem.get_color(:background)

      # Verify colors change in high contrast mode
      assert accent != "#4A9CD5",
             "Expected accent color to change in high contrast mode"

      assert background != "#1E1E1E",
             "Expected background color to change in high contrast mode"
    end

    test "themes have sufficient contrast for accessibility" do
      # Test all standard themes
      themes = [:standard, :dark, :high_contrast]

      Enum.each(themes, fn theme ->
        # Apply theme
        ColorSystem.apply_theme(theme)

        # Get foreground and background colors
        foreground = ColorSystem.get_color(:foreground)
        background = ColorSystem.get_color(:background)

        # Verify contrast
        assert_sufficient_contrast(foreground, background)
      end)
    end

    test "color system respects reduced motion settings" do
      # Set reduced motion through user preferences
      UserPreferences.set(
        "accessibility.reduced_motion",
        true,
        __MODULE__.UserPreferences
      )

      # Re-initialize Framework to pick up the preference
      Framework.init(%{}, __MODULE__.UserPreferences)

      # Get the setting directly from the process dictionary
      settings = Process.get(:animation_framework_settings, %{})
      reduced_motion_enabled = Map.get(settings, :reduced_motion, false)

      # Verify animation framework respects this setting
      assert reduced_motion_enabled == true

      # Restore previous state (set pref to false and re-init)
      UserPreferences.set(
        "accessibility.reduced_motion",
        false,
        __MODULE__.UserPreferences
      )

      Framework.init(%{}, __MODULE__.UserPreferences)
      settings_after = Process.get(:animation_framework_settings, %{})
      refute Map.get(settings_after, :reduced_motion, false)
    end
  end

  # Helper functions

  defp calculate_contrast_ratio(color1, color2) do
    # Use the proper Utilities.contrast_ratio function
    Raxol.Style.Colors.Utilities.contrast_ratio(color1, color2)
  end
end
