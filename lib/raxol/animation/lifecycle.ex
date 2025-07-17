defmodule Raxol.Animation.Lifecycle do
  @moduledoc """
  Manages the lifecycle of animations including starting, stopping, and completion handling.

  This module is responsible for:
  - Starting animations on elements
  - Stopping animations
  - Handling animation completion and callbacks
  - Managing animation announcements and accessibility
  """

  require Raxol.Core.Runtime.Log
  alias Raxol.Core.Accessibility
  alias Raxol.Animation.StateManager
  alias Raxol.Animation.Accessibility, as: AnimAccessibility
  alias Raxol.Animation.PathManager

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
      animation_def = PathManager.update_animation_path(animation_def, element_id)

      # Check accessibility settings via StateManager
      settings = StateManager.get_settings()
      reduce_motion? = Map.get(settings, :reduced_motion, false)

      cognitive_accessibility? =
        Map.get(settings, :cognitive_accessibility, false)

      disable_all_animations? =
        Map.get(settings, :disable_all_animations, false)

      # Adapt animation for accessibility and global disable
      adapted_animation =
        if disable_all_animations? do
          animation_def
          |> Map.put(:duration, 10)
          |> Map.put(:disabled, true)
        else
          AnimAccessibility.adapt_animation(
            animation_def,
            reduce_motion?,
            cognitive_accessibility?
          )
        end

      notify_pid = Map.get(opts, :notify_pid, self())

      # Build animation instance
      instance = %{
        animation: adapted_animation,
        start_time: System.system_time(:millisecond),
        on_complete: Map.get(opts, :on_complete),
        context: Map.get(opts, :context),
        notify_pid: notify_pid
      }

      # Register animation instance
      StateManager.put_active_animation(
        element_id,
        animation_def.name,
        instance
      )

      # Always send animation_started message for test synchronization
      send(notify_pid, {:animation_started, element_id, animation_def.name})

      # Announce animation start to screen reader if needed
      if Map.get(adapted_animation, :announce_to_screen_reader, false) do
        description = Map.get(adapted_animation, :description)

        message =
          if description,
            do: "#{description} started",
            else: "Animation started"

        Accessibility.announce(message, [], user_preferences_pid)
      end

      # If animation is disabled (e.g., by reduced motion), mark as pending completion
      if AnimAccessibility.disabled?(adapted_animation) do
        # Mark the instance as pending completion
        pending_instance = Map.put(instance, :pending_completion, true)

        StateManager.put_active_animation(
          element_id,
          animation_def.name,
          pending_instance
        )
      end

      :ok
    else
      {:error, :animation_not_found}
    end
  end

  @doc """
  Stop an animation for a specific element.

  ## Parameters

  * `animation_name` - The name of the animation to stop
  * `element_id` - Identifier for the element

  ## Returns

  * `:ok` - Animation was stopped successfully
  * `{:error, :animation_not_found}` - Animation was not found
  """
  def stop_animation(animation_name, element_id) do
    case StateManager.get_active_animation(element_id, animation_name) do
      nil ->
        {:error, :animation_not_found}

      instance ->
        # Call on_complete callback if provided
        if instance.on_complete do
          try do
            instance.on_complete.(instance.context)
          rescue
            e ->
              Raxol.Core.Runtime.Log.error(
                "Error in animation on_complete callback: #{inspect(e)}"
              )
          end
        end

        # Remove from active animations
        StateManager.remove_active_animation(element_id, animation_name)

        # Send completion message
        send(instance.notify_pid, {:animation_completed, element_id, animation_name})

        :ok
    end
  end

  @doc """
  Handle animation completion, including callbacks and notifications.

  This function is called when an animation completes, either naturally or due to being disabled.
  """
  def handle_animation_completion(
        animation,
        element_id,
        animation_name,
        instance,
        user_preferences_pid
      ) do
    # Call on_complete callback if provided
    if instance.on_complete do
      try do
        instance.on_complete.(instance.context)
      rescue
        e ->
          Raxol.Core.Runtime.Log.error(
            "Error in animation on_complete callback: #{inspect(e)}"
          )
      end
    end

    # Send completion message to notify_pid
    if instance.notify_pid do
      send(instance.notify_pid, {:animation_completed, element_id, animation_name})
    end

    # Announce completion to screen reader if needed
    if Map.get(animation, :announce_to_screen_reader, false) do
      description = Map.get(animation, :description)

      message =
        if description,
          do: "#{description} completed",
          else: "Animation completed"

      Accessibility.announce(message, [], user_preferences_pid)
    end
  end

  @doc """
  Get the current value of an animation for a specific element.

  ## Parameters

  * `animation_name` - The name of the animation
  * `element_id` - Identifier for the element

  ## Returns

  * `{:ok, value}` - Current animation value
  * `{:error, :animation_not_found}` - Animation was not found
  """
  def get_current_value(animation_name, element_id) do
    case StateManager.get_active_animation(element_id, animation_name) do
      nil ->
        {:error, :animation_not_found}

      instance ->
        animation = instance.animation
        start_time = instance.start_time
        now = System.system_time(:millisecond)
        elapsed = now - start_time
        duration = animation.duration

        if elapsed >= duration do
          # Animation is complete, return final value
          {:ok, Map.get(animation, :to, 1)}
        else
          # Calculate current value
          progress = min(max(elapsed / duration, 0.0), 1.0)
          from = Map.get(animation, :from, 0)
          to = Map.get(animation, :to, 1)

          current_value =
            case {from, to} do
              {from_val, to_val} when is_number(from_val) and is_number(to_val) ->
                from_val + (to_val - from_val) * progress

              {from_val, to_val} when is_list(from_val) and is_list(to_val) ->
                Enum.zip_with(from_val, to_val, fn f, t ->
                  if is_number(f) and is_number(t) do
                    f + (t - f) * progress
                  else
                    t
                  end
                end)

              _ ->
                to
            end

          {:ok, current_value}
        end
    end
  end
end
