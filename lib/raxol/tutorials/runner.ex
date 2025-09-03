defmodule Raxol.Tutorials.Runner do
  @moduledoc """
  Interactive tutorial runner for Raxol.

  This module provides a command-line interface for running interactive tutorials,
  managing progress, and providing a guided learning experience.
  """

  use GenServer
  require Logger

  alias Raxol.Docs.InteractiveTutorial
  alias Raxol.Core.ErrorHandling
  # Tutorial runner functionality - aliases will be added as needed

  defstruct [
    :current_tutorial,
    :progress,
    :state,
    :input_buffer,
    :display_mode
  ]

  # Client API

  @doc """
  Starts the tutorial runner.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Lists all available tutorials.
  """
  def list_tutorials(server \\ __MODULE__) do
    GenServer.call(server, :list_tutorials)
  end

  @doc """
  Starts a specific tutorial by ID.
  """
  def start_tutorial(tutorial_id, server \\ __MODULE__) do
    GenServer.call(server, {:start_tutorial, tutorial_id})
  end

  @doc """
  Displays the current step.
  """
  def show_current(server \\ __MODULE__) do
    GenServer.call(server, :show_current)
  end

  @doc """
  Advances to the next step.
  """
  def next_step(server \\ __MODULE__) do
    GenServer.call(server, :next_step)
  end

  @doc """
  Goes back to the previous step.
  """
  def previous_step(server \\ __MODULE__) do
    GenServer.call(server, :previous_step)
  end

  @doc """
  Runs the code example for the current step.
  """
  def run_example do
    GenServer.call(__MODULE__, :run_example)
  end

  @doc """
  Submits a solution for the current exercise.
  """
  def submit_solution(code) do
    GenServer.call(__MODULE__, {:submit_solution, code})
  end

  @doc """
  Gets a hint for the current step.
  """
  def get_hint do
    GenServer.call(__MODULE__, :get_hint)
  end

  @doc """
  Shows the current progress.
  """
  def show_progress do
    GenServer.call(__MODULE__, :show_progress)
  end

  @doc """
  Exits the tutorial runner.
  """
  def exit do
    GenServer.stop(__MODULE__)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Initialize tutorial system
    InteractiveTutorial.init()

    state = %__MODULE__{
      current_tutorial: nil,
      progress: %{},
      state: :idle,
      input_buffer: "",
      display_mode: :terminal
    }

    # Print welcome message
    print_welcome()

    {:ok, state}
  end

  @impl true
  def handle_call(:list_tutorials, _from, state) do
    tutorials = InteractiveTutorial.list_tutorials()

    output = format_tutorial_list(tutorials)
    {:reply, {:ok, output}, state}
  end

  @impl true
  def handle_call({:start_tutorial, tutorial_id}, _from, state) do
    case InteractiveTutorial.start_tutorial(tutorial_id) do
      {:ok, tutorial} ->
        new_state = %{
          state
          | current_tutorial: tutorial,
            state: :in_tutorial
        }

        output = format_tutorial_start(tutorial)
        {:reply, {:ok, output}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:show_current, _from, %{state: :idle} = state) do
    {:reply,
     {:error, "No tutorial active. Use 'start <tutorial_id>' to begin."},
     state}
  end

  def handle_call(:show_current, _from, %{state: :in_tutorial} = state) do
    output = format_current_step(state)
    {:reply, {:ok, output}, state}
  end

  @impl true
  def handle_call(:next_step, _from, state) do
    case InteractiveTutorial.next_step() do
      {:ok, :tutorial_completed} ->
        output = """

        #{IO.ANSI.green()}✓ Congratulations! You've completed this tutorial!#{IO.ANSI.reset()}

        Type 'list' to see other tutorials or 'exit' to quit.
        """

        {:reply, {:ok, output}, state}

      {:ok, step} ->
        output = format_step(step)
        {:reply, {:ok, output}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:previous_step, _from, state) do
    case InteractiveTutorial.previous_step() do
      {:ok, step} when is_map(step) ->
        output = format_step(step)
        {:reply, {:ok, output}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:run_example, _from, state) do
    with {_tutorial, step} <- InteractiveTutorial.get_current_position(),
         result = run_example_code(step.example_code),
         output = format_example_result(result) do
      {:reply, {:ok, output}, state}
    else
      nil -> {:reply, {:error, "No active step"}, state}
    end
  end

  @impl true
  def handle_call({:submit_solution, code}, _from, state) do
    case InteractiveTutorial.validate_exercise(code) do
      {:ok, message} ->
        # Update progress
        new_progress =
          update_progress(
            state.progress,
            state.current_tutorial,
            state.current_step
          )

        new_state = %{state | progress: new_progress}

        output = format_success(message)
        {:reply, {:ok, output}, new_state}

      {:error, reason} ->
        output = format_error(reason)
        {:reply, {:ok, output}, state}
    end
  end

  @impl true
  def handle_call(:get_hint, _from, state) do
    case InteractiveTutorial.get_hint() do
      {:ok, hint} ->
        output = format_hint(hint)
        {:reply, {:ok, output}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:show_progress, _from, state) do
    output = format_progress(state.progress, state.current_tutorial)
    {:reply, {:ok, output}, state}
  end

  # Private Functions

  defp print_welcome do
    IO.puts("""

    #{IO.ANSI.cyan()}╔════════════════════════════════════════════╗
    ║     Welcome to Raxol Interactive Tutorials    ║
    ╚════════════════════════════════════════════╝#{IO.ANSI.reset()}

    Available commands:
      #{IO.ANSI.green()}list#{IO.ANSI.reset()}              - Show all available tutorials
      #{IO.ANSI.green()}start <id>#{IO.ANSI.reset()}        - Start a tutorial
      #{IO.ANSI.green()}next#{IO.ANSI.reset()}              - Go to next step
      #{IO.ANSI.green()}prev#{IO.ANSI.reset()}              - Go to previous step
      #{IO.ANSI.green()}show#{IO.ANSI.reset()}              - Show current step
      #{IO.ANSI.green()}run#{IO.ANSI.reset()}               - Run example code
      #{IO.ANSI.green()}submit <code>#{IO.ANSI.reset()}     - Submit exercise solution
      #{IO.ANSI.green()}hint#{IO.ANSI.reset()}              - Get a hint
      #{IO.ANSI.green()}progress#{IO.ANSI.reset()}          - Show progress
      #{IO.ANSI.green()}help#{IO.ANSI.reset()}              - Show this help
      #{IO.ANSI.green()}exit#{IO.ANSI.reset()}              - Exit tutorials

    Type 'list' to see available tutorials.
    """)
  end

  defp format_tutorial_list(tutorials) do
    header = "\n#{IO.ANSI.bright()}Available Tutorials:#{IO.ANSI.reset()}\n"

    items =
      Enum.map(tutorials, fn tutorial ->
        progress_bar = format_progress_bar(tutorial.progress)

        difficulty_color =
          case tutorial.difficulty do
            :beginner -> IO.ANSI.green()
            :intermediate -> IO.ANSI.yellow()
            :advanced -> IO.ANSI.red()
          end

        """

        #{IO.ANSI.bright()}#{tutorial.id}#{IO.ANSI.reset()} - #{tutorial.title}
          #{difficulty_color}[#{tutorial.difficulty}]#{IO.ANSI.reset()} · #{tutorial.estimated_time} minutes
          #{tutorial.description}
          Progress: #{progress_bar}
          Tags: #{Enum.join(tutorial.tags, ", ")}
        """
      end)

    header <> Enum.join(items, "\n")
  end

  defp format_tutorial_start(tutorial) do
    """

    #{IO.ANSI.cyan()}════════════════════════════════════════════════#{IO.ANSI.reset()}
    #{IO.ANSI.bright()}Starting: #{tutorial.title}#{IO.ANSI.reset()}
    #{IO.ANSI.cyan()}════════════════════════════════════════════════#{IO.ANSI.reset()}

    #{tutorial.description}

    Difficulty: #{tutorial.difficulty}
    Estimated time: #{tutorial.estimated_time} minutes
    Steps: #{length(tutorial.steps)}

    Type 'next' to begin with the first step.
    """
  end

  defp format_current_step(_state) do
    case InteractiveTutorial.get_current_position() do
      {tutorial, step} ->
        # Find the step index for display
        step_index = Enum.find_index(tutorial.steps, &(&1.id == step.id)) || 0
        format_step_with_context(step, tutorial, step_index)

      nil ->
        "No active step. Use 'next' to advance."
    end
  end

  defp format_step(step) when is_map(step) do
    """

    #{IO.ANSI.bright()}#{step.title}#{IO.ANSI.reset()}
    #{String.duplicate("─", String.length(step.title))}

    #{step.content}

    #{if step.example_code, do: format_code_block(step.example_code), else: ""}

    #{if step.exercise, do: format_exercise(step.exercise), else: ""}

    #{format_navigation_hints()}
    """
  end

  defp format_step(_), do: "No step data available"

  defp format_step_with_context(step, tutorial, step_index) do
    total_steps = length(tutorial.steps)
    progress = "Step #{step_index + 1} of #{total_steps}"

    """

    #{IO.ANSI.bright()}#{step.title}#{IO.ANSI.reset()} #{IO.ANSI.light_black()}(#{progress})#{IO.ANSI.reset()}
    #{String.duplicate("─", String.length(step.title))}

    #{step.content}

    #{if step.example_code, do: format_code_block(step.example_code), else: ""}

    #{if step.exercise, do: format_exercise(step.exercise), else: ""}

    #{format_navigation_hints()}
    """
  end

  defp format_code_block(code) do
    """
    #{IO.ANSI.cyan()}Example Code:#{IO.ANSI.reset()}
    #{IO.ANSI.light_black()}```elixir#{IO.ANSI.reset()}
    #{code}
    #{IO.ANSI.light_black()}```#{IO.ANSI.reset()}

    Type 'run' to execute this example.
    """
  end

  defp format_exercise(exercise) do
    """
    #{IO.ANSI.yellow()}📝 Exercise:#{IO.ANSI.reset()}
    #{exercise.description || exercise}

    Type 'submit <your_code>' to submit your solution.
    Type 'hint' if you need help.
    """
  end

  defp format_navigation_hints do
    """
    #{IO.ANSI.light_black()}
    Navigation: 'next' → | ← 'prev' | 'show' to redisplay
    #{IO.ANSI.reset()}
    """
  end

  defp format_example_result({:ok, result}) do
    """
    #{IO.ANSI.green()}✓ Example executed successfully:#{IO.ANSI.reset()}
    #{inspect(result, pretty: true)}
    """
  end

  defp format_example_result({:error, error}) do
    """
    #{IO.ANSI.red()}✗ Example failed:#{IO.ANSI.reset()}
    #{error}
    """
  end

  defp format_success(message) do
    """
    #{IO.ANSI.green()}✓ Correct! #{message || "Great job!"}#{IO.ANSI.reset()}

    Type 'next' to continue to the next step.
    """
  end

  defp format_error(reason) do
    """
    #{IO.ANSI.red()}✗ Not quite right:#{IO.ANSI.reset()}
    #{reason}

    Try again or type 'hint' for help.
    """
  end

  defp format_hint(hint) do
    """
    #{IO.ANSI.yellow()}💡 Hint:#{IO.ANSI.reset()}
    #{hint}
    """
  end

  defp format_progress(progress, nil), do: "No tutorial currently active."

  defp format_progress(progress, current_tutorial) do
    completed_steps = Map.get(progress, {current_tutorial.id, :steps}, [])
    total_steps = length(current_tutorial.steps)
    percentage = round(length(completed_steps) / total_steps * 100)

    """
    #{IO.ANSI.bright()}Progress for #{current_tutorial.title}:#{IO.ANSI.reset()}

    Completed: #{length(completed_steps)}/#{total_steps} steps (#{percentage}%)
    #{format_progress_bar(%{completed_steps: completed_steps, total: total_steps})}

    Completed steps:
    #{format_completed_steps(completed_steps)}
    """
  end

  defp format_progress_bar(progress) do
    completed = length(Map.get(progress, :completed_steps, []))
    total = Map.get(progress, :total, 10)
    percentage = if total > 0, do: completed / total, else: 0

    bar_width = 20
    filled = round(percentage * bar_width)
    empty = bar_width - filled

    bar = String.duplicate("█", filled) <> String.duplicate("░", empty)
    "#{IO.ANSI.green()}#{bar}#{IO.ANSI.reset()} #{round(percentage * 100)}%"
  end

  defp format_completed_steps(steps) do
    if Enum.empty?(steps) do
      "  None yet"
    else
      steps
      |> Enum.map(fn step ->
        "  #{IO.ANSI.green()}✓#{IO.ANSI.reset()} Step #{step}"
      end)
      |> Enum.join("\n")
    end
  end

  defp run_example_code(nil), do: {:error, "No example code available"}

  defp run_example_code(code) do
    case ErrorHandling.safe_call(fn ->
           # Create a safe evaluation context
           Code.eval_string(code, [], __ENV__)
         end) do
      {:ok, {result, _binding}} -> {:ok, result}
      {:error, error} -> {:error, Exception.format(:error, error, [])}
    end
  end

  defp update_progress(progress, tutorial, step) do
    key = {tutorial.id, :steps}
    completed_steps = Map.get(progress, key, [])

    case step in completed_steps do
      true -> progress
      false -> Map.put(progress, key, completed_steps ++ [step])
    end
  end
end
