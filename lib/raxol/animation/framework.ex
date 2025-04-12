defmodule Raxol.Animation.Framework do
  @moduledoc """
  A general-purpose animation framework for Raxol terminal UI applications.

  This module provides a comprehensive animation system that:
  - Supports various animation types (easing, physics-based, keyframes)
  - Respects reduced motion accessibility settings
  - Provides smooth transitions between UI states
  - Offers standard animation patterns for common interactions
  - Manages animation timing and rendering

  The framework automatically adapts to user preferences for reduced motion
  and will provide alternative non-animated transitions when needed.

  ## Usage

  ```elixir
  # Initialize the animation framework
  AnimationFramework.init()

  # Create a simple animation
  animation = AnimationFramework.create_animation(:fade_in, %{
    duration: 300,
    easing: :ease_out_cubic
  })

  # Start the animation
  AnimationFramework.start_animation(animation, :element_id)

  # Update state with animation progress
  updated_state = AnimationFramework.apply_animation(state, now)
  ```
  """

  require Logger
  alias Raxol.Core.Accessibility

  @animation_fps 30
  @animation_frame_ms round(1000 / @animation_fps)

  @doc """
  Initialize the animation framework.

  This sets up the necessary state for tracking animations and
  integrates with accessibility settings.

  ## Options

  * `:reduced_motion` - Start with reduced motion (default: from accessibility settings)
  * `:default_duration` - Default animation duration in milliseconds (default: 300)
  * `:frame_ms` - Frame duration in milliseconds (default: #{@animation_frame_ms})

  ## Examples

      iex> AnimationFramework.init()
      :ok

      iex> AnimationFramework.init(reduced_motion: true)
      :ok
  """
  def init(opts \\ %{}) do
    Logger.debug("Initializing animation framework...")

    # Get accessibility settings
    reduced_motion =
      Map.get(opts, :reduced_motion, Accessibility.reduced_motion_enabled?())

    default_duration = Map.get(opts, :default_duration, 300)
    frame_ms = Map.get(opts, :frame_ms, @animation_frame_ms)

    # Store framework settings
    Process.put(:animation_framework_settings, %{
      reduced_motion: reduced_motion,
      default_duration: default_duration,
      frame_ms: frame_ms
    })

    # Initialize animation registry
    Process.put(:animation_framework_animations, %{})
    Process.put(:animation_framework_active_animations, %{})

    :ok
  end

  @doc """
  Create a new animation.

  ## Parameters

  * `name` - Unique identifier for the animation
  * `params` - Animation parameters

  ## Options

  * `:type` - Animation type (:fade, :slide, :scale, :color, :generic)
  * `:duration` - Duration in milliseconds
  * `:easing` - Easing function name
  * `:from` - Starting value
  * `:to` - Ending value
  * `:direction` - Animation direction (:in, :out)
  * `:announce_to_screen_reader` - Whether to announce to screen readers
  * `:description` - Description for screen reader announcements

  ## Examples

      iex> AnimationFramework.create_animation(:fade_in, %{
      ...>   type: :fade,
      ...>   duration: 300,
      ...>   easing: :ease_out_cubic,
      ...>   from: 0.0,
      ...>   to: 1.0,
      ...>   direction: :in
      ...> })
      %{
        name: :fade_in,
        type: :fade,
        duration: 300,
        easing: :ease_out_cubic,
        from: 0.0,
        to: 1.0,
        direction: :in
      }
  """
  def create_animation(name, params) do
    # Get default settings
    settings = Process.get(:animation_framework_settings, %{})
    default_duration = Map.get(settings, :default_duration, 300)

    # Create animation with defaults
    animation =
      Map.merge(
        %{
          name: name,
          duration: default_duration,
          easing: :linear,
          type: :generic
        },
        params
      )

    # Store animation in registry
    animations = Process.get(:animation_framework_animations, %{})
    updated_animations = Map.put(animations, name, animation)
    Process.put(:animation_framework_animations, updated_animations)

    animation
  end

  @doc """
  Start an animation for a specific element.

  ## Parameters

  * `animation_name` - The name of the animation to start
  * `element_id` - Identifier for the element being animated
  * `opts` - Additional options

  ## Options

  * `:on_complete` - Function to call when animation completes
  * `:context` - Additional context for the animation

  ## Examples

      iex> AnimationFramework.start_animation(:fade_in, "search_button")
      :ok

      iex> AnimationFramework.start_animation(:slide_in, "panel", on_complete: &handle_complete/1)
      :ok
  """
  def start_animation(animation_name, element_id, opts \\ %{}) do
    # Get animation definition
    animations = Process.get(:animation_framework_animations, %{})
    animation = Map.get(animations, animation_name)

    if animation do
      # Check if reduced motion is enabled
      settings = Process.get(:animation_framework_settings, %{})

      adapted_animation =
        if Map.get(settings, :reduced_motion, false) do
          # For reduced motion, either disable animation or use simplified version
          adapt_for_reduced_motion(animation)
        else
          animation
        end

      # Create animation instance
      instance = %{
        animation: adapted_animation,
        start_time: System.monotonic_time(:millisecond),
        on_complete: Map.get(opts, :on_complete),
        context: Map.get(opts, :context, %{})
      }

      # Store active animation
      active_animations =
        Process.get(:animation_framework_active_animations, %{})

      element_animations = Map.get(active_animations, element_id, %{})

      updated_element_animations =
        Map.put(element_animations, animation_name, instance)

      updated_active_animations =
        Map.put(active_animations, element_id, updated_element_animations)

      Process.put(
        :animation_framework_active_animations,
        updated_active_animations
      )

      # Announce to screen reader if configured
      if Map.get(animation, :announce_to_screen_reader, false) do
        Accessibility.announce(
          Map.get(animation, :description, "Animation started")
        )
      end

      :ok
    else
      {:error, :animation_not_found}
    end
  end

  @doc """
  Update animations and apply their current values to the state.

  ## Parameters

  * `state` - Current application state

  ## Returns

  Updated state with animation values applied.
  """
  def apply_animations_to_state(state) do
    # Get active animations
    active_animations = Process.get(:animation_framework_active_animations, %{})

    # Apply each animation to the state
    Enum.reduce(active_animations, state, fn {element_id, element_animations},
                                             acc_state ->
      # For each animation affecting this element
      Enum.reduce(element_animations, acc_state, fn {animation_name, instance},
                                                    element_acc_state ->
        # Apply this specific animation to the state
        apply_animation_to_state(
          element_acc_state,
          element_id,
          animation_name,
          instance
        )
      end)
    end)
  end

  defp apply_animation_to_state(state, element_id, animation_name, instance) do
    # Implementation depends on state structure and animation type
    case instance.animation.type do
      :fade ->
        # Update opacity for the element
        set_in_state(state, [:elements, element_id, :opacity], instance.value)

      :slide ->
        # Update position for the element
        set_in_state(state, [:elements, element_id, :position], instance.value)

      :scale ->
        # Update scale for the element
        set_in_state(state, [:elements, element_id, :scale], instance.value)

      :color ->
        # Update color for the element
        set_in_state(state, [:elements, element_id, :color], instance.value)

      _ ->
        # For generic animations, store the value in a animations map
        animations = Map.get(state, :animations, %{})
        element_animations = Map.get(animations, element_id, %{})

        updated_element_animations =
          Map.put(element_animations, animation_name, instance.value)

        updated_animations =
          Map.put(animations, element_id, updated_element_animations)

        Map.put(state, :animations, updated_animations)
    end
  end

  @doc """
  Stops a specific animation for an element.

  ## Parameters

  * `animation_name` - The name of the animation to stop
  * `element_id` - Identifier for the element being animated

  ## Examples

      iex> AnimationFramework.stop_animation(:fade_in, "search_button")
      :ok
  """
  def stop_animation(animation_name, element_id) do
    active_animations = Process.get(:animation_framework_active_animations, %{})
    element_animations = Map.get(active_animations, element_id, %{})
    updated_element_animations = Map.delete(element_animations, animation_name)

    updated_active_animations =
      if map_size(updated_element_animations) == 0 do
        Map.delete(active_animations, element_id)
      else
        Map.put(active_animations, element_id, updated_element_animations)
      end

    Process.put(
      :animation_framework_active_animations,
      updated_active_animations
    )

    :ok
  end

  @doc """
  Gets the current value and completion status of an animation instance.

  ## Parameters

  * `animation_name` - The name of the animation
  * `element_id` - Identifier for the element being animated

  ## Returns

  * `{value, done?}` - A tuple with the current animation value and a boolean indicating if it's finished.
  * `:not_found` - If the animation instance is not active.

  ## Examples

      iex> AnimationFramework.get_current_value(:fade_in, "search_button")
      {0.5, false}
  """
  def get_current_value(animation_name, element_id) do
    active_animations = Process.get(:animation_framework_active_animations, %{})

    case get_in(active_animations, [element_id, animation_name]) do
      nil ->
        :not_found

      instance ->
        current_time = System.monotonic_time(:millisecond)
        elapsed = current_time - instance.start_time
        animation = instance.animation
        duration = animation.duration

        if animation[:disabled] or duration == 0 or elapsed >= duration do
          # Animation is done (or disabled/instant)
          {animation.to, true}
        else
          # Calculate progress (0.0 to 1.0)
          progress = elapsed / duration

          # Apply easing function (placeholder - needs easing implementation)
          # TODO: Apply easing function animation.easing
          eased_progress = progress

          # Interpolate value
          value = interpolate(animation.from, animation.to, eased_progress)
          {value, false}
        end
    end
  end

  defp adapt_for_reduced_motion(anim) do
    # For reduced motion, either disable animation or use simplified version
    case anim.type do
      :fade ->
        # For fades, use instant transition
        Map.put(anim, :duration, 0)

      :slide ->
        # For slides, use instant position change
        Map.put(anim, :duration, 0)

      :scale ->
        # For scales, use instant size change
        Map.put(anim, :duration, 0)

      :color ->
        # For colors, use instant color change
        Map.put(anim, :duration, 0)

      _ ->
        # For other animations, disable them
        Map.put(anim, :disabled, true)
    end
  end

  defp set_in_state(state, path, value) do
    # Helper to set nested values in state
    put_in(state, path, value)
  end

  # TODO: Implement easing functions
  # TODO: Implement interpolation for different types (color, numbers, etc.)
  defp interpolate(from, to, progress) when is_number(from) and is_number(to) do
    from + (to - from) * progress
  end

  # Add clauses for other types if needed
  # Default fallback
  defp interpolate(_from, to, _progress), do: to
end
