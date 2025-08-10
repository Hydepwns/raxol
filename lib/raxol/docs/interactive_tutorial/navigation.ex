defmodule Raxol.Docs.InteractiveTutorial.Navigation do
  import Raxol.Guards

  @moduledoc """
  Handles navigation and progress tracking for tutorials.
  """

  alias Raxol.Docs.InteractiveTutorial.State

  @doc """
  Starts a tutorial by ID.
  """
  def start_tutorial(state, tutorial_id) do
    case Map.get(state.tutorials, tutorial_id) do
      nil ->
        {:error, "Tutorial not found"}

      tutorial ->
        # Get the first step or last accessed step
        progress =
          Map.get(state.progress, tutorial_id, %{
            completed: false,
            completed_steps: [],
            last_step: nil
          })

        step_id = progress.last_step || List.first(tutorial.steps).id

        # Update state
        updated_state = %{
          state
          | current_tutorial: tutorial_id,
            current_step: step_id,
            history: [{:tutorial_start, tutorial_id, step_id} | state.history]
        }

        {:ok, State.get_current_step(updated_state)}
    end
  end

  @doc """
  Goes to the next step in the current tutorial.
  """
  def next_step(state) do
    with tutorial_id when not nil?(tutorial_id) <- state.current_tutorial,
         step_id when not nil?(step_id) <- state.current_step,
         tutorial when not nil?(tutorial) <-
           Map.get(state.tutorials, tutorial_id) do
      current_index = Enum.find_index(tutorial.steps, &(&1.id == step_id))

      if current_index < length(tutorial.steps) - 1 do
        next_step = Enum.at(tutorial.steps, current_index + 1)

        updated_state =
          state
          |> Map.put(:current_step, next_step.id)
          |> Map.update!(
            :history,
            &[{:step_change, tutorial_id, next_step.id} | &1]
          )
          |> State.update_progress(tutorial_id, next_step.id)

        {:ok, State.get_current_step(updated_state), updated_state}
      else
        # This was the last step, mark tutorial as completed
        state
        |> State.mark_completed(tutorial_id)
        |> Map.update!(:history, &[{:tutorial_complete, tutorial_id} | &1])
        |> then(fn _ -> {:ok, :tutorial_completed} end)
      end
    else
      _ -> {:error, "No tutorial in progress"}
    end
  end

  @doc """
  Goes to the previous step in the current tutorial.
  """
  def previous_step(state) do
    with tutorial_id when not nil?(tutorial_id) <- state.current_tutorial,
         step_id when not nil?(step_id) <- state.current_step,
         tutorial when not nil?(tutorial) <-
           Map.get(state.tutorials, tutorial_id) do
      current_index = Enum.find_index(tutorial.steps, &(&1.id == step_id))

      if current_index > 0 do
        prev_step = Enum.at(tutorial.steps, current_index - 1)

        updated_state = %{
          state
          | current_step: prev_step.id,
            history: [{:step_change, tutorial_id, prev_step.id} | state.history]
        }

        {:ok, State.get_current_step(updated_state), updated_state}
      else
        {:error, "Already at first step"}
      end
    else
      _ -> {:error, "No tutorial in progress"}
    end
  end

  @doc """
  Jumps to a specific step in the current tutorial.
  """
  def jump_to_step(state, step_id) do
    with tutorial_id when not nil?(tutorial_id) <- state.current_tutorial,
         tutorial when not nil?(tutorial) <-
           Map.get(state.tutorials, tutorial_id),
         true <- Enum.any?(tutorial.steps, &(&1.id == step_id)) do
      updated_state = %{
        state
        | current_step: step_id,
          history: [{:step_jump, tutorial_id, step_id} | state.history]
      }

      {:ok, State.get_current_step(updated_state)}
    else
      _ -> {:error, "Invalid step or no tutorial in progress"}
    end
  end

  @doc """
  Gets the progress for a tutorial.
  """
  def get_progress(state, tutorial_id) do
    case Map.get(state.tutorials, tutorial_id) do
      nil ->
        {:error, "Tutorial not found"}

      tutorial ->
        progress =
          Map.get(state.progress, tutorial_id, %{
            completed: false,
            completed_steps: [],
            last_step: nil
          })

        total_steps = length(tutorial.steps)
        completed_steps = length(progress.completed_steps)

        percentage =
          if total_steps > 0, do: completed_steps / total_steps * 100, else: 0

        {:ok,
         %{
           tutorial_id: tutorial_id,
           completed: progress.completed,
           completed_steps: progress.completed_steps,
           last_step: progress.last_step,
           total_steps: total_steps,
           completed_count: completed_steps,
           percentage: percentage
         }}
    end
  end
end
