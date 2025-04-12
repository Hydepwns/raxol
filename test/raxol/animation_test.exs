defmodule Raxol.AnimationTest do
  use ExUnit.Case

  import Raxol.AccessibilityTestHelpers

  alias Raxol.Animation.Framework
  alias Raxol.Core.Accessibility
  alias Raxol.Core.UserPreferences

  setup do
    # Initialize required systems for testing
    Framework.init()
    Accessibility.enable()
    UserPreferences.init()

    :ok
  end

  describe "Animation Framework with accessibility integration" do
    test "respects reduced motion settings" do
      # Ensure reduced motion is disabled initially
      UserPreferences.set(:reduced_motion, false)

      # Create a standard animation
      standard_animation =
        Framework.create_animation(
          duration: 500,
          easing: :ease_in_out,
          from: 0,
          to: 100
        )

      # Enable reduced motion
      UserPreferences.set(:reduced_motion, true)

      # Create an animation with reduced motion enabled
      reduced_motion_animation =
        Framework.create_animation(
          duration: 500,
          easing: :ease_in_out,
          from: 0,
          to: 100
        )

      # Verify reduced motion animation has shorter duration or is disabled
      assert reduced_motion_animation.duration < standard_animation.duration ||
               reduced_motion_animation.disabled == true
    end

    test "announces animation start and completion to screen readers when relevant" do
      with_screen_reader_spy(fn ->
        # Create and start an important animation that should be announced
        animation =
          Framework.create_animation(
            duration: 100,
            from: 0,
            to: 100,
            announce_to_screen_reader: true,
            description: "Loading process"
          )

        Framework.start_animation(animation)

        # Wait for animation to complete
        Process.sleep(150)

        # Verify announcements were made
        assert_announced("Loading process started")
        assert_announced("Loading process completed")
      end)
    end

    test "does not announce non-important animations to screen readers" do
      with_screen_reader_spy(fn ->
        # Create and start a non-important animation
        animation =
          Framework.create_animation(
            duration: 100,
            from: 0,
            to: 100,
            announce_to_screen_reader: false
          )

        Framework.start_animation(animation)

        # Wait for animation to complete
        Process.sleep(150)

        # Verify no announcements were made
        assert_no_announcements()
      end)
    end

    test "disables animations when system preference is set" do
      # Enable system-wide animation disabling
      UserPreferences.set(:disable_all_animations, true)

      # Create an animation
      animation =
        Framework.create_animation(
          duration: 500,
          from: 0,
          to: 100
        )

      # Verify animation is disabled
      assert animation.disabled == true

      # Verify animation completes immediately
      {value, _} = Framework.get_current_value(animation)
      assert value == 100
    end

    test "provides alternative non-animated experience" do
      # Enable reduced motion
      with_reduced_motion(fn ->
        # Create a progress indicator with animation
        progress = Framework.create_progress_indicator(animated: true)

        # Verify it falls back to non-animated version
        assert progress.animation_type == :none ||
                 progress.animation_type == :simplified
      end)
    end

    test "animation framework integrates with user preferences" do
      # Set user preference for reduced motion
      UserPreferences.set(:reduced_motion, true)

      # Verify framework respects this setting
      assert Framework.reduced_motion_enabled?()

      # Create an animation
      animation =
        Framework.create_animation(
          duration: 500,
          from: 0,
          to: 100
        )

      # Verify animation respects reduced motion
      assert animation.duration < 500 || animation.disabled == true

      # Disable reduced motion
      UserPreferences.set(:reduced_motion, false)

      # Verify framework updates its state
      refute Framework.reduced_motion_enabled?()
    end

    test "animations have appropriate timing for cognitive accessibility" do
      # Create a standard animation
      animation =
        Framework.create_animation(
          duration: 500,
          from: 0,
          to: 100
        )

      # Enable cognitive accessibility mode
      UserPreferences.set(:cognitive_accessibility, true)

      # Create an animation with cognitive accessibility enabled
      cognitive_animation =
        Framework.create_animation(
          duration: 500,
          from: 0,
          to: 100
        )

      # Verify cognitive animation has longer duration to be more perceivable
      assert cognitive_animation.duration > animation.duration
    end
  end
end
