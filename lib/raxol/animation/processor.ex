defmodule Raxol.Animation.Processor do
  @moduledoc """
  Handles the processing of active animations and their application to state.

  This module is responsible for:
  - Processing active animations and calculating their current values
  - Applying animation values to the application state
  - Handling animation completion
  - Managing animation progress and timing
  """

  require Raxol.Core.Runtime.Log
  alias Raxol.Animation.StateManager, as: StateManager
  alias Raxol.Animation.Accessibility, as: AnimAccessibility
  alias Raxol.Animation.Lifecycle
  alias Raxol.Animation.Adaptation
  alias Raxol.Animation.PathManager

  @doc """
  Update animations and apply their current values to the state.

  ## Parameters

  * `state` - Current application state
  * `user_preferences_pid` - (Optional) The UserPreferences process pid or name for accessibility announcements

  ## Returns

  Updated state with animation values applied.
  """
  def apply_animations_to_state(state, user_preferences_pid \\ nil) do
    # Fetch active animations before re-adaptation
    active_animations_before = StateManager.get_active_animations()

    # Re-adapt existing animations if settings have changed, and get any that were completed due to being disabled
    completed_due_to_disable =
      Adaptation.re_adapt_animations_if_needed(
        user_preferences_pid,
        active_animations_before
      )

    now = System.system_time(:millisecond)

    # After re-adaptation, fetch active animations again in case any were updated or removed
    active_animations = StateManager.get_active_animations()

    # Ensure state has proper structure for animations
    state_with_elements = PathManager.ensure_state_structure(state, [:elements])

    # First, process completions due to re-adaptation
    Enum.each(completed_due_to_disable, fn {element_id, animation_name,
                                            instance} ->
      Lifecycle.handle_animation_completion(
        instance.animation,
        element_id,
        animation_name,
        instance,
        user_preferences_pid
      )

      StateManager.remove_active_animation(element_id, animation_name)
    end)

    {new_state, completed} =
      Enum.reduce(active_animations, {state_with_elements, []}, fn {element_id,
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

    # Remove completed animations from state manager
    Enum.each(completed, fn {element_id, animation_name} ->
      StateManager.remove_active_animation(element_id, animation_name)
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
      fn {animation_name, instance}, {state, completed} ->
        apply_animation_to_state_internal(
          instance,
          animation_name,
          element_id,
          state,
          completed,
          now,
          user_preferences_pid
        )
      end
    )
  end

  defp apply_animation_to_state_internal(
         instance,
         animation_name,
         element_id,
         state,
         completed_list,
         now,
         user_preferences_pid
       ) do
    animation = instance.animation
    start_time = instance.start_time
    elapsed = now - start_time
    duration = animation.duration

    # Check if animation should be completed
    is_disabled = AnimAccessibility.disabled?(animation)
    is_pending_completion = Map.get(instance, :pending_completion, false)

    should_complete = elapsed >= duration or (is_disabled and is_pending_completion)
    
    case should_complete do
      true ->
        # Calculate final value and apply to state before completion
        final_progress = 1.0
        final_value = calculate_current_value(animation, final_progress)

        updated_state =
          PathManager.set_in_state(state, animation.target_path, final_value)

        # Handle completion for both normal and disabled animations
        Lifecycle.handle_animation_completion(
          animation,
          element_id,
          animation_name,
          instance,
          user_preferences_pid
        )

        # Mark as completed
        {updated_state, [{element_id, animation_name} | completed_list]}
      false ->
        # Calculate current value and apply to state
        progress = calculate_animation_progress(animation, elapsed, duration)
        current_value = calculate_current_value(animation, progress)

        # Apply to state
        updated_state =
          PathManager.set_in_state(state, animation.target_path, current_value)

        {updated_state, completed_list}
    end
  end

  defp ease_in_out_quad(progress) when progress < 0.5 do
    2 * progress * progress
  end

  defp ease_in_out_quad(progress) do
    1 - 2 * (1 - progress) * (1 - progress)
  end

  defp ease_in_out_cubic(progress) when progress < 0.5 do
    4 * progress * progress * progress
  end

  defp ease_in_out_cubic(progress) do
    1 - 4 * (1 - progress) * (1 - progress) * (1 - progress)
  end

  defp interpolate_values(f, t, progress) when is_number(f) and is_number(t) do
    f + (t - f) * progress
  end

  defp interpolate_values(_f, t, _progress), do: t

  defp calculate_animation_progress(_animation, _elapsed, 0) do
    # Handle zero duration case - animation completes immediately
    1.0
  end

  defp calculate_animation_progress(animation, elapsed, duration) do
    # Ensure progress is between 0 and 1
    progress = min(max(elapsed / duration, 0.0), 1.0)

    # Apply easing if specified
    case Map.get(animation, :easing) do
      :ease_in_quad ->
        progress * progress

      :ease_out_quad ->
        1 - (1 - progress) * (1 - progress)

      :ease_in_out_quad ->
        ease_in_out_quad(progress)

      :ease_in_cubic ->
        progress * progress * progress

      :ease_out_cubic ->
        1 - (1 - progress) * (1 - progress) * (1 - progress)

      :ease_in_out_cubic ->
        ease_in_out_cubic(progress)

      _ ->
        progress
    end
  end

  defp calculate_current_value(animation, progress) do
    from = Map.get(animation, :from, 0)
    to = Map.get(animation, :to, 1)

    case {from, to} do
      {from_val, to_val} when is_number(from_val) and is_number(to_val) ->
        from_val + (to_val - from_val) * progress

      {from_val, to_val} when is_list(from_val) and is_list(to_val) ->
        Enum.zip_with(from_val, to_val, fn f, t ->
          interpolate_values(f, t, progress)
        end)

      _ ->
        to
    end
  end
end
