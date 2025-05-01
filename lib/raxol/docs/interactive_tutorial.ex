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

  # Added aliases for parsing
  alias YamlElixir
  alias Earmark.Ast
  alias Earmark.Helpers

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
    initial_state = State.new()

    # Load tutorials from Markdown files
    state =
      load_tutorials_from_markdown("docs/tutorials")
      |> Enum.reduce(initial_state, fn tutorial, acc ->
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

  # --- Tutorial Loading Logic ---

  defp load_tutorials_from_markdown(dir) do
    tutorials_path = Path.join(dir, "*.md")

    Path.wildcard(tutorials_path)
    |> Enum.map(&parse_tutorial_file/1)
    |> Enum.reject(&is_nil/1) # Filter out files that failed to parse
  end

  defp parse_tutorial_file(file_path) do
    IO.puts("Parsing tutorial: #{file_path}")
    case File.read(file_path) do
      {:ok, content} ->
        try do
          parse_markdown_content(content, file_path)
        rescue
          e ->
            IO.warn("Error parsing tutorial file #{file_path}: #{inspect(e)}. Skipping.")
            nil
        catch
          kind, reason ->
            stacktrace = System.stacktrace()
            IO.warn("Error parsing tutorial file #{file_path}: #{kind}: #{inspect(reason)}\n#{Exception.format_stacktrace(stacktrace)}. Skipping.")
            nil
        end
      {:error, reason} ->
        IO.warn("Could not read tutorial file #{file_path}: #{reason}. Skipping.")
        nil
    end
  end

  # Parses frontmatter and Markdown body
  defp parse_markdown_content(content, file_path \\ "") do
    # Split frontmatter (between ---) and body
    parts = String.split(content, "---", parts: 3)

    {metadata_str, body_md} =
      case parts do
        ["", yaml, md] -> {yaml, String.trim(md)}
        # Handle case with no leading --- or no frontmatter?
        _ ->
           IO.warn("Invalid frontmatter format in #{file_path}. Skipping.")
           throw({:error, :invalid_frontmatter})
      end

    metadata =
      case YamlElixir.read_from_string(metadata_str) do
        {:ok, data} -> Map.new(data)
        {:error, reason} ->
          IO.warn("YAML parsing error in #{file_path}: #{inspect(reason)}. Skipping.")
          throw({:error, :yaml_parse_error})
      end

    # Basic metadata validation
    required_keys = [:id, :title, :description]
    unless Enum.all?(required_keys, &Map.has_key?(metadata, &1)) do
      IO.warn("Missing required metadata (#{inspect required_keys}) in #{file_path}. Skipping.")
      throw({:error, :missing_metadata})
    end

    steps = parse_steps_from_markdown(body_md, file_path)

    %Tutorial{
      id: Map.get(metadata, :id),
      title: Map.get(metadata, :title),
      description: Map.get(metadata, :description),
      tags: Map.get(metadata, :tags, []),
      difficulty: Map.get(metadata, :difficulty, :intermediate) |> String.to_atom(),
      estimated_time: Map.get(metadata, :time),
      prerequisites: Map.get(metadata, :prerequisites, []),
      steps: steps,
      metadata: Map.drop(metadata, [:id, :title, :description, :tags, :difficulty, :time, :prerequisites])
    }
  end

  # Parses steps separated by horizontal rules (---)
  defp parse_steps_from_markdown(markdown_body, file_path \\ "") do
     markdown_body
     |> String.split("--- ") # Split by horizontal rule marker
     |> Enum.map(&String.trim/1)
     |> Enum.reject(&(&1 == ""))
     |> Enum.map_reduce(1, fn step_md, index ->
         case parse_single_step(step_md, index, file_path) do
           nil -> {nil, index} # Skip invalid steps
           step -> {step, index + 1}
         end
       end)
     |> elem(0)
     |> Enum.reject(&is_nil/1)
  end

  # Parses a single step's markdown content
  # This is a simplified parser. A more robust approach might use Earmark's AST directly.
  defp parse_single_step(step_md, _index, file_path \\ "") do
    lines = String.split(step_md, "\n", trim: true)

    # Extract Step ID and Title from H2
    {step_id, step_title} =
      case List.first(lines) do
        h2 when is_binary(h2) and String.starts_with?(h2, "## [") ->
          case Regex.run(~r/^##\s+\[([a-zA-Z0-9_\-]+)\]\s+(.*)$/, h2) do
            [_, id, title] -> {id, String.trim(title)}
            _ ->
              IO.warn("Invalid step title format in #{file_path}: #{h2}")
              throw({:error, :invalid_step_title})
          end
        _ ->
           IO.warn("Missing or invalid step title (H2 with [id]) in #{file_path}")
           throw({:error, :missing_step_title})
      end

    # Simple section parsing based on H3 markers
    sections = partition_by_h3(List.delete_at(lines, 0))

    content_md = Map.get(sections, :content, []) |> Enum.join("\n")
    example_code = Map.get(sections, "Example", []) |> extract_code_block()
    exercise_lines = Map.get(sections, "Exercise", [])
    exercise_desc = Enum.reject(exercise_lines, &String.starts_with?(&1, "> Validation:")) |> Enum.join("\n")
    validation_str = Enum.find_value(exercise_lines, fn line ->
      if String.starts_with?(line, "> Validation:") do
        String.trim(String.replace(line, "> Validation:", ""))
      end
    end)
    validation_fun = if validation_str, do: String.to_atom(validation_str), else: nil

    hints_md = Map.get(sections, "Hints", []) |> Enum.join("\n")
    # Earmark can parse the list later if needed, or we can do basic list extraction
    hints =
      hints_md
      |> String.split("\n", trim: true)
      |> Enum.filter(&String.starts_with?(&1, ["* ", "- "]))
      |> Enum.map(&String.replace_prefix(&1, ["* ", "- "], ""))
      |> Enum.map(&String.trim/1)

    %Step{
      id: step_id,
      title: step_title,
      content: content_md,
      example_code: example_code,
      exercise: if exercise_desc == "", do: nil, else: exercise_desc,
      validation: validation_fun, # Store the atom name
      hints: hints,
      next_steps: [], # Placeholder - could potentially parse from content? Or add explicit marker?
      interactive_elements: [] # Placeholder
    }
  end

  # Helper to partition lines by H3 sections (simplistic)
  defp partition_by_h3(lines) do
    Enum.reduce(lines, %{current_section: :content, content: []}, fn line, acc ->
      case String.trim(line) do
        h3 when String.starts_with?(h3, "### ") ->
          section_name = String.replace_prefix(h3, "### ", "") |> String.trim()
          %{acc | current_section: section_name}
        _ ->
          section_key = acc.current_section
          Map.update(acc, section_key, [line], fn existing -> [line | existing] end)
      end
    end)
    |> Map.delete(:current_section)
    |> Enum.map(fn {k, v} -> {k, Enum.reverse(v)} end) # Reverse lines back to original order
    |> Map.new()
  end

  # Helper to extract code from the first ``` block (simplistic)
  defp extract_code_block(lines) do
    lines
    |> Enum.drop_while(&(!String.starts_with?(&1, "```")))
    |> Enum.drop(1) # Drop the opening ```
    |> Enum.take_while(&(!String.starts_with?(&1, "```")))
    |> Enum.join("\n")
    |> case do
      "" -> nil
      code -> code
    end
  end

  # --- Validation Functions (Placeholders) ---
  # These need to be implemented based on tutorial requirements.
  # They receive the user's submission string.
  # They should return :ok or an error message string.

  def validate_setup_step(submission) do
    cond do
      !String.contains?(submission, "Raxol.Core.UXRefinement.init()") ->
        "Missing `Raxol.Core.UXRefinement.init()` call."
      !String.contains?(submission, "enable_feature(:focus_management)") ->
        "Missing `enable_feature(:focus_management)`."
       !String.contains?(submission, "enable_feature(:keyboard_navigation)") ->
         "Missing `enable_feature(:keyboard_navigation)`."
      true ->
        :ok
    end
  end

  def validate_basic_ui_step(submission) do
    # Basic check for keywords. More robust validation might involve parsing.
    cond do
      !String.contains?(submission, "use Raxol.Core.Runtime.Application") ->
         "Did you `use Raxol.Core.Runtime.Application`?"
      !String.contains?(submission, "import Raxol.View.Elements") ->
         "Did you `import Raxol.View.Elements`?"
       !String.contains?(submission, "panel do") ->
         "Missing `panel` element."
      !String.contains?(submission, ~s(text(content: "Welcome to Raxol!"))) ->
        "Missing `text` element with the correct content."
      true ->
        :ok
    end
  end

  # --- Original Private Helpers ---

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

    # Find step by ID
    step_id = state.current_step
    Enum.find(tutorial.steps, fn step -> step.id == step_id end)
  end

  # Removed the hardcoded built_in_tutorials function
  # defp built_in_tutorials do ... end
end
