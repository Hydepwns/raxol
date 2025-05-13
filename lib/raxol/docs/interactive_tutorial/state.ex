defmodule Raxol.Docs.InteractiveTutorial.State do
  @moduledoc """
  Manages the state of the interactive tutorial system.
  """

  alias Raxol.Docs.InteractiveTutorial.Models.{Tutorial, Step}

  @type tutorial_id :: String.t()
  @type step_id :: String.t()
  @type progress :: %{
          completed: boolean(),
          completed_steps: [step_id()],
          last_step: step_id() | nil
        }

  defstruct [
    :tutorials,
    :current_tutorial,
    :current_step,
    :progress,
    :bookmarks,
    :history
  ]

  @type t :: %__MODULE__{
          tutorials: %{tutorial_id() => Tutorial.t()},
          current_tutorial: tutorial_id() | nil,
          current_step: step_id() | nil,
          progress: %{tutorial_id() => progress()},
          bookmarks: %{tutorial_id() => step_id()},
          history: [{atom(), tutorial_id(), step_id()}]
        }

  @doc """
  Creates a new empty state.
  """
  def new do
    %__MODULE__{
      tutorials: %{},
      current_tutorial: nil,
      current_step: nil,
      progress: %{},
      bookmarks: %{},
      history: []
    }
  end

  @doc """
  Gets the current step from the state.
  """
  def get_current_step(%__MODULE__{} = state) do
    with tutorial_id when not is_nil(tutorial_id) <- state.current_tutorial,
         step_id when not is_nil(step_id) <- state.current_step,
         tutorial when not is_nil(tutorial) <-
           Map.get(state.tutorials, tutorial_id),
         step when not is_nil(step) <-
           Enum.find(tutorial.steps, &(&1.id == step_id)) do
      step
    else
      _ -> nil
    end
  end

  @doc """
  Updates the progress for a tutorial.
  """
  def update_progress(%__MODULE__{} = state, tutorial_id, step_id) do
    progress =
      Map.get(state.progress, tutorial_id, %{
        completed: false,
        completed_steps: [],
        last_step: nil
      })

    updated_progress = %{
      progress
      | completed_steps: [step_id | progress.completed_steps] |> Enum.uniq(),
        last_step: step_id
    }

    %{state | progress: Map.put(state.progress, tutorial_id, updated_progress)}
  end

  @doc """
  Marks a tutorial as completed.
  """
  def mark_completed(%__MODULE__{} = state, tutorial_id) do
    progress =
      Map.get(state.progress, tutorial_id, %{
        completed: false,
        completed_steps: [],
        last_step: nil
      })

    updated_progress = %{progress | completed: true}
    %{state | progress: Map.put(state.progress, tutorial_id, updated_progress)}
  end
end
