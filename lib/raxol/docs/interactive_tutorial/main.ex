defmodule Raxol.Docs.InteractiveTutorial do
  @moduledoc """
  Interactive tutorial system for Raxol documentation.

  This module provides a framework for creating and displaying interactive
  tutorials that guide users through Raxol features with hands-on examples
  and step-by-step instructions.

  Features:
  * Step-by-step guides with interactive examples
  * Progress tracking and bookmarking
  * Exercise validation
  * Contextual hints and help
  * Integration with documentation
  """

  alias Raxol.Docs.InteractiveTutorial.{
    State,
    SimpleLoader,
    Navigation,
    Validation,
    Renderer
  }

  # Process dictionary key for tutorial state
  @state_key :raxol_tutorial_state

  @doc """
  Initializes the tutorial system.
  """
  def init do
    initial_state = State.new()

    # Load tutorials
    state =
      SimpleLoader.load_tutorials()
      |> Enum.reduce(initial_state, fn tutorial, acc ->
        register_tutorial(tutorial, acc)
      end)

    Raxol.Core.StateManager.set_state(@state_key, state)
    :ok
  end

  @doc """
  Registers a new tutorial.
  """
  def register_tutorial(tutorial, state \\ nil) do
    with_state(state, fn s ->
      %{s | tutorials: Map.put(s.tutorials, tutorial.id, tutorial)}
    end)
  end

  @doc """
  Returns a list of all available tutorials.
  """
  def list_tutorials do
    with_state(fn state ->
      tutorials =
        state.tutorials
        |> Map.values()
        |> Enum.map(fn tutorial ->
          # Add progress information
          progress =
            Map.get(state.progress, tutorial.id, %{
              completed: false,
              completed_steps: [],
              last_step: nil
            })

          Map.put(tutorial, :progress, progress)
        end)

      {state, tutorials}
    end)
  end

  @doc """
  Starts a tutorial by ID.
  """
  def start_tutorial(tutorial_id) do
    with_state(fn state ->
      case Navigation.start_tutorial(state, tutorial_id) do
        {:ok, step} ->
          tutorial = Map.get(state.tutorials, tutorial_id)

          updated_state = %{
            state
            | current_tutorial: tutorial_id,
              current_step: if(step, do: step.id, else: nil)
          }

          {updated_state, {:ok, tutorial}}

        {:error, reason} ->
          {state, {:error, reason}}
      end
    end)
  end

  @doc """
  Goes to the next step in the current tutorial.
  """
  def next_step do
    with_state(fn state ->
      case Navigation.next_step(state) do
        {:ok, step, updated_state} when is_map(step) ->
          {updated_state, {:ok, step}}

        {:ok, :tutorial_completed} ->
          {state, {:ok, :tutorial_completed}}

        {:error, reason} ->
          {state, {:error, reason}}

        other ->
          {state, {:error, "Unexpected response: #{inspect(other)}"}}
      end
    end)
  end

  @doc """
  Goes to the previous step in the current tutorial.
  """
  def previous_step do
    with_state(fn state ->
      case Navigation.previous_step(state) do
        {:ok, step, updated_state} ->
          {updated_state, {:ok, step}}

        {:error, reason} ->
          {state, {:error, reason}}
      end
    end)
  end

  @doc """
  Jumps to a specific step in the current tutorial.
  """
  def jump_to_step(step_id) do
    with_state(fn state ->
      case Navigation.jump_to_step(state, step_id) do
        {:ok, step} ->
          updated_state = %{state | current_step: step_id}
          {updated_state, {:ok, step}}

        {:error, reason} ->
          {state, {:error, reason}}
      end
    end)
  end

  @doc """
  Gets the progress for a tutorial.
  """
  def get_progress(tutorial_id) do
    with_state(fn state ->
      progress = Navigation.get_progress(state, tutorial_id)
      {state, progress}
    end)
  end

  @doc """
  Gets the current position in the tutorial.
  """
  def get_current_position do
    with_state(fn state ->
      case State.get_current_step(state) do
        nil ->
          {state, nil}

        step ->
          {state, {Map.get(state.tutorials, state.current_tutorial), step}}
      end
    end)
  end

  @doc """
  Validates a solution for the current step.
  """
  def validate_exercise(solution) do
    with_state(fn state ->
      case State.get_current_step(state) do
        nil ->
          {state, {:error, "No tutorial in progress"}}

        step ->
          result = Validation.validate_solution(step, solution)
          {state, result}
      end
    end)
  end

  @doc """
  Gets a hint for the current step.
  """
  def get_hint do
    with_state(fn state ->
      case State.get_current_step(state) do
        nil ->
          {state, {:error, "No tutorial in progress"}}

        step ->
          result =
            case step.hints do
              [] -> {:error, "No hints available"}
              hints -> {:ok, List.first(hints)}
            end

          {state, result}
      end
    end)
  end

  @doc """
  Renders the current step's content.
  """
  def render_current_step do
    with_state(fn state ->
      case State.get_current_step(state) do
        nil ->
          {state, {:error, "No tutorial in progress"}}

        step ->
          result = Renderer.render_step(step)
          {state, result}
      end
    end)
  end

  @doc """
  Renders interactive elements for the current step.
  """
  def render_interactive_elements do
    with_state(fn state ->
      case State.get_current_step(state) do
        nil ->
          {state, {:error, "No tutorial in progress"}}

        step ->
          result = Renderer.render_interactive_elements(step)
          {state, result}
      end
    end)
  end

  # Helper function to work with state
  defp with_state(state \\ nil, fun) do
    current_state = state || Raxol.Core.StateManager.get_state(@state_key) || State.new()

    case fun.(current_state) do
      {updated_state, result} ->
        Raxol.Core.StateManager.set_state(@state_key, updated_state)
        result

      updated_state when is_map(updated_state) ->
        Raxol.Core.StateManager.set_state(@state_key, updated_state)
        updated_state
    end
  end
end
