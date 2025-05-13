defmodule Raxol.Core.Accessibility.ThemeIntegrationTest do
  use Raxol.DataCase, async: true

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

  describe "handle_high_contrast/1" do
    test "updates component styles for high contrast mode" do
      # Subscribe to theme change events
      ref = make_ref()
      EventManager.subscribe(ref, :theme_changed)

      # Handle high contrast event
      assert :ok =
               ThemeIntegration.handle_high_contrast(
                 {:accessibility_high_contrast, true}
               )

      # Wait for theme change event
      assert_receive {:theme_changed, %{high_contrast: true}}, 1000

      # Get color scheme
      scheme = ThemeIntegration.get_color_scheme()
      assert scheme != nil

      # Verify high contrast colors
      assert scheme.background == :black
      assert scheme.foreground == :white

      # Cleanup subscription
      EventManager.unsubscribe(ref, :theme_changed)
    end

    test "updates component styles for standard mode" do
      # Subscribe to theme change events
      ref = make_ref()
      EventManager.subscribe(ref, :theme_changed)

      # Handle standard contrast event
      assert :ok =
               ThemeIntegration.handle_high_contrast(
                 {:accessibility_high_contrast, false}
               )

      # Wait for theme change event
      assert_receive {:theme_changed, %{high_contrast: false}}, 1000

      # Get color scheme
      scheme = ThemeIntegration.get_color_scheme()
      assert scheme != nil

      # Verify standard colors
      assert scheme.background == {:rgb, 30, 30, 30}
      assert scheme.foreground == {:rgb, 220, 220, 220}

      # Cleanup subscription
      EventManager.unsubscribe(ref, :theme_changed)
    end
  end

  describe "handle_reduced_motion/1" do
    test "disables animations when reduced motion is enabled" do
      # Subscribe to theme change events
      ref = make_ref()
      EventManager.subscribe(ref, :theme_changed)

      # Handle reduced motion event
      assert :ok =
               ThemeIntegration.handle_reduced_motion(
                 {:accessibility_reduced_motion, true}
               )

      # Wait for theme change event
      assert_receive {:theme_changed, %{reduced_motion: true}}, 1000

      # Verify active variant
      assert ThemeIntegration.get_active_variant() == :reduced_motion

      # Cleanup subscription
      EventManager.unsubscribe(ref, :theme_changed)
    end

    test "enables animations when reduced motion is disabled" do
      # Subscribe to theme change events
      ref = make_ref()
      EventManager.subscribe(ref, :theme_changed)

      # Handle reduced motion event
      assert :ok =
               ThemeIntegration.handle_reduced_motion(
                 {:accessibility_reduced_motion, false}
               )

      # Wait for theme change event
      assert_receive {:theme_changed, %{reduced_motion: false}}, 1000

      # Verify active variant
      assert ThemeIntegration.get_active_variant() == :standard

      # Cleanup subscription
      EventManager.unsubscribe(ref, :theme_changed)
    end
  end

  describe "handle_large_text/1" do
    test "sets text scale for large text mode" do
      # Subscribe to theme change events
      ref = make_ref()
      EventManager.subscribe(ref, :theme_changed)

      # Handle large text event
      assert :ok =
               ThemeIntegration.handle_large_text(
                 {:accessibility_large_text, true}
               )

      # Wait for theme change event
      assert_receive {:theme_changed, %{large_text: true}}, 1000

      # Verify text scale
      assert ThemeIntegration.get_text_scale() == 1.5

      # Cleanup subscription
      EventManager.unsubscribe(ref, :theme_changed)
    end

    test "sets text scale for standard text mode" do
      # Subscribe to theme change events
      ref = make_ref()
      EventManager.subscribe(ref, :theme_changed)

      # Handle standard text event
      assert :ok =
               ThemeIntegration.handle_large_text(
                 {:accessibility_large_text, false}
               )

      # Wait for theme change event
      assert_receive {:theme_changed, %{large_text: false}}, 1000

      # Verify text scale
      assert ThemeIntegration.get_text_scale() == 1.0

      # Cleanup subscription
      EventManager.unsubscribe(ref, :theme_changed)
    end
  end

  describe "apply_settings/1" do
    test "applies accessibility settings" do
      # Subscribe to theme change events
      ref = make_ref()
      EventManager.subscribe(ref, :theme_changed)

      # Apply settings
      assert :ok =
               ThemeIntegration.apply_settings(
                 high_contrast: true,
                 reduced_motion: true,
                 large_text: true
               )

      # Wait for theme change events
      assert_receive {:theme_changed, %{high_contrast: true}}, 1000
      assert_receive {:theme_changed, %{reduced_motion: true}}, 1000
      assert_receive {:theme_changed, %{large_text: true}}, 1000

      # Verify active variant
      assert ThemeIntegration.get_active_variant() == :high_contrast

      # Verify text scale
      assert ThemeIntegration.get_text_scale() == 1.5

      # Cleanup subscription
      EventManager.unsubscribe(ref, :theme_changed)
    end
  end

  describe "get_color_scheme/0" do
    test "returns high contrast colors when high contrast is enabled" do
      # Subscribe to theme change events
      ref = make_ref()
      EventManager.subscribe(ref, :theme_changed)

      # Enable high contrast
      assert :ok = ThemeIntegration.apply_settings(high_contrast: true)
      assert_receive {:theme_changed, %{high_contrast: true}}, 1000

      # Get color scheme
      scheme = ThemeIntegration.get_color_scheme()
      assert scheme != nil

      # Verify high contrast colors
      assert scheme.background == :black
      assert scheme.foreground == :white

      # Cleanup subscription
      EventManager.unsubscribe(ref, :theme_changed)
    end

    test "returns standard colors when high contrast is disabled" do
      # Subscribe to theme change events
      ref = make_ref()
      EventManager.subscribe(ref, :theme_changed)

      # Disable high contrast
      assert :ok = ThemeIntegration.apply_settings(high_contrast: false)
      assert_receive {:theme_changed, %{high_contrast: false}}, 1000

      # Get color scheme
      scheme = ThemeIntegration.get_color_scheme()
      assert scheme != nil

      # Verify standard colors
      assert scheme.background == {:rgb, 30, 30, 30}
      assert scheme.foreground == {:rgb, 220, 220, 220}

      # Cleanup subscription
      EventManager.unsubscribe(ref, :theme_changed)
    end

    test "returns standard colors when accessibility options are not set" do
      # Subscribe to theme change events
      ref = make_ref()
      EventManager.subscribe(ref, :theme_changed)

      # Apply default settings
      assert :ok = ThemeIntegration.apply_settings([])
      assert_receive {:theme_changed, %{high_contrast: false}}, 1000

      # Get color scheme
      scheme = ThemeIntegration.get_color_scheme()
      assert scheme != nil

      # Verify standard colors
      assert scheme.background == {:rgb, 30, 30, 30}
      assert scheme.foreground == {:rgb, 220, 220, 220}

      # Cleanup subscription
      EventManager.unsubscribe(ref, :theme_changed)
    end
  end

  defp pref_key(key), do: "accessibility.#{key}"
end
