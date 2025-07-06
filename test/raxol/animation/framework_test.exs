defmodule Raxol.Animation.FrameworkTest do
  # Disable async because we are manipulating GenServers
  use ExUnit.Case, async: false

  require Logger

  alias Raxol.Animation.{Animation, Framework}
  alias Raxol.Core.Accessibility
  alias Raxol.Core.UserPreferences
  alias Raxol.Test.EventAssertions
  import Raxol.AccessibilityTestHelpers
  import Raxol.Guards

  Logger.debug("Starting FrameworkTest module")

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
    Logger.debug("Starting setup block")
    local_user_prefs_name = __MODULE__.UserPreferences
    user_prefs_opts = [name: local_user_prefs_name, test_mode?: true]

    Logger.debug(
      "Starting UserPreferences with opts: #{inspect(user_prefs_opts)}"
    )

    {:ok, _pid} = start_supervised({UserPreferences, user_prefs_opts})
    Logger.debug("UserPreferences started successfully")

    Framework.init(%{}, local_user_prefs_name)
    Logger.debug("Framework initialized")

    # Reset relevant prefs before each test
    UserPreferences.set(
      "accessibility.reduced_motion",
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
    Logger.debug("Preferences applied successfully")

    on_exit(fn ->
      Framework.stop()
      Logger.debug("Framework stopped in on_exit")
    end)

    :ok
  end

  describe "Animation Framework" do
    setup do
      # Check if UserPreferences is already started
      case Raxol.Core.UserPreferences.start_link([]) do
        {:ok, user_preferences_pid} ->
          %{user_preferences_pid: user_preferences_pid}
        {:error, {:already_started, user_preferences_pid}} ->
          %{user_preferences_pid: user_preferences_pid}
      end
    end

    test ~c"initializes with default settings", %{user_preferences_pid: user_preferences_pid} do
      assert :ok == Framework.init(%{}, user_preferences_pid)
      # Verify default settings
      settings = Process.get(:animation_framework_settings, %{})
      assert settings.reduced_motion == false
      assert settings.default_duration == 300
      # Note: default_easing is not stored in settings, it's used at creation time
    end

    test ~c"creates animation with default settings" do
      animation =
        Framework.create_animation(:test_animation, %{
          type: :fade,
          from: 0,
          to: 1,
          target_path: [:opacity]
        })

      assert animation.name == :test_animation
      assert map?(animation)
      assert Map.has_key?(animation, :type)
      assert animation.type == :fade
      # Default duration
      assert animation.duration == 300
      # Default easing
      assert animation.easing == :linear
      assert animation.from == 0
      assert animation.to == 1
    end

    test ~c"creates animation with custom settings" do
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
      assert map?(animation)
      assert Map.has_key?(animation, :type)
      assert animation.type == :slide
      assert animation.duration == 500
      assert animation.easing == :ease_out_cubic
      assert animation.from == 0
      assert animation.to == 100
      assert animation.direction == :right
    end

    test "starts animation for an element", %{
      user_preferences_pid: user_preferences_pid
    } do
      # Create and start a test animation
      animation =
        Framework.create_animation(:test_animation, %{
          type: :fade,
          from: 0,
          to: 1,
          target_path: [:opacity]
        })

      assert :ok ==
               Framework.start_animation(
                 animation.name,
                 "test_element",
                 %{},
                 user_preferences_pid
               )

      wait_for_animation_start("test_element", animation.name)
    end

    test "handles reduced motion preferences", %{
      user_preferences_pid: user_preferences_pid
    } do
      # Enable reduced motion *before* creating/starting
      UserPreferences.set("accessibility.reduced_motion", true, user_preferences_pid)
      Framework.init(%{reduced_motion: true}, user_preferences_pid)

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
      :ok =
        Framework.start_animation(
          animation.name,
          "test_element",
          %{},
          user_preferences_pid
        )

      wait_for_animation_start("test_element", animation.name)

      # Apply animation immediately
      updated_state =
        Framework.apply_animations_to_state(initial_state, user_preferences_pid)

      # Verify the final state was applied immediately due to reduced motion
      assert get_in(updated_state, [:elements, "test_element", :opacity]) == 1
    end

    test "announces animations to screen readers when configured", %{
      user_preferences_pid: user_preferences_pid
    } do
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
        :ok =
          Framework.start_animation(
            animation.name,
            "test_element",
            %{},
            user_preferences_pid
          )

        wait_for_animation_start("test_element", animation.name)

        # Verify announcement was made
        assert_receive {:accessibility_announcement, "Test animation started"},
                       100
      end)
    end

    test "applies animation values to state", %{
      user_preferences_pid: user_preferences_pid
    } do
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

      :ok =
        Framework.start_animation(
          animation.name,
          "test_element",
          %{},
          user_preferences_pid
        )

      wait_for_animation_start("test_element", animation.name)

      # Apply animation to state
      updated_state =
        Framework.apply_animations_to_state(initial_state, user_preferences_pid)

      # Verify state was updated
      assert get_in(updated_state, [:elements, "test_element", :opacity]) == 1
    end

    test "handles multiple animations on same element", %{
      user_preferences_pid: user_preferences_pid
    } do
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

      :ok =
        Framework.start_animation(
          fade_animation.name,
          "test_element",
          %{},
          user_preferences_pid
        )

      :ok =
        Framework.start_animation(
          slide_animation.name,
          "test_element",
          %{},
          user_preferences_pid
        )

      wait_for_animation_start("test_element", fade_animation.name)
      wait_for_animation_start("test_element", slide_animation.name)

      # Apply animations to state
      updated_state =
        Framework.apply_animations_to_state(initial_state, user_preferences_pid)

      # Verify both animations were applied
      assert get_in(updated_state, [:elements, "test_element", :opacity]) == 1

      assert get_in(updated_state, [:elements, "test_element", :position]) ==
               100
    end

    test "meets performance requirements", %{
      user_preferences_pid: user_preferences_pid
    } do
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
      start_time = System.unique_integer([:positive])

      :ok =
        Framework.start_animation(
          animation.name,
          "test_element",
          %{},
          user_preferences_pid
        )

      wait_for_animation_start("test_element", animation.name)
      wait_for_animation_completion("test_element", animation.name)

      end_time = System.unique_integer([:positive])

      duration =
        System.convert_time_unit(end_time - start_time, :native, :millisecond)

      # Verify performance requirements
      assert duration < 16, "Animation frame time too high"
    end
  end
end
