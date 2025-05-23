defmodule Raxol.Docs.TutorialViewer do
  @moduledoc """
  UI Component for displaying interactive tutorials.

  Uses Raxol.Docs.InteractiveTutorial to manage state and content.
  """
  use Raxol.Core.Runtime.Application
  import Raxol.View.Elements

  # Removed unused aliases for CodeBlock, MarkdownRenderer
  # alias Raxol.UI.Components.{MarkdownRenderer, CodeBlock}

  alias Raxol.Docs.InteractiveTutorial
  alias Raxol.Docs.InteractiveTutorial.Models.{Tutorial, Step}

  # --- State ---

  defmodule ComponentState do
    @moduledoc false
    # :selecting_tutorial | :viewing_step
    defstruct status: :selecting_tutorial,
              available_tutorials: [],
              current_tutorial_id: nil,
              current_step_id: nil,
              # Added for exercise input
              exercise_input: "",
              # Added for validation/hint feedback
              feedback_message: nil

    # We fetch the actual step/tutorial content dynamically from InteractiveTutorial
  end

  # --- Lifecycle Callbacks ---

  @impl true
  def init(_opts) do
    # Ensure the backend tutorial system is initialized
    InteractiveTutorial.init()

    # Fetch available tutorials
    tutorials = InteractiveTutorial.list_tutorials()

    initial_state = %ComponentState{
      status: :selecting_tutorial,
      available_tutorials: tutorials
    }

    {:ok, initial_state}
  end

  # --- Update Logic ---

  @impl true
  def update(message, model) do
    case message do
      {:start_tutorial, tutorial_id} ->
        case InteractiveTutorial.start_tutorial(tutorial_id) do
          {:ok, _first_step} ->
            # Fetch current position to update state accurately
            {_backend_state, {tutorial, step}} =
              InteractiveTutorial.get_current_position()

            new_model = %{
              model
              | status: :viewing_step,
                current_tutorial_id: tutorial.id,
                current_step_id: step.id,
                # Clear input on start
                exercise_input: "",
                # Clear feedback on start
                feedback_message: nil
            }

            {:ok, new_model}

          {:error, reason} ->
            # Show error
            {:ok, %{model | feedback_message: "Error: #{reason}"}}
        end

      :next_step ->
        case InteractiveTutorial.next_step() do
          {:ok, next_step} ->
            new_model = %{
              model
              | current_step_id: next_step.id,
                # Clear input on next step
                exercise_input: "",
                # Clear feedback on next step
                feedback_message: nil
            }

            {:ok, new_model}

          :tutorial_completed ->
            # NOTE: Showing completion message via feedback_message. Enhance with modal/notification if desired.
            IO.puts("Tutorial completed!")

            new_model = %{
              model
              | status: :selecting_tutorial,
                current_tutorial_id: nil,
                current_step_id: nil,
                # Clear input on complete
                exercise_input: "",
                # Show completion message
                feedback_message: "Tutorial Completed!"
            }

            {:ok, new_model}

          {:error, reason} ->
            # Don't clear feedback here, might be useful ("already at last step")
            # Stay on current step
            {:ok, model}
        end

      :prev_step ->
        case InteractiveTutorial.previous_step() do
          {:ok, prev_step} ->
            new_model = %{
              model
              | current_step_id: prev_step.id,
                # Clear input on prev step
                exercise_input: "",
                # Clear feedback on prev step
                feedback_message: nil
            }

            {:ok, new_model}

          {:error, reason} ->
            # Don't clear feedback here, might be useful ("already at first step")
            # Stay on current step
            {:ok, model}
        end

      :back_to_list ->
        # Optional: Call InteractiveTutorial.reset() or similar if it exists.
        # Assuming start_tutorial will handle overwriting state correctly.
        new_model = %{
          model
          | status: :selecting_tutorial,
            current_tutorial_id: nil,
            current_step_id: nil,
            # Clear input on back
            exercise_input: "",
            # Clear feedback on back
            feedback_message: nil
        }

        {:ok, new_model}

      # Handle exercise input changes
      {:update_exercise_input, value} ->
        {:ok, %{model | exercise_input: value}}

      # Handle exercise validation
      :validate_exercise ->
        case InteractiveTutorial.validate_exercise(model.exercise_input) do
          {:ok, msg} ->
            {:ok, %{model | feedback_message: "Validation OK: #{msg}"}}

          {:error, reason} ->
            {:ok, %{model | feedback_message: "Validation Failed: #{reason}"}}
        end

      # Handle hint request
      :get_hint ->
        case InteractiveTutorial.get_hint() do
          {:ok, hint} ->
            {:ok, %{model | feedback_message: "Hint: #{hint}"}}

          {:error, reason} ->
            {:ok, %{model | feedback_message: "Hint Error: #{reason}"}}
        end

      {:ui, _ui_event_details} ->
        # NOTE: Handle UI events if needed in the future.
        :ok

      _ ->
        {:ok, model}
    end
  end

  # --- View Rendering ---

  @impl true
  def view(model = %ComponentState{}) do
    view do
      panel(title: "Interactive Tutorials") do
        case model.status do
          :selecting_tutorial ->
            render_tutorial_selection(model.available_tutorials)

          :viewing_step ->
            # Fetch current step data on each render to ensure freshness
            case InteractiveTutorial.get_current_position() do
              {_backend_state, {tutorial, step}} ->
                render_step_view(tutorial, step, model)

              nil ->
                # Should not happen if status is :viewing_step, but handle defensively
                render_tutorial_selection(model.available_tutorials,
                  error: "Error: No tutorial active."
                )
            end
        end
      end
    end
  end

  # --- View Helpers ---

  defp render_tutorial_selection(tutorials, opts \\ []) do
    error = Keyword.get(opts, :error)

    column(gap: 10) do
      if error do
        text(content: error, style: "color: red;")
      end

      text(content: "Select a tutorial to begin:")
      # NOTE: Add sorting or better display if many tutorials in the future.
      Enum.map(tutorials, fn tutorial = %Tutorial{} ->
        # Assuming Tutorial struct has :id, :title, :description
        panel(title: tutorial.title, style: "margin-bottom: 10px;") do
          column(gap: 5) do
            text(content: tutorial.description)
            # Add more details like difficulty, time?
            button(
              content: "Start Tutorial",
              on_click: {:start_tutorial, tutorial.id}
            )
          end
        end
      end)
    end
  end

  defp render_step_view(
         tutorial = %Tutorial{},
         step = %Step{},
         model = %ComponentState{}
       ) do
    # Basic rendering of step content. Assumes content is markdown-like text.
    # NOTE: Use a proper Markdown renderer component if available in the future.

    # Determine button disabled states
    step_ids = Enum.map(tutorial.steps, & &1.id)
    first_step? = step.id == List.first(step_ids)
    last_step? = step.id == List.last(step_ids)

    column(gap: 15, padding: 10) do
      text(
        content: "Tutorial: #{tutorial.title}",
        style: "font-weight: bold; text-decoration: underline;"
      )

      text(
        content: "Step #{step.id}: #{step.title}",
        style: "font-weight: bold; font-size: 1.2em;"
      )

      # Render Content
      panel(title: "Content") do
        # Use the MarkdownRenderer component
        # Assuming step.content is the markdown string
        # MarkdownRenderer(markdown_text: step.content || "") # Commented out problematic component call
        # TEMP: Render as plain text for now
        text(content: step.content || "", style: "font-family: monospace;")
      end

      # Render Example Code (if any)
      if step.example_code do
        panel(title: "Example Code") do
          # NOTE: Use a syntax-highlighting code block component if available in the future.
          # Use the CodeBlock component
          {Raxol.UI.Components.CodeBlock,
           [content: step.example_code, language: step.language || "elixir"]}
        end
      end

      # Render Exercise (if any)
      if step.exercise do
        panel(title: "Exercise") do
          column(gap: 10) do
            text(content: step.exercise)

            # Assuming a text_input component exists and sends {:update_exercise_input, value} on change
            text_input(
              value: model.exercise_input,
              placeholder: "Enter your answer here...",
              # Assumes simple value forwarding
              on_change: :update_exercise_input
              # Or maybe on_change: fn val -> {:update_exercise_input, val} end
            )

            # Display feedback if present
            if model.feedback_message do
              feedback_style =
                if String.starts_with?(model.feedback_message, [
                     "Validation OK",
                     "Hint"
                   ]) do
                  # Green for success/hints
                  "color: green; margin-top: 5px;"
                else
                  # Red for errors/failures
                  "color: red; margin-top: 5px;"
                end

              text(content: model.feedback_message, style: feedback_style)
            end

            Raxol.View.Elements.row gap: 10, style: "margin-top: 10px;" do
              button(content: "Validate", on_click: :validate_exercise)

              # NOTE: Check if hints are available for the step before enabling in the future.
              button(content: "Get Hint", on_click: :get_hint)
            end
          end
        end
      end

      # Navigation
      Raxol.View.Elements.row gap: 10,
                              justify: :space_between,
                              style: "margin-top: 15px;" do
        # NOTE: Determining if first/last step to disable buttons is now handled.
        button(
          content: "< Previous",
          on_click: :prev_step,
          disabled: first_step?
        )

        button(content: "Back to List", on_click: :back_to_list)
        button(content: "Next >", on_click: :next_step, disabled: last_step?)
      end
    end
  end

  # Add missing Application behaviour callbacks
  @impl true
  # Correct signature handle_event/1
  def handle_event(event) do
    # Handle UI events based on the event structure
    case event do
      {:ui, _ui_event_details} ->
        # TODO: Handle UI events if needed
        :ok

      _ ->
        # Ignore other events for now
        :ok
    end
  end

  @impl true
  # No async messages handled yet
  def handle_message(_message, state), do: {:ok, state}

  @impl true
  # No tick handling needed
  def handle_tick(_state), do: :ok

  @impl true
  # No subscriptions needed
  def subscriptions(_state), do: []

  @impl true
  # Basic terminate
  def terminate(_reason, _state), do: :ok
end
