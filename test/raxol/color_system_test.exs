defmodule Raxol.ColorSystemTest do
  use ExUnit.Case

  import Raxol.AccessibilityTestHelpers

  alias Raxol.Core.Accessibility
  alias Raxol.Core.UserPreferences
  alias Raxol.Style.Colors.PaletteManager
  alias Raxol.Style.Colors.System, as: ColorSystem

  setup do
    # Initialize required systems for testing
    ColorSystem.init()
    PaletteManager.init()
    Accessibility.enable()
    UserPreferences.init()

    :ok
  end

  describe "ColorSystem with accessibility integration" do
    test "applies high contrast mode to theme colors" do
      # Apply a theme
      ColorSystem.apply_theme(:standard)

      # Get the primary color before high contrast
      normal_primary = ColorSystem.get_color(:primary)

      # Enable high contrast mode
      Accessibility.set_high_contrast(true)

      # Get the primary color after high contrast
      high_contrast_primary = ColorSystem.get_color(:primary)

      # Verify colors are different in high contrast mode
      assert normal_primary != high_contrast_primary

      # Verify high contrast color has sufficient contrast with background
      background = ColorSystem.get_color(:background)
      assert_sufficient_contrast(high_contrast_primary, background)
    end

    test "announces theme changes to screen readers" do
      with_screen_reader_spy(fn ->
        # Change the theme
        UserPreferences.set(:theme, :dark)

        # Assert announcement was made
        assert_announced("dark theme")
      end)
    end

    test "maintains user color preferences" do
      # Set a user preference for accent color
      UserPreferences.set(:accent_color, "#FF5722")

      # Save preferences
      UserPreferences.save()

      # Reset preferences to defaults
      Process.put(:user_preferences, %{})

      # Load preferences
      UserPreferences.load()

      # Verify preference was maintained
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
               "Color #{color} has insufficient contrast with dark background"
      end)
    end

    test "adapts focus ring color for high contrast mode" do
      # Configure focus ring
      Raxol.Components.FocusRing.configure(color: :blue, high_contrast: false)

      # Get initial focus ring style
      initial_config = get_focus_ring_config()

      # Enable high contrast mode
      with_high_contrast(fn ->
        # Get high contrast focus ring style
        high_contrast_config = get_focus_ring_config()

        # Verify high contrast was applied
        assert high_contrast_config.high_contrast == true
        assert high_contrast_config.color != initial_config.color
      end)
    end

    test "color system integrates with user preferences" do
      # Set user preference for a theme
      UserPreferences.set(:theme, :dark)

      # Verify theme was applied
      assert ColorSystem.get_current_theme() == :dark

      # Set high contrast mode in user preferences
      UserPreferences.set(:high_contrast, true)

      # Verify high contrast mode was applied
      assert Accessibility.high_contrast_enabled?()

      # Verify colors reflect high contrast setting
      primary = ColorSystem.get_color(:primary)
      background = ColorSystem.get_color(:background)
      assert_sufficient_contrast(primary, background)
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
      # Get animation framework module if available
      animation_module = Raxol.Animation.Framework

      if function_exported?(animation_module, :reduced_motion_enabled?, 0) do
        # Check initial reduced motion state
        initial_state = animation_module.reduced_motion_enabled?()

        # Set reduced motion through user preferences
        UserPreferences.set(:reduced_motion, true)

        # Verify animation framework respects this setting
        assert animation_module.reduced_motion_enabled?()

        # Restore previous state
        UserPreferences.set(:reduced_motion, initial_state)
      else
        # Skip test if animation framework not available
        flunk("Skipping test: Animation framework not available")
      end
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
    # Parse hex color
    hex = String.replace(hex, ~r/^#/, "")

    r = String.slice(hex, 0..1) |> String.to_integer(16)
    g = String.slice(hex, 2..3) |> String.to_integer(16)
    b = String.slice(hex, 4..5) |> String.to_integer(16)

    # Convert to sRGB
    r_srgb = r / 255
    g_srgb = g / 255
    b_srgb = b / 255

    # Calculate luminance components
    r_lum =
      if r_srgb <= 0.03928,
        do: r_srgb / 12.92,
        else: :math.pow((r_srgb + 0.055) / 1.055, 2.4)

    g_lum =
      if g_srgb <= 0.03928,
        do: g_srgb / 12.92,
        else: :math.pow((g_srgb + 0.055) / 1.055, 2.4)

    b_lum =
      if b_srgb <= 0.03928,
        do: b_srgb / 12.92,
        else: :math.pow((b_srgb + 0.055) / 1.055, 2.4)

    # Calculate relative luminance
    0.2126 * r_lum + 0.7152 * g_lum + 0.0722 * b_lum
  end
end
