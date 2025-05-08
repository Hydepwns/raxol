defmodule Raxol.Animation.FrameworkTest do
  # Disable async because we are manipulating GenServers
  use ExUnit.Case, async: false

  alias Raxol.Animation.{Animation, Framework}
  alias Raxol.Core.Accessibility
  alias Raxol.Core.UserPreferences

  # Start UserPreferences for these tests
  setup do
    # Use a test-specific name to avoid conflicts
    {:ok, _pid} =
      start_supervised({UserPreferences, name: __MODULE__.UserPreferences})

    # Initialize required systems for testing
    Framework.init()
    Accessibility.enable()

    :ok
  end

  describe "Animation Framework" do
    test "initializes with default settings" do
      assert :ok == Framework.init()
    end

    test "creates animation with default settings" do
      animation =
        Framework.create_animation(:test_animation, %{
          type: :fade,
          from: 0,
          to: 1
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
          direction: :right
        })

      assert animation.name == :custom_animation
      assert animation.type == :slide
      assert animation.duration == 500
      assert animation.easing == :ease_out_cubic
      assert animation.from == 0
      assert animation.to == 100
      assert animation.direction == :right
    end

    test "starts animation for an element" do
      # Create and start a test animation
      _animation =
        Framework.create_animation(:test_animation, %{
          type: :fade,
          from: 0,
          to: 1
        })

      assert :ok == Framework.start_animation(:test_animation, "test_element")
    end

    test "handles reduced motion preferences" do
      # Enable reduced motion *before* creating/starting
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
      _animation =
        Framework.create_animation(:test_animation, %{
          type: :fade,
          # Original duration doesn't matter now
          duration: 300,
          # Matches initial state
          from: 0,
          # Final value
          to: 1
        })

      # Start the animation
      :ok = Framework.start_animation(:test_animation, "test_element")

      # Apply animation immediately
      updated_state = Framework.apply_animations_to_state(initial_state)

      # Verify the final state was applied immediately due to reduced motion
      assert get_in(updated_state, [:elements, "test_element", :opacity]) == 1
    end

    test "announces animations to screen readers when configured" do
      # Create an animation with screen reader announcement
      _animation =
        Framework.create_animation(:test_animation, %{
          type: :fade,
          from: 0,
          to: 1,
          announce_to_screen_reader: true,
          description: "Test animation"
        })

      # Start the animation
      :ok = Framework.start_animation(:test_animation, "test_element")

      # Verify announcement was made by checking the process dictionary queue
      announcements = Process.get(:accessibility_announcements, [])
      assert Enum.any?(announcements, &(&1.message == "Test animation"))
    end

    test "applies animation values to state" do
      # Create initial state
      initial_state = %{
        elements: %{
          "test_element" => %{
            opacity: 0
          }
        }
      }

      # Create and start a fade animation with zero duration for instant result
      _animation =
        Framework.create_animation(:fade_in, %{
          type: :fade,
          # Set duration to 0
          duration: 0,
          from: 0,
          to: 1
        })

      :ok = Framework.start_animation(:fade_in, "test_element")

      # Apply animation to state
      updated_state = Framework.apply_animations_to_state(initial_state)

      # Verify state was updated
      assert get_in(updated_state, [:elements, "test_element", :opacity]) == 1
    end

    test "handles multiple animations on same element" do
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
      _fade_animation =
        Framework.create_animation(:fade_in, %{
          type: :fade,
          # Set duration to 0
          duration: 0,
          from: 0,
          to: 1
        })

      _slide_animation =
        Framework.create_animation(:slide_in, %{
          type: :slide,
          # Set duration to 0
          duration: 0,
          from: 0,
          to: 100
        })

      :ok = Framework.start_animation(:fade_in, "test_element")
      :ok = Framework.start_animation(:slide_in, "test_element")

      # Apply animations to state
      updated_state = Framework.apply_animations_to_state(initial_state)

      # Verify both animations were applied
      assert get_in(updated_state, [:elements, "test_element", :opacity]) == 1

      assert get_in(updated_state, [:elements, "test_element", :position]) ==
               100
    end
  end
end
