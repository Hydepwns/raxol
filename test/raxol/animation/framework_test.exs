defmodule Raxol.Animation.FrameworkTest do
  # Disable async because we are manipulating GenServers
  use ExUnit.Case, async: false

  alias Raxol.Animation.{Animation, Framework}
  alias Raxol.Core.Accessibility
  alias Raxol.Core.UserPreferences
  alias Raxol.Test.EventAssertions
  import Raxol.AccessibilityTestHelpers

  # Helper to wait for animation completion
  defp wait_for_animation_completion(element_id, animation_name, timeout \\ 100) do
    assert_receive {:animation_completed, ^element_id, ^animation_name}, timeout
  end

  # Helper to wait for animation start
  defp wait_for_animation_start(element_id, animation_name, timeout \\ 100) do
    assert_receive {:animation_started, ^element_id, ^animation_name}, timeout
  end

  # Start UserPreferences for these tests
  setup do
    # Use a test-specific name to avoid conflicts
    {:ok, _pid} =
      start_supervised({UserPreferences, name: __MODULE__.UserPreferences})

    # Initialize required systems for testing
    Framework.init()
    # Accessibility.enable() -- replaced by with_screen_reader_spy in tests

    # Reset relevant prefs before each test
    UserPreferences.set("accessibility.reduced_motion", false)
    UserPreferences.set("accessibility.screen_reader", true)
    UserPreferences.set("accessibility.silence_announcements", false)

    # Accessibility.clear_announcements() -- replaced by with_screen_reader_spy in tests

    # Wait for preferences to be applied
    assert_receive {:preferences_applied}, 100

    on_exit(fn ->
      # Cleanup
      Framework.stop()
      # Accessibility.disable() -- replaced by with_screen_reader_spy in tests
    end)

    :ok
  end

  describe "Animation Framework" do
    setup do
      {:ok, user_preferences_pid} = Raxol.Core.UserPreferences.start_link([])
      %{user_preferences_pid: user_preferences_pid}
    end

    test "initializes with default settings" do
      assert :ok == Framework.init()
      # Verify default settings
      settings = Process.get(:animation_framework_settings, %{})
      assert settings.reduced_motion == false
      assert settings.default_duration == 300
      assert settings.default_easing == :linear
    end

    test "creates animation with default settings" do
      animation =
        Framework.create_animation(:test_animation, %{
          type: :fade,
          from: 0,
          to: 1,
          target_path: [:opacity]
        })

      assert animation.name == :test_animation
      assert animation.type == :fade
      # Default duration
      assert animation.duration == 300
      # Default easing
      assert animation.easing == :linear
      assert animation.from == 0
      assert animation.to == 1
    end

    test "creates animation with custom settings" do
      animation =
        Framework.create_animation(:custom_animation, %{
          type: :slide,
          duration: 500,
          easing: :ease_out_cubic,
          from: 0,
          to: 100,
          direction: :right,
          target_path: [:position]
        })

      assert animation.name == :custom_animation
      assert animation.type == :slide
      assert animation.duration == 500
      assert animation.easing == :ease_out_cubic
      assert animation.from == 0
      assert animation.to == 100
      assert animation.direction == :right
    end

    test "starts animation for an element", %{user_preferences_pid: user_preferences_pid} do
      # Create and start a test animation
      animation =
        Framework.create_animation(:test_animation, %{
          type: :fade,
          from: 0,
          to: 1,
          target_path: [:opacity]
        })

      assert :ok == Framework.start_animation(animation.name, "test_element", %{}, user_preferences_pid)
      wait_for_animation_start("test_element", animation.name)
    end

    test "handles reduced motion preferences", %{user_preferences_pid: user_preferences_pid} do
      # Enable reduced motion *before* creating/starting
      UserPreferences.set("accessibility.reduced_motion", true)
      Framework.init(%{reduced_motion: true})

      # Create initial state
      initial_state = %{
        elements: %{
          "test_element" => %{
            # Initial value
            opacity: 0
          }
        }
      }

      # Create a test animation
      animation =
        Framework.create_animation(:test_animation, %{
          type: :fade,
          # Original duration doesn't matter now
          duration: 300,
          # Matches initial state
          from: 0,
          # Final value
          to: 1,
          target_path: [:opacity]
        })

      # Start the animation
      :ok = Framework.start_animation(animation.name, "test_element", %{}, user_preferences_pid)
      wait_for_animation_start("test_element", animation.name)

      # Apply animation immediately
      updated_state = Framework.apply_animations_to_state(initial_state, user_preferences_pid)

      # Verify the final state was applied immediately due to reduced motion
      assert get_in(updated_state, [:elements, "test_element", :opacity]) == 1
    end

    test "announces animations to screen readers when configured", %{user_preferences_pid: user_preferences_pid} do
      with_screen_reader_spy(user_preferences_pid, fn ->
        # Create an animation with screen reader announcement
        animation =
          Framework.create_animation(:test_animation, %{
            type: :fade,
            from: 0,
            to: 1,
            announce_to_screen_reader: true,
            description: "Test animation",
            target_path: [:opacity]
          })

        # Start the animation
        :ok = Framework.start_animation(animation.name, "test_element", %{}, user_preferences_pid)
        wait_for_animation_start("test_element", animation.name)

        # Verify announcement was made
        assert_receive {:accessibility_announcement, "Test animation started"},
                       100
      end)
    end

    test "applies animation values to state", %{user_preferences_pid: user_preferences_pid} do
      # Create initial state
      initial_state = %{
        elements: %{
          "test_element" => %{
            opacity: 0
          }
        }
      }

      # Create and start a fade animation with zero duration for instant result
      animation =
        Framework.create_animation(:fade_in, %{
          type: :fade,
          # Set duration to 0
          duration: 0,
          from: 0,
          to: 1,
          target_path: [:opacity]
        })

      :ok = Framework.start_animation(animation.name, "test_element", %{}, user_preferences_pid)
      wait_for_animation_start("test_element", animation.name)

      # Apply animation to state
      updated_state = Framework.apply_animations_to_state(initial_state, user_preferences_pid)

      # Verify state was updated
      assert get_in(updated_state, [:elements, "test_element", :opacity]) == 1
    end

    test "handles multiple animations on same element", %{user_preferences_pid: user_preferences_pid} do
      # Create initial state
      initial_state = %{
        elements: %{
          "test_element" => %{
            opacity: 0,
            position: 0
          }
        }
      }

      # Create and start multiple animations with zero duration
      fade_animation =
        Framework.create_animation(:fade_in, %{
          type: :fade,
          # Set duration to 0
          duration: 0,
          from: 0,
          to: 1,
          target_path: [:opacity]
        })

      slide_animation =
        Framework.create_animation(:slide_in, %{
          type: :slide,
          # Set duration to 0
          duration: 0,
          from: 0,
          to: 100,
          target_path: [:position]
        })

      :ok = Framework.start_animation(fade_animation.name, "test_element", %{}, user_preferences_pid)
      :ok = Framework.start_animation(slide_animation.name, "test_element", %{}, user_preferences_pid)

      wait_for_animation_start("test_element", fade_animation.name)
      wait_for_animation_start("test_element", slide_animation.name)

      # Apply animations to state
      updated_state = Framework.apply_animations_to_state(initial_state, user_preferences_pid)

      # Verify both animations were applied
      assert get_in(updated_state, [:elements, "test_element", :opacity]) == 1

      assert get_in(updated_state, [:elements, "test_element", :position]) ==
               100
    end

    test "meets performance requirements", %{user_preferences_pid: user_preferences_pid} do
      # Create a test animation
      animation =
        Framework.create_animation(:perf_test, %{
          type: :fade,
          duration: 100,
          from: 0,
          to: 1,
          target_path: [:opacity]
        })

      # Measure animation performance
      start_time = System.monotonic_time()

      :ok = Framework.start_animation(animation.name, "test_element", %{}, user_preferences_pid)
      wait_for_animation_start("test_element", animation.name)
      wait_for_animation_completion("test_element", animation.name)

      end_time = System.monotonic_time()

      duration =
        System.convert_time_unit(end_time - start_time, :native, :millisecond)

      # Verify performance requirements
      assert duration < 16, "Animation frame time too high"
    end
  end
end
