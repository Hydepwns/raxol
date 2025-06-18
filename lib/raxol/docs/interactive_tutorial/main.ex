defmodule Raxol.Docs.InteractiveTutorial do
  @moduledoc '''
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
  '''

  alias Raxol.Docs.InteractiveTutorial.{
    State,
    Loader,
    Navigation,
    Validation,
    Renderer
  }

  # Process dictionary key for tutorial state
  @state_key :raxol_tutorial_state

  @doc '''
  Initializes the tutorial system.
  '''
  def init do
    initial_state = State.new()

    # Load tutorials from Markdown files
    state =
      Loader.load_tutorials_from_markdown("docs/tutorials")
      |> Enum.reduce(initial_state, fn tutorial, acc ->
        register_tutorial(tutorial, acc)
      end)

    Process.put(@state_key, state)
    :ok
  end

  @doc '''
  Registers a new tutorial.
  '''
  def register_tutorial(tutorial, state \\ nil) do
    with_state(state, fn s ->
      %{s | tutorials: Map.put(s.tutorials, tutorial.id, tutorial)}
    end)
  end

  @doc '''
  Returns a list of all available tutorials.
  '''
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

  @doc '''
  Starts a tutorial by ID.
  '''
  def start_tutorial(tutorial_id) do
    with_state(fn state ->
      Navigation.start_tutorial(state, tutorial_id)
    end)
  end

  @doc '''
  Goes to the next step in the current tutorial.
  '''
  def next_step do
    with_state(fn state ->
      Navigation.next_step(state)
    end)
  end

  @doc '''
  Goes to the previous step in the current tutorial.
  '''
  def previous_step do
    with_state(fn state ->
      Navigation.previous_step(state)
    end)
  end

  @doc '''
  Jumps to a specific step in the current tutorial.
  '''
  def jump_to_step(step_id) do
    with_state(fn state ->
      Navigation.jump_to_step(state, step_id)
    end)
  end

  @doc '''
  Gets the progress for a tutorial.
  '''
  def get_progress(tutorial_id) do
    with_state(fn state ->
      Navigation.get_progress(state, tutorial_id)
    end)
  end

  @doc '''
  Gets the current position in the tutorial.
  '''
  def get_current_position do
    with_state(fn state ->
      case State.get_current_step(state) do
        nil ->
          nil

        step ->
          {state, {Map.get(state.tutorials, state.current_tutorial), step}}
      end
    end)
  end

  @doc '''
  Validates a solution for the current step.
  '''
  def validate_exercise(solution) do
    with_state(fn state ->
      case State.get_current_step(state) do
        nil -> {:error, "No tutorial in progress"}
        step -> Validation.validate_solution(step, solution)
      end
    end)
  end

  @doc '''
  Gets a hint for the current step.
  '''
  def get_hint do
    with_state(fn state ->
      case State.get_current_step(state) do
        nil ->
          {:error, "No tutorial in progress"}

        step ->
          case step.hints do
            [] -> {:error, "No hints available"}
            hints -> {:ok, List.first(hints)}
          end
      end
    end)
  end

  @doc '''
  Renders the current step's content.
  '''
  def render_current_step do
    with_state(fn state ->
      case State.get_current_step(state) do
        nil -> {:error, "No tutorial in progress"}
        step -> Renderer.render_step(step)
      end
    end)
  end

  @doc '''
  Renders interactive elements for the current step.
  '''
  def render_interactive_elements do
    with_state(fn state ->
      case State.get_current_step(state) do
        nil -> {:error, "No tutorial in progress"}
        step -> Renderer.render_interactive_elements(step)
      end
    end)
  end

  # Helper function to work with state
  defp with_state(state \\ nil, fun) do
    current_state = state || Process.get(@state_key)
    {updated_state, result} = fun.(current_state)
    Process.put(@state_key, updated_state)
    result
  end
end
