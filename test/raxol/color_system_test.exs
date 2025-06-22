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

    {:ok, _pid} = start_supervised({UserPreferences, user_prefs_opts})

    # Reset relevant prefs before each test
    UserPreferences.set(
      "accessibility.high_contrast",
      false,
      local_user_prefs_name
    )

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
    assert_receive {:preferences_applied, ^local_user_prefs_name}, 100

    on_exit(fn ->
      # Cleanup
      File.rm(Raxol.Core.Preferences.Persistence.preferences_path())
    end)

    :ok
  end

  describe "ColorSystem with accessibility integration" do
    test "applies high contrast mode to theme colors" do
      # Apply a theme
      ColorSystem.apply_theme(:standard)
      assert_receive {:theme_changed, :standard}, 100

      # Get the primary color before high contrast
      normal_primary = ColorSystem.get_color(:primary)

      # Raxol.Core.Runtime.Log.info("[Test Log] Normal primary: #{inspect(normal_primary)}")

      # Enable high contrast mode
      Accessibility.set_high_contrast(true)
      # Wait for high contrast change to be applied
      assert_receive {:high_contrast_changed, true}, 100

      # Get the primary color after high contrast
      high_contrast_primary = ColorSystem.get_color(:primary)

      # Raxol.Core.Runtime.Log.info("[Test Log] High contrast primary: #{inspect(high_contrast_primary)}")

      # Verify colors are different in high contrast mode
      assert normal_primary != high_contrast_primary

      # Get the background color (also after high contrast is enabled)
      background = ColorSystem.get_color(:background)

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
      # Ensure queue is clear before test
      Process.put(:accessibility_announcements, [])

      # Set the theme preference
      UserPreferences.set(:theme, :dark)

      # Manually apply the theme to trigger the event handler -> announce
      ColorSystem.apply_theme(:dark)

      # Get announcements directly from the process dictionary queue
      announcements = Process.get(:accessibility_announcements, [])

      # Assert announcement was made (should contain theme name)
      # assert_announced("dark theme") # Remove spy assertion
      assert Enum.any?(announcements, fn announcement ->
               announcement.message == "Theme changed to dark"
             end),
             "Expected announcement \"Theme changed to dark\" not found in #{inspect(announcements)}"
    end

    test "maintains user color preferences" do
      # Set a user preference for accent color
      UserPreferences.set(:accent_color, "#FF5722")

      # Save preferences
      UserPreferences.save!()

      # Reset preferences to defaults
      Process.put(:user_preferences, %{})

      # Load preferences (Not needed - loaded on init)
      # UserPreferences.load()

      # Verify preference was maintained
      # assert UserPreferences.get([:theme, :accent_color]) == "#FF5722"
      # Fixed path
      assert UserPreferences.get(:accent_color) == "#FF5722"
    end

    test "generates accessible color scales" do
      # Generate a color scale
      scale = PaletteManager.generate_scale("#0077CC", 5)

      # Get dark background color
      dark_bg = "#121212"

      # Verify each color in the scale has sufficient contrast with the background
      Enum.each(scale, fn color ->
        ratio = calculate_contrast_ratio(color, dark_bg)

        # Convert ratio to float for comparison
        {ratio_value, _} = Float.parse(ratio)

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
      assert ColorSystem.get_color(:primary) == "#0d6efd",
             "Expected dark theme primary color"

      refute Accessibility.get_option(:high_contrast, false)

      # --- Test 2: Apply dark theme WITH high contrast ---
      ColorSystem.apply_theme(:dark, high_contrast: true)

      # Verify colors returned by ColorSystem respect high contrast
      primary = ColorSystem.get_color(:primary)
      background = ColorSystem.get_color(:background)

      # Verify colors change in high contrast mode
      assert primary != "#0d6efd",
             "Expected primary color to change in high contrast mode"

      assert background != "#212529",
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
      UserPreferences.set("accessibility.reduced_motion", true)

      # Re-initialize Framework to pick up the preference
      Framework.init()

      # Get the setting directly from the process dictionary
      settings = Process.get(:animation_framework_settings, %{})
      reduced_motion_enabled = Map.get(settings, :reduced_motion, false)

      # Verify animation framework respects this setting
      assert reduced_motion_enabled == true

      # Restore previous state (set pref to false and re-init)
      UserPreferences.set("accessibility.reduced_motion", false)
      Framework.init()
      settings_after = Process.get(:animation_framework_settings, %{})
      refute Map.get(settings_after, :reduced_motion, false)
    end
  end

  # Helper functions

  defp get_focus_ring_config do
    # Access focus ring configuration (implementation depends on how it's stored)
    Process.get(:focus_ring_config, %{})
  end

  defp calculate_contrast_ratio(color1, color2) do
    # Convert colors to relative luminance
    l1 = relative_luminance(color1)
    l2 = relative_luminance(color2)

    # Calculate contrast ratio
    ratio =
      if l1 > l2 do
        (l1 + 0.05) / (l2 + 0.05)
      else
        (l2 + 0.05) / (l1 + 0.05)
      end

    # Format to one decimal place
    :erlang.float_to_binary(ratio, decimals: 1)
  end

  defp relative_luminance(hex) do
    hex = String.replace(hex, ~r/^#/, "")
    {r, g, b} = parse_hex_components(hex)
    {r_lum, g_lum, b_lum} = calculate_luminance_components(r, g, b)

    0.2126 * r_lum + 0.7152 * g_lum + 0.0722 * b_lum
  end

  defp parse_hex_components(hex) do
    r = String.slice(hex, 0..1) |> String.to_integer(16)
    g = String.slice(hex, 2..3) |> String.to_integer(16)
    b = String.slice(hex, 4..5) |> String.to_integer(16)
    {r, g, b}
  end

  defp calculate_luminance_components(r, g, b) do
    r_srgb = r / 255
    g_srgb = g / 255
    b_srgb = b / 255

    r_lum = convert_to_linear(r_srgb)
    g_lum = convert_to_linear(g_srgb)
    b_lum = convert_to_linear(b_srgb)

    {r_lum, g_lum, b_lum}
  end

  defp convert_to_linear(value) do
    if value <= 0.03928 do
      value / 12.92
    else
      :math.pow((value + 0.055) / 1.055, 2.4)
    end
  end

  defp setup_accessibility_and_prefs() do
    # Ensure UserPreferences is started (might be redundant due to test_helper.exs)
    case Process.whereis(UserPreferences) do
      nil ->
        {:ok, pid} = UserPreferences.start_link([])
        pid

      pid when is_pid(pid) ->
        # Already started, return existing pid
        pid
    end
  end

  defp cleanup_accessibility_and_prefs(pid) when is_pid(pid) do
    # Attempt to stop the process started by this test setup.
    # Be cautious if this process is globally shared.
    ref = Process.monitor(pid)
    Process.exit(pid, :shutdown)
    # Wait for the process to exit, or timeout
    receive do
      {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
    after
      500 ->
        IO.puts(
          "Warning: UserPreferences process #{inspect(pid)} did not shut down cleanly in cleanup_accessibility_and_prefs"
        )
    end

    :ok
  catch
    # Ignore if process already exited
    :exit, _ -> :ok
  end

  # Ignore if pid is not valid
  defp cleanup_accessibility_and_prefs(_), do: :ok
end
