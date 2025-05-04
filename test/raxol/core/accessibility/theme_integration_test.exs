defmodule Raxol.Core.Accessibility.ThemeIntegrationTest do
  use ExUnit.Case, async: true

  alias Raxol.Components.FocusRing
  alias Raxol.Core.Accessibility.ThemeIntegration
  alias Raxol.Core.Events.Manager, as: EventManager

  setup do
    # Initialize dependencies
    EventManager.init()

    # Clean up after tests
    on_exit(fn ->
      ThemeIntegration.cleanup()
    end)

    :ok
  end

  describe "init/0" do
    test "initializes theme integration" do
      assert :ok = ThemeIntegration.init()

      # Verify event handlers are registered
      handlers = EventManager.get_handlers()

      assert Enum.member?(
               handlers[:accessibility_high_contrast] || [],
               {ThemeIntegration, :handle_high_contrast}
             )

      assert Enum.member?(
               handlers[:accessibility_reduced_motion] || [],
               {ThemeIntegration, :handle_reduced_motion}
             )

      assert Enum.member?(
               handlers[:accessibility_large_text] || [],
               {ThemeIntegration, :handle_large_text}
             )
    end
  end

  describe "cleanup/0" do
    test "cleans up theme integration" do
      # First initialize
      ThemeIntegration.init()

      # Then clean up
      assert :ok = ThemeIntegration.cleanup()

      # Verify event handlers are unregistered
      handlers = EventManager.get_handlers()

      refute Enum.member?(
               handlers[:accessibility_high_contrast] || [],
               {ThemeIntegration, :handle_high_contrast}
             )

      refute Enum.member?(
               handlers[:accessibility_reduced_motion] || [],
               {ThemeIntegration, :handle_reduced_motion}
             )

      refute Enum.member?(
               handlers[:accessibility_large_text] || [],
               {ThemeIntegration, :handle_large_text}
             )
    end
  end

  describe "apply_current_settings/0" do
    test "applies current accessibility settings" do
      # Set up accessibility options
      Process.put(:accessibility_options,
        high_contrast: true,
        reduced_motion: true,
        large_text: true
      )

      # Apply settings
      assert :ok = ThemeIntegration.apply_current_settings()

      # Verify text scale was set
      assert Process.get(:accessibility_text_scale) == 1.5

      # Verify component styles were updated
      component_styles = Process.get(:accessibility_component_styles)
      assert component_styles != nil

      # Clean up
      Process.delete(:accessibility_options)
      Process.delete(:accessibility_text_scale)
      Process.delete(:accessibility_component_styles)
    end
  end

  describe "handle_high_contrast/1" do
    test "updates component styles for high contrast mode" do
      # Handle high contrast event
      assert :ok =
               ThemeIntegration.handle_high_contrast(
                 {:accessibility_high_contrast, true}
               )

      # Verify component styles were updated
      component_styles = Process.get(:accessibility_component_styles)
      assert component_styles != nil

      # Check button colors
      assert component_styles.button.background == :yellow
      assert component_styles.button.foreground == :black

      # Clean up
      Process.delete(:accessibility_component_styles)
    end

    test "updates component styles for standard mode" do
      # Handle standard contrast event
      assert :ok =
               ThemeIntegration.handle_high_contrast(
                 {:accessibility_high_contrast, false}
               )

      # Verify component styles were updated
      component_styles = Process.get(:accessibility_component_styles)
      assert component_styles != nil

      # Check button colors
      assert component_styles.button.background == {:rgb, 0, 120, 215}
      assert component_styles.button.foreground == :white

      # Clean up
      Process.delete(:accessibility_component_styles)
    end
  end

  describe "handle_reduced_motion/1" do
    test "disables animations when reduced motion is enabled" do
      # Record initial configuration
      initial_config = Process.get(:focus_ring_config)

      # Mock FocusRing.configure
      original_configure = Function.capture(FocusRing, :configure, 1)

      # Create a test process to receive configure calls
      test_pid = self()

      # Override the function with a mock that sends messages to our test process
      :meck.new(FocusRing, [:passthrough])

      :meck.expect(FocusRing, :configure, fn opts ->
        send(test_pid, {:configure, opts})
        :ok
      end)

      try do
        # Handle reduced motion event
        assert :ok =
                 ThemeIntegration.handle_reduced_motion(
                   {:accessibility_reduced_motion, true}
                 )

        # Verify FocusRing.configure was called with correct options
        assert_received {:configure, opts}
        assert opts[:animation] == :none
        assert opts[:transition_effect] == :none
      after
        # Clean up the mock
        :meck.unload(FocusRing)

        # Restore original configuration
        if initial_config do
          Process.put(:focus_ring_config, initial_config)
        end
      end
    end

    test "enables animations when reduced motion is disabled" do
      # Record initial configuration
      initial_config = Process.get(:focus_ring_config)

      # Mock FocusRing.configure
      test_pid = self()

      :meck.new(FocusRing, [:passthrough])

      :meck.expect(FocusRing, :configure, fn opts ->
        send(test_pid, {:configure, opts})
        :ok
      end)

      try do
        # Handle reduced motion event
        assert :ok =
                 ThemeIntegration.handle_reduced_motion(
                   {:accessibility_reduced_motion, false}
                 )

        # Verify FocusRing.configure was called with correct options
        assert_received {:configure, opts}
        assert opts[:animation] == :pulse
        assert opts[:transition_effect] == :fade
      after
        # Clean up the mock
        :meck.unload(FocusRing)

        # Restore original configuration
        if initial_config do
          Process.put(:focus_ring_config, initial_config)
        end
      end
    end
  end

  describe "handle_large_text/1" do
    test "sets text scale for large text mode" do
      # Handle large text event
      assert :ok =
               ThemeIntegration.handle_large_text(
                 {:accessibility_large_text, true}
               )

      # Verify text scale was set
      assert Process.get(:accessibility_text_scale) == 1.5

      # Clean up
      Process.delete(:accessibility_text_scale)
    end

    test "sets text scale for standard text mode" do
      # Handle standard text event
      assert :ok =
               ThemeIntegration.handle_large_text(
                 {:accessibility_large_text, false}
               )

      # Verify text scale was set
      assert Process.get(:accessibility_text_scale) == 1.0

      # Clean up
      Process.delete(:accessibility_text_scale)
    end
  end

  describe "get_standard_colors/0" do
    test "returns standard color scheme" do
      colors = ThemeIntegration.get_standard_colors()

      assert colors.background == {:rgb, 30, 30, 30}
      assert colors.foreground == {:rgb, 220, 220, 220}
      assert colors.accent == {:rgb, 0, 120, 215}
      assert colors.focus == {:rgb, 0, 120, 215}
      assert colors.button == {:rgb, 0, 120, 215}
      assert colors.error == {:rgb, 232, 17, 35}
      assert colors.success == {:rgb, 16, 124, 16}
      assert colors.warning == {:rgb, 255, 140, 0}
      assert colors.info == {:rgb, 41, 128, 185}
      assert colors.border == {:rgb, 100, 100, 100}
    end
  end

  describe "get_current_colors/0" do
    test "returns high contrast colors when high contrast is enabled" do
      # Set high contrast mode
      Process.put(:accessibility_options, high_contrast: true)

      colors = ThemeIntegration.get_current_colors()

      assert colors.background == :black
      assert colors.foreground == :white

      # Clean up
      Process.delete(:accessibility_options)
    end

    test "returns standard colors when high contrast is disabled" do
      # Set standard contrast mode
      Process.put(:accessibility_options, high_contrast: false)

      colors = ThemeIntegration.get_current_colors()

      assert colors.background == {:rgb, 30, 30, 30}
      assert colors.foreground == {:rgb, 220, 220, 220}

      # Clean up
      Process.delete(:accessibility_options)
    end

    test "returns standard colors when accessibility options are not set" do
      # Ensure no options are set
      Process.delete(:accessibility_options)

      colors = ThemeIntegration.get_current_colors()

      assert colors.background == {:rgb, 30, 30, 30}
      assert colors.foreground == {:rgb, 220, 220, 220}
    end
  end

  # Commenting out test for get_high_contrast_colors/0 as it no longer exists
  # test "get_high_contrast_colors/0 returns high contrast color scheme" do
  #   # Setup: Register a theme first
  #   colors = %{primary: "#007bff", background: "#ffffff"}
  #   System.register_theme(:test_hc, colors)
  #   System.apply_theme(:test_hc)

  #   # Call the function
  #   hc_colors = ThemeIntegration.get_high_contrast_colors()

  #   # Assertions
  #   assert is_map(hc_colors)
  #   # Assert contrast ratio between primary and background is high enough
  #   primary_hc = hc_colors.primary
  #   background_hc = hc_colors.background
  #   assert Accessibility.contrast_ratio(primary_hc, background_hc) >= 4.5
  # end
end
