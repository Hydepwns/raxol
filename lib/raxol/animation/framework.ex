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

  # Define an animation (target_path can be a property, e.g., [:opacity])
  Raxol.Animation.Framework.create_animation(:fade_in, %{
    target_path: [:opacity], # Will be automatically scoped to the element's state
    duration: 300,
    easing: :ease_out_cubic,
    from: 0.0,
    to: 1.0
  })

  # Start the animation on an element
  # The framework will update [:elements, "my_element_id", :opacity] in the state
  Raxol.Animation.Framework.start_animation(:fade_in, "my_element_id")

  # In the application's update loop, apply animations to the state
  updated_state = Raxol.Animation.Framework.apply_animations_to_state(current_state)
  ```

  ### About `target_path`

  When defining an animation, you can specify `target_path` as a single property (e.g., `[:opacity]`).
  When you start the animation for a specific element, the framework will automatically scope the path to that element:
  - If you pass `element_id = "foo"` and `target_path = [:opacity]`, the animation will update `[:elements, "foo", :opacity]` in your state.
  - If you provide a fully qualified path (e.g., `[:elements, "foo", :opacity]`), it will be used as-is.
  """

  require Raxol.Core.Runtime.Log
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
  def init(opts \\ %{}, user_preferences_pid \\ nil) do
    Raxol.Core.Runtime.Log.debug("Initializing animation framework...")

    # Read reduced_motion preference
    reduced_motion_pref =
      Raxol.Core.UserPreferences.get(
        [:accessibility, :reduced_motion],
        user_preferences_pid
      ) || false

    reduced_motion = Map.get(opts, :reduced_motion, reduced_motion_pref)

    # Read cognitive_accessibility preference
    cognitive_accessibility_pref =
      Raxol.Core.UserPreferences.get(
        [:accessibility, :cognitive_accessibility],
        user_preferences_pid
      ) ||
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
  * `:target_path` - Path within the state to animate. This can be a property (e.g., `[:opacity]`),
    in which case the framework will scope it to the element's state when starting the animation.
    If you provide a fully qualified path (e.g., `[:elements, "my_element_id", :opacity]`), it will be used as-is.

  ## Examples

      iex> AnimationFramework.create_animation(:fade_in, %{
      ...>   type: :fade,
      ...>   duration: 300,
      ...>   easing: :ease_out_cubic,
      ...>   from: 0.0,
      ...>   to: 1.0,
      ...>   direction: :in,
      ...>   target_path: [:opacity] # Will be scoped to the element when started
      ...> })
      %{
        name: :fade_in,
        type: :fade,
        duration: 300,
        easing: :ease_out_cubic,
        from: 0.0,
        to: 1.0,
        direction: :in,
        target_path: [:opacity]
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
  * `user_preferences_pid` - (Optional) The UserPreferences process pid or name for accessibility announcements

  ## Options

  * `:on_complete` - Function to call when animation completes
  * `:context` - Additional context for the animation

  ## Path Scoping

  If the animation's `target_path` is a property (e.g., `[:opacity]`), the framework will automatically scope it to the element's state (e.g., `[:elements, element_id, :opacity]`).
  If you provide a fully qualified path, it will be used as-is.

  ## Examples

      iex> AnimationFramework.start_animation(:fade_in, "search_button", %{}, user_preferences_pid)
      :ok

      iex> AnimationFramework.start_animation(:slide_in, "panel", %{on_complete: &handle_complete/1}, user_preferences_pid)
      :ok
  """
  def start_animation(
        animation_name,
        element_id,
        opts \\ %{},
        user_preferences_pid \\ nil
      ) do
    # Get animation definition via StateManager
    animation_def = StateManager.get_animation(animation_name)

    if animation_def do
      # Generalize target_path: if it's a single property, prepend [:elements, element_id]
      animation_def = update_animation_path(animation_def, element_id)

      # Check accessibility settings via StateManager
      settings = StateManager.get_settings()
      reduce_motion? = Map.get(settings, :reduced_motion, false)

      cognitive_accessibility? =
        Map.get(settings, :cognitive_accessibility, false)

      # Adapt animation for accessibility
      adapted_animation =
        AnimAccessibility.adapt_animation(
          animation_def,
          reduce_motion?,
          cognitive_accessibility?
        )

      # Build animation instance
      instance = %{
        animation: adapted_animation,
        start_time: System.unique_integer([:positive]),
        on_complete: Map.get(opts, :on_complete),
        context: Map.get(opts, :context)
      }

      # Register animation instance
      StateManager.put_active_animation(
        element_id,
        animation_def.name,
        instance
      )

      # Handle screen reader announcement
      maybe_announce_animation(
        adapted_animation,
        reduce_motion?,
        user_preferences_pid
      )

      # Always send animation_started message for test synchronization
      send(self(), {:animation_started, element_id, animation_def.name})
      :ok
    else
      {:error, :animation_not_found}
    end
  end

  defp maybe_announce_animation(animation, reduce_motion?, user_preferences_pid) do
    should_announce =
      Map.get(animation, :announce_to_screen_reader, false) and
        not (reduce_motion? and Map.get(animation, :disabled, false) == true)

    if should_announce do
      description = Map.get(animation, :description)

      message =
        if description, do: "#{description} started", else: "Animation started"

      Accessibility.announce(message, user_preferences_pid)
    end
  end

  defp update_animation_path(animation_def, element_id) do
    case Map.get(animation_def, :target_path) do
      [^element_id | _] ->
        # Already starts with element_id (rare, but just in case)
        animation_def

      [:elements, ^element_id | _] ->
        # Already fully qualified
        animation_def

      [property] when is_atom(property) or is_binary(property) ->
        Map.put(animation_def, :target_path, [
          :elements,
          to_string(element_id),
          property
        ])

      path when is_list(path) ->
        qualify_path(animation_def, path, element_id)

      _ ->
        animation_def
    end
  end

  defp qualify_path(animation_def, path, element_id) do
    case path do
      [:elements, id | _] ->
        id_str = if is_binary(id), do: id, else: to_string(id)
        elem_id_str = to_string(element_id)

        if id == element_id or id_str == elem_id_str do
          animation_def
        else
          Map.put(
            animation_def,
            :target_path,
            [:elements, elem_id_str] ++ path
          )
        end

      _ ->
        Map.put(
          animation_def,
          :target_path,
          [:elements, to_string(element_id)] ++ path
        )
    end
  end

  @doc """
  Update animations and apply their current values to the state.

  ## Parameters

  * `state` - Current application state
  * `user_preferences_pid` - (Optional) The UserPreferences process pid or name for accessibility announcements

  ## Returns

  Updated state with animation values applied.
  """
  def apply_animations_to_state(state, user_preferences_pid \\ nil) do
    now = System.monotonic_time(:millisecond)
    active_animations = StateManager.get_active_animations()

    {new_state, completed} =
      Enum.reduce(active_animations, {state, []}, fn {element_id,
                                                      element_animations},
                                                     {current_state,
                                                      completed_list} ->
        process_element_animations(
          element_animations,
          element_id,
          current_state,
          completed_list,
          now,
          user_preferences_pid
        )
      end)

    Enum.each(completed, fn {element_id, animation_name} ->
      StateManager.remove_active_animation(element_id, animation_name)
      send(self(), {:animation_completed, element_id, animation_name})
    end)

    new_state
  end

  defp process_element_animations(
         element_animations,
         element_id,
         current_state,
         completed_list,
         now,
         user_preferences_pid
       ) do
    Enum.reduce(
      element_animations,
      {current_state, completed_list},
      fn {animation_name, instance}, {elem_state, elem_completed} ->
        case apply_animation_to_state_internal(
               elem_state,
               element_id,
               animation_name,
               instance,
               now,
               user_preferences_pid
             ) do
          {:ok, updated_elem_state} ->
            {updated_elem_state, elem_completed}

          {:completed, updated_elem_state} ->
            {updated_elem_state,
             [{element_id, animation_name} | elem_completed]}
        end
      end
    )
  end

  defp apply_animation_to_state_internal(
         state,
         element_id,
         animation_name,
         instance,
         now,
         user_preferences_pid
       ) do
    animation = instance.animation
    start_time = instance.start_time
    duration = animation.duration
    elapsed = now - start_time

    # Check for completion
    if elapsed >= duration or Map.get(animation, :disabled, false) do
      # Animation complete
      # Apply final value
      final_value = animation.to

      updated_state =
        update_state_with_path(
          state,
          animation,
          final_value,
          element_id,
          animation_name
        )

      handle_animation_completion(
        animation,
        element_id,
        animation_name,
        instance,
        user_preferences_pid
      )

      {:completed, updated_state}
    else
      case calculate_animation_progress(animation, elapsed, duration) do
        {:ok, current_value} ->
          updated_state =
            update_state_with_path(
              state,
              animation,
              current_value,
              element_id,
              animation_name
            )

          {:ok, updated_state}
      end
    end
  end

  defp update_state_with_path(
         state,
         animation,
         value,
         element_id,
         animation_name
       ) do
    path = Map.get(animation, :target_path)

    if path do
      set_in_state(state, path, value)
    else
      Raxol.Core.Runtime.Log.error(
        "Animation #{animation_name} for element #{element_id} is missing :target_path."
      )

      state
    end
  end

  defp calculate_animation_progress(animation, elapsed, duration) do
    progress = if duration <= 0, do: 1.0, else: min(1.0, elapsed / duration)

    eased_progress =
      Raxol.Animation.Easing.calculate_value(animation.easing, progress)

    current_value =
      Raxol.Animation.Interpolate.value(
        animation.from,
        animation.to,
        eased_progress
      )

    {:ok, current_value}
  end

  defp handle_animation_completion(
         animation,
         element_id,
         animation_name,
         instance,
         user_preferences_pid
       ) do
    # Announce completion if needed
    if Map.get(animation, :announce_to_screen_reader, false) do
      description = Map.get(animation, :description)

      message =
        if description,
          do: "#{description} completed",
          else: "Animation completed"

      Accessibility.announce(message, [], user_preferences_pid)
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
          Raxol.Core.Runtime.Log.error(
            "Error in on_complete callback for animation #{animation_name}: #{inspect(e)}"
          )
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
    # Send completion message since we're stopping the animation
    send(self(), {:animation_completed, element_id, animation_name})
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

  # Helper function to set value in nested state (might move later)
  # Consider using Kernel.put_in/3 with Access syntax if paths are lists of keys
  defp set_in_state(state, path, value) when is_list(path) do
    # Use Kernel.put_in for list paths
    put_in(state, path, value)
  catch
    # Catch potential errors if path is invalid for the state structure
    :error, reason ->
      Raxol.Core.Runtime.Log.warning_with_context(
        "[Animation] Failed to set path #{inspect(path)} in state: #{inspect(reason)}",
        %{path: path, reason: reason}
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
    Raxol.Core.Runtime.Log.warning_with_context(
      "[Animation] Path #{inspect(key)} is not a list and state is not a map. Cannot set value.",
      %{}
    )

    state
  end

  def should_reduce_motion?(user_preferences_pid \\ nil) do
    reduced_motion_pref =
      Raxol.Core.UserPreferences.get(
        [:accessibility, :reduced_motion],
        user_preferences_pid
      ) || false

    reduced_motion_pref
  end

  def should_apply_cognitive_accessibility? do
    cognitive_pref =
      Raxol.Core.UserPreferences.get([:accessibility, :cognitive_accessibility]) ||
        false

    cognitive_pref
  end

  @doc """
  Stops all animations and clears animation state. Used for test cleanup.
  """
  def stop do
    Raxol.Animation.StateManager.clear_all()
    :ok
  end
end
