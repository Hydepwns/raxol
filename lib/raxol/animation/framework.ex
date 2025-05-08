defmodule Raxol.Animation.Framework do
  @moduledoc """
  Coordinates the lifecycle of animations within Raxol.

  This module acts as the main entry point for creating, starting, stopping,
  and applying animations to the application state. It relies on supporting
  modules for specific concerns:

  - `Raxol.Animation.StateManager`: Handles the storage and retrieval of
    animation definitions and active instances.
  - `Raxol.Animation.Accessibility`: Adapts animations based on user
    accessibility preferences (e.g., reduced motion).
  - `Raxol.Animation.Interpolate`: Provides easing and value interpolation
    functions.

  The framework automatically handles:
  - Timing and progress calculation.
  - Applying interpolated values to the application state via configured paths.
  - Managing animation completion and callbacks.
  - Adapting to reduced motion settings.

  ## Usage

  ```elixir
  # Initialize the framework (typically done once on application start)
  Raxol.Animation.Framework.init()

  # Define an animation
  Raxol.Animation.Framework.create_animation(:fade_in, %{
    target_path: [:opacity], # Path within state to animate
    duration: 300,
    easing: :ease_out_cubic,
    from: 0.0,
    to: 1.0
  })

  # Start the animation on an element
  Raxol.Animation.Framework.start_animation(:fade_in, :my_element_id)

  # In the application's update loop, apply animations to the state
  updated_state = Raxol.Animation.Framework.apply_animations_to_state(current_state)
  ```
  """

  require Logger
  alias Raxol.Core.Accessibility
  alias Raxol.Animation.StateManager
  alias Raxol.Animation.Accessibility, as: AnimAccessibility

  @animation_fps 30
  @animation_frame_ms round(1000 / @animation_fps)

  @doc """
  Initialize the animation framework.

  This sets up the necessary state for tracking animations and
  integrates with accessibility settings.

  ## Options

  * `:reduced_motion` - Start with reduced motion (default: from accessibility settings)
  * `:cognitive_accessibility` - Start with cognitive accessibility (default: from accessibility settings)
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

    # Read reduced_motion preference
    reduced_motion_pref =
      Raxol.Core.UserPreferences.get([:accessibility, :reduced_motion]) || false

    reduced_motion = Map.get(opts, :reduced_motion, reduced_motion_pref)

    # Read cognitive_accessibility preference
    cognitive_accessibility_pref =
      Raxol.Core.UserPreferences.get([:accessibility, :cognitive_accessibility]) ||
        false

    cognitive_accessibility =
      Map.get(opts, :cognitive_accessibility, cognitive_accessibility_pref)

    default_duration = Map.get(opts, :default_duration, 300)
    frame_ms = Map.get(opts, :frame_ms, @animation_frame_ms)

    # Store framework settings via StateManager
    settings = %{
      reduced_motion: reduced_motion,
      cognitive_accessibility: cognitive_accessibility,
      default_duration: default_duration,
      frame_ms: frame_ms
    }

    StateManager.init(settings)

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
    # Get default settings via StateManager
    settings = StateManager.get_settings()
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

    # Store animation in registry via StateManager
    StateManager.put_animation(animation)

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
    # Get animation definition via StateManager
    animation_def = StateManager.get_animation(animation_name)

    if animation_def do
      # Check accessibility settings via StateManager
      settings = StateManager.get_settings()
      reduce_motion? = Map.get(settings, :reduced_motion, false)

      cognitive_accessibility? =
        Map.get(settings, :cognitive_accessibility, false)

      adapted_animation =
        cond do
          reduce_motion? ->
            AnimAccessibility.adapt_for_reduced_motion(animation_def)

          cognitive_accessibility? ->
            AnimAccessibility.adapt_for_cognitive_accessibility(animation_def)

          true ->
            animation_def
        end

      # Create animation instance
      instance = %{
        animation: adapted_animation,
        start_time: System.monotonic_time(:millisecond),
        on_complete: Map.get(opts, :on_complete),
        context: Map.get(opts, :context, %{})
      }

      # Store active animation via StateManager
      StateManager.put_active_animation(element_id, animation_name, instance)

      # Announce to screen reader if configured and not fully disabled by reduced motion
      should_announce =
        Map.get(adapted_animation, :announce_to_screen_reader, false) and
          not (reduce_motion? and
                 Map.get(adapted_animation, :disabled, false) == true)

      if should_announce do
        description = Map.get(adapted_animation, :description)

        message =
          if description,
            do: "#{description} started",
            else: "Animation started"

        Accessibility.announce(message)
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
    now = System.monotonic_time(:millisecond)
    # Get active animations via StateManager
    active_animations = StateManager.get_active_animations()

    # Process animations, collecting new state and completed animations
    {new_state, completed} =
      Enum.reduce(active_animations, {state, []}, fn {element_id,
                                                      element_animations},
                                                     {current_state,
                                                      completed_list} ->
        Enum.reduce(
          element_animations,
          {current_state, completed_list},
          fn {animation_name, instance}, {elem_state, elem_completed} ->
            # Call the modified apply_animation_to_state/6 (or similar) which returns status
            case apply_animation_to_state_internal(
                   elem_state,
                   element_id,
                   animation_name,
                   instance,
                   now
                 ) do
              {:ok, updated_elem_state} ->
                # Continue with updated state
                {updated_elem_state, elem_completed}

              {:completed, updated_elem_state} ->
                # Add to completed list and continue with updated state
                {updated_elem_state,
                 [{element_id, animation_name} | elem_completed]}
            end
          end
        )
      end)

    # Remove completed animations from state manager
    Enum.each(completed, fn {element_id, animation_name} ->
      StateManager.remove_active_animation(element_id, animation_name)
    end)

    new_state
  end

  defp apply_animation_to_state_internal(
         state,
         element_id,
         animation_name,
         instance,
         now
       ) do
    animation = instance.animation
    start_time = instance.start_time
    duration = animation.duration
    elapsed = now - start_time

    # Check for completion
    if elapsed >= duration do
      # Animation complete
      # Apply final value
      final_value = animation.to
      # Ensure target_path exists in the animation map
      path = Map.get(animation, :target_path)

      updated_state =
        if path do
          set_in_state(state, path, final_value)
        else
          Logger.error(
            "Animation #{animation_name} for element #{element_id} is missing :target_path."
          )

          # Return original state if path is missing
          state
        end

      # Announce completion if needed
      if Map.get(animation, :announce_to_screen_reader, false) do
        description = Map.get(animation, :description)

        message =
          if description,
            do: "#{description} completed",
            else: "Animation completed"

        Accessibility.announce(message)
      end

      # Call on_complete callback if provided
      if instance.on_complete do
        try do
          instance.on_complete.(%{
            element_id: element_id,
            animation_name: animation_name,
            context: instance.context
          })
        rescue
          e ->
            Logger.error(
              "Error in on_complete callback for animation #{animation_name}: #{inspect(e)}"
            )
        end
      end

      {:completed, updated_state}
    else
      # Animation in progress
      progress = if duration <= 0, do: 1.0, else: min(1.0, elapsed / duration)

      eased_progress =
        Raxol.Animation.Easing.calculate_value(animation.easing, progress)

      current_value =
        Raxol.Animation.Interpolate.value(
          animation.from,
          animation.to,
          eased_progress
        )

      # Ensure target_path exists in the animation map
      path = Map.get(animation, :target_path)

      unless path do
        Logger.error(
          "Animation #{animation_name} for element #{element_id} is missing :target_path."
        )

        # Skip update
        # Indicate normal progress
        {:ok, state}
      else
        updated_state = set_in_state(state, path, current_value)
        # Indicate normal progress
        {:ok, updated_state}
      end
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
    # Use StateManager to remove the animation
    StateManager.remove_active_animation(element_id, animation_name)
    # Ensure function returns something, :ok seems appropriate
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
    # Get all active animations via StateManager
    active_animations = StateManager.get_active_animations()

    # Access the specific instance using element_id and animation_name
    case get_in(active_animations, [element_id, animation_name]) do
      nil ->
        :not_found

      instance ->
        # Calculation logic remains the same for now
        current_time = System.monotonic_time(:millisecond)
        elapsed = current_time - instance.start_time
        animation = instance.animation
        duration = animation.duration

        # TODO: The check for animation[:disabled] might need refinement depending on how
        #       disabled state is handled (e.g., preventing start vs. instant completion).
        #       Assuming adapt_for_reduced_motion handles the main case for now.
        if duration <= 0 or elapsed >= duration do
          # Animation is done (or instant)
          {animation.to, true}
        else
          # Calculate progress (0.0 to 1.0)
          # duration already checked > 0
          progress = elapsed / duration

          # Apply easing function (using Interpolate module as seen elsewhere)
          eased_progress =
            Raxol.Animation.Easing.calculate_value(animation.easing, progress)

          # Interpolate value (using Interpolate module)
          value =
            Raxol.Animation.Interpolate.value(
              animation.from,
              animation.to,
              eased_progress
            )

          {value, false}
        end
    end
  end

  # Helper function to get value from nested state (might move later)
  # This is a simplified version, might need more robust implementation
  # Consider using Kernel.get_in/2 with Access syntax if paths are lists of keys
  defp get_in_state(state, path) when is_list(path) do
    # Use Kernel.get_in for list paths
    get_in(state, path)
  catch
    # Catch potential errors if path is invalid for the state structure
    :error, reason ->
      Logger.warning(
        "[Animation] Failed to get path #{inspect(path)} from state: #{inspect(reason)}"
      )

      # Or return an appropriate default/error indicator
      nil
  end

  # Handle potential non-list paths if necessary (e.g., single atom key)
  defp get_in_state(state, key) when not is_list(key) do
    # Assuming it might be a single key for a top-level map access
    Map.get(state, key)
  end

  # Helper function to set value in nested state (might move later)
  # Consider using Kernel.put_in/3 with Access syntax if paths are lists of keys
  defp set_in_state(state, path, value) when is_list(path) do
    # Use Kernel.put_in for list paths
    put_in(state, path, value)
  catch
    # Catch potential errors if path is invalid for the state structure
    :error, reason ->
      Logger.warning(
        "[Animation] Failed to set path #{inspect(path)} in state: #{inspect(reason)}"
      )

      # Return original state on error
      state
  end

  # Handle potential non-list paths if necessary
  defp set_in_state(state, key, value)
       when not is_list(key) and is_map(state) do
    Map.put(state, key, value)
  end

  defp set_in_state(state, key, _value)
       when not is_list(key) and not is_map(state) do
    # If key is not a list and state is not a map, we cannot proceed
    # This might happen if the path is incorrect or points to a scalar value
    Logger.warning(
      "[Animation] Path #{inspect(key)} is not a list and state is not a map. Cannot set value."
    )

    state
  end

  def should_reduce_motion? do
    # TODO: Use Accessibility module helper?
    reduced_motion_pref =
      Raxol.Core.UserPreferences.get([:accessibility, :reduced_motion]) || false

    reduced_motion_pref
  end

  def should_apply_cognitive_accessibility? do
    cognitive_pref =
      Raxol.Core.UserPreferences.get([:accessibility, :cognitive_accessibility]) ||
        false

    cognitive_pref
  end
end
