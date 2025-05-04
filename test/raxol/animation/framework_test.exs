defmodule Raxol.Animation.FrameworkTest do
  use ExUnit.Case, async: false # Disable async because we are manipulating GenServers

  alias Raxol.Animation.{Animation, Framework}
  alias Raxol.Core.Accessibility
  alias Raxol.Core.UserPreferences

  # Start UserPreferences for these tests
  setup do
    {:ok, _pid} = start_supervised(UserPreferences)
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
      # Enable reduced motion
      Framework.init(%{reduced_motion: true})

      # Create a test animation
      animation =
        Framework.create_animation(:test_animation, %{
          type: :fade,
          duration: 300,
          from: 0,
          to: 1
        })

      # Start the animation
      :ok = Framework.start_animation(:test_animation, "test_element")

      # Verify animation is adapted for reduced motion
      assert animation.duration == 0
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

      # Verify announcement was made
      assert Accessibility.was_announced?("Test animation")
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

      # Create and start a fade animation
      _animation =
        Framework.create_animation(:fade_in, %{
          type: :fade,
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

      # Create and start multiple animations
      _fade_animation =
        Framework.create_animation(:fade_in, %{
          type: :fade,
          from: 0,
          to: 1
        })

      _slide_animation =
        Framework.create_animation(:slide_in, %{
          type: :slide,
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
