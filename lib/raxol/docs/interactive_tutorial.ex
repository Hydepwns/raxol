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

  alias Raxol.Core.UXRefinement
  alias Raxol.AI.ContentGeneration

  @type tutorial_id :: String.t()
  @type step_id :: String.t()

  # Tutorial state
  defmodule State do
    @moduledoc false
    defstruct [
      :tutorials,
      :current_tutorial,
      :current_step,
      :progress,
      :bookmarks,
      :history
    ]

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
  end

  # Step definition
  defmodule Step do
    @moduledoc false
    defstruct [
      :id,
      :title,
      :content,
      :example_code,
      :exercise,
      :validation,
      :hints,
      :next_steps,
      :interactive_elements
    ]
  end

  # Tutorial definition
  defmodule Tutorial do
    @moduledoc false
    defstruct [
      :id,
      :title,
      :description,
      :tags,
      :difficulty,
      :estimated_time,
      :prerequisites,
      :steps,
      :metadata
    ]
  end

  # Process dictionary key for tutorial state
  @state_key :raxol_tutorial_state

  @doc """
  Initializes the tutorial system.
  """
  def init do
    state = State.new()

    # Load built-in tutorials
    state =
      Enum.reduce(built_in_tutorials(), state, fn tutorial, acc ->
        register_tutorial(tutorial, acc)
      end)

    Process.put(@state_key, state)
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
      case Map.get(state.tutorials, tutorial_id) do
        nil ->
          {state, {:error, "Tutorial not found"}}

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

          {updated_state, {:ok, get_current_step(updated_state)}}
      end
    end)
  end

  @doc """
  Goes to the next step in the current tutorial.
  """
  def next_step do
    with_state(fn state ->
      if state.current_tutorial && state.current_step do
        tutorial = Map.get(state.tutorials, state.current_tutorial)

        current_index =
          Enum.find_index(tutorial.steps, fn step ->
            step.id == state.current_step
          end)

        if current_index < length(tutorial.steps) - 1 do
          next_step = Enum.at(tutorial.steps, current_index + 1)

          # Update progress
          progress =
            Map.get(state.progress, state.current_tutorial, %{
              completed: false,
              completed_steps: [],
              last_step: nil
            })

          updated_progress = %{
            progress
            | completed_steps:
                [state.current_step | progress.completed_steps] |> Enum.uniq(),
              last_step: next_step.id
          }

          # Update state
          updated_state = %{
            state
            | current_step: next_step.id,
              progress:
                Map.put(
                  state.progress,
                  state.current_tutorial,
                  updated_progress
                ),
              history: [
                {:step_change, state.current_tutorial, next_step.id}
                | state.history
              ]
          }

          {updated_state, {:ok, get_current_step(updated_state)}}
        else
          # This was the last step, mark tutorial as completed
          progress =
            Map.get(state.progress, state.current_tutorial, %{
              completed: false,
              completed_steps: [],
              last_step: nil
            })

          updated_progress = %{
            progress
            | completed: true,
              completed_steps:
                [state.current_step | progress.completed_steps] |> Enum.uniq()
          }

          updated_state = %{
            state
            | progress:
                Map.put(
                  state.progress,
                  state.current_tutorial,
                  updated_progress
                ),
              history: [
                {:tutorial_complete, state.current_tutorial} | state.history
              ]
          }

          {updated_state, {:ok, :tutorial_completed}}
        end
      else
        {state, {:error, "No tutorial in progress"}}
      end
    end)
  end

  @doc """
  Goes to the previous step in the current tutorial.
  """
  def previous_step do
    with_state(fn state ->
      if state.current_tutorial && state.current_step do
        tutorial = Map.get(state.tutorials, state.current_tutorial)

        current_index =
          Enum.find_index(tutorial.steps, fn step ->
            step.id == state.current_step
          end)

        if current_index > 0 do
          prev_step = Enum.at(tutorial.steps, current_index - 1)

          # Update progress
          progress =
            Map.get(state.progress, state.current_tutorial, %{
              completed: false,
              completed_steps: [],
              last_step: nil
            })

          updated_progress = %{progress | last_step: prev_step.id}

          # Update state
          updated_state = %{
            state
            | current_step: prev_step.id,
              progress:
                Map.put(
                  state.progress,
                  state.current_tutorial,
                  updated_progress
                ),
              history: [
                {:step_change, state.current_tutorial, prev_step.id}
                | state.history
              ]
          }

          {updated_state, {:ok, get_current_step(updated_state)}}
        else
          {state, {:error, "Already at the first step"}}
        end
      else
        {state, {:error, "No tutorial in progress"}}
      end
    end)
  end

  @doc """
  Validates the current exercise.
  """
  def validate_exercise(submission) do
    with_state(fn state ->
      if state.current_tutorial && state.current_step do
        step = get_current_step(state)

        if step.validation do
          # Run the validation function
          result = step.validation.(submission)

          if result == :ok do
            # Mark step as completed
            progress =
              Map.get(state.progress, state.current_tutorial, %{
                completed: false,
                completed_steps: [],
                last_step: nil
              })

            updated_progress = %{
              progress
              | completed_steps:
                  [state.current_step | progress.completed_steps] |> Enum.uniq()
            }

            updated_state = %{
              state
              | progress:
                  Map.put(
                    state.progress,
                    state.current_tutorial,
                    updated_progress
                  ),
                history: [
                  {:exercise_completed, state.current_tutorial,
                   state.current_step}
                  | state.history
                ]
            }

            {updated_state, {:ok, "Exercise completed successfully!"}}
          else
            {state, {:error, result}}
          end
        else
          {state, {:error, "This step doesn't have an exercise to validate"}}
        end
      else
        {state, {:error, "No tutorial in progress"}}
      end
    end)
  end

  @doc """
  Gets a hint for the current exercise.
  """
  def get_hint(index \\ 0) do
    with_state(fn state ->
      if state.current_tutorial && state.current_step do
        step = get_current_step(state)

        if step.hints && length(step.hints) > index do
          hint = Enum.at(step.hints, index)
          {state, {:ok, hint}}
        else
          # Generate a hint if AI content generation is enabled
          if UXRefinement.feature_enabled?(:ai_content_generation) do
            context = %{
              tutorial_id: state.current_tutorial,
              step_id: state.current_step,
              step_title: step.title,
              exercise: step.exercise,
              example_code: step.example_code
            }

            case ContentGeneration.generate(
                   :hint,
                   "Generate a hint for the current exercise",
                   context: context
                 ) do
              {:ok, hint} -> {state, {:ok, hint}}
              _ -> {state, {:error, "No more hints available"}}
            end
          else
            {state, {:error, "No more hints available"}}
          end
        end
      else
        {state, {:error, "No tutorial in progress"}}
      end
    end)
  end

  @doc """
  Bookmarks the current position in a tutorial.
  """
  def bookmark(name \\ nil) do
    with_state(fn state ->
      if state.current_tutorial && state.current_step do
        bookmark_name = name || "Bookmark #{map_size(state.bookmarks) + 1}"

        bookmark = %{
          name: bookmark_name,
          tutorial_id: state.current_tutorial,
          step_id: state.current_step,
          timestamp: DateTime.utc_now()
        }

        updated_state = %{
          state
          | bookmarks: Map.put(state.bookmarks, bookmark_name, bookmark)
        }

        {updated_state, {:ok, bookmark}}
      else
        {state, {:error, "No tutorial in progress"}}
      end
    end)
  end

  @doc """
  Returns to a bookmarked position.
  """
  def goto_bookmark(bookmark_name) do
    with_state(fn state ->
      case Map.get(state.bookmarks, bookmark_name) do
        nil ->
          {state, {:error, "Bookmark not found"}}

        bookmark ->
          # Resume from bookmark
          updated_state = %{
            state
            | current_tutorial: bookmark.tutorial_id,
              current_step: bookmark.step_id,
              history: [{:bookmark_resume, bookmark_name} | state.history]
          }

          {updated_state, {:ok, get_current_step(updated_state)}}
      end
    end)
  end

  @doc """
  Lists all bookmarks.
  """
  def list_bookmarks do
    with_state(fn state ->
      {state, Map.values(state.bookmarks)}
    end)
  end

  @doc """
  Gets the current tutorial and step.
  """
  def get_current_position do
    with_state(fn state ->
      if state.current_tutorial && state.current_step do
        tutorial = Map.get(state.tutorials, state.current_tutorial)
        step = get_current_step(state)

        {state, {tutorial, step}}
      else
        {state, nil}
      end
    end)
  end

  @doc """
  Exports a user's progress for saving.
  """
  def export_progress do
    with_state(fn state ->
      progress_data = %{
        progress: state.progress,
        bookmarks: state.bookmarks,
        current_tutorial: state.current_tutorial,
        current_step: state.current_step
      }

      {state, progress_data}
    end)
  end

  @doc """
  Imports saved progress.
  """
  def import_progress(progress_data) do
    with_state(fn state ->
      updated_state = %{
        state
        | progress: progress_data.progress,
          bookmarks: progress_data.bookmarks,
          current_tutorial: progress_data.current_tutorial,
          current_step: progress_data.current_step,
          history: [{:progress_imported, DateTime.utc_now()} | state.history]
      }

      {updated_state, :ok}
    end)
  end

  # Private helpers

  defp with_state(arg1, arg2 \\ nil) do
    {state, fun} =
      if is_function(arg1) do
        {Process.get(@state_key) || State.new(), arg1}
      else
        {arg1 || Process.get(@state_key) || State.new(), arg2}
      end

    case fun.(state) do
      {new_state, result} ->
        Process.put(@state_key, new_state)
        result

      new_state ->
        Process.put(@state_key, new_state)
        nil
    end
  end

  defp get_current_step(state) do
    tutorial = Map.get(state.tutorials, state.current_tutorial)
    Enum.find(tutorial.steps, fn step -> step.id == state.current_step end)
  end

  defp built_in_tutorials do
    [
      %Tutorial{
        id: "getting_started",
        title: "Getting Started with Raxol",
        description: "Learn the basics of using Raxol for terminal UIs",
        tags: ["beginner", "introduction"],
        difficulty: :beginner,
        # minutes
        estimated_time: 15,
        prerequisites: [],
        steps: [
          %Step{
            id: "welcome",
            title: "Welcome to Raxol",
            content: """
            # Welcome to Raxol!

            Raxol is a comprehensive UX enhancement framework for terminal UI applications in Elixir.

            This tutorial will guide you through the basics of using Raxol to create
            beautiful and accessible terminal UIs.

            ## What you'll learn

            * Basic concepts and architecture
            * Setting up your first Raxol application
            * Using the core UX features
            * Adding keyboard shortcuts and focus management

            Let's get started!
            """,
            example_code: nil,
            exercise: nil,
            validation: nil,
            hints: [],
            next_steps: ["setup"],
            interactive_elements: []
          },
          %Step{
            id: "setup",
            title: "Setting Up Your Project",
            content: """
            # Setting Up Your Project

            First, let's create a new Elixir project and add Raxol as a dependency.

            1. Create a new project:
            ```bash
            mix new my_terminal_app
            cd my_terminal_app
            ```

            2. Add Raxol to your dependencies in `mix.exs`:

            ```elixir
            def deps do
              [
                {:raxol, "~> 0.1.0"}
              ]
            end
            ```

            3. Fetch dependencies:
            ```bash
            mix deps.get
            ```

            Now you're ready to start using Raxol!
            """,
            example_code: """
            # In lib/my_terminal_app.ex:

            defmodule MyTerminalApp do
              use Raxol.Application
              
              def start do
                Raxol.Core.UXRefinement.init()
                Raxol.Core.UXRefinement.enable_feature(:focus_management)
                Raxol.Core.UXRefinement.enable_feature(:keyboard_navigation)
                
                # Start your application
                MyTerminalApp.UI.start()
              end
            end
            """,
            exercise:
              "Initialize the Raxol UX Refinement system and enable the focus_management and keyboard_navigation features.",
            validation: fn code ->
              cond do
                not String.contains?(code, "UXRefinement.init()") ->
                  "Make sure to initialize the UX Refinement system with Raxol.Core.UXRefinement.init()"

                not String.contains?(code, "enable_feature(:focus_management)") ->
                  "You need to enable the focus_management feature"

                not String.contains?(
                  code,
                  "enable_feature(:keyboard_navigation)"
                ) ->
                  "You need to enable the keyboard_navigation feature"

                true ->
                  :ok
              end
            end,
            hints: [
              "Start by calling the init() function on the UXRefinement module",
              "Use enable_feature/1 to enable each required feature",
              "You need to enable both focus_management and keyboard_navigation features"
            ],
            next_steps: ["basic_ui"],
            interactive_elements: []
          },
          %Step{
            id: "basic_ui",
            title: "Creating Your First UI",
            content: """
            # Creating Your First UI

            Now let's create a simple UI with Raxol. We'll make a basic screen with a few interactive elements.

            1. Create a UI module:

            ```elixir
            defmodule MyTerminalApp.UI do
              use Raxol.View
              alias Raxol.Components
              
              def start do
                Raxol.render(fn -> view() end)
              end
              
              def view do
                Components.panel do
                  Components.title("My Terminal App")
                  Components.text("Welcome to my first Raxol application!")
                  Components.button("Press me!", id: "main_button")
                end
              end
            end
            ```

            2. Run your application:

            ```bash
            iex -S mix
            iex> MyTerminalApp.start()
            ```

            You should see your UI appear in the terminal!
            """,
            example_code: nil,
            exercise:
              "Create a panel with a title, some text, and a button as shown in the example",
            validation: nil,
            hints: [],
            next_steps: ["focus_management"],
            interactive_elements: []
          }
          # More steps would be defined here
        ],
        metadata: %{
          version: "1.0.0",
          author: "Raxol Team"
        }
      }
      # More built-in tutorials would be defined here
    ]
  end
end
