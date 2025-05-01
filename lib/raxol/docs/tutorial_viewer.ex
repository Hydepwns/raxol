defmodule Raxol.Docs.TutorialViewer do
  @moduledoc """
  UI Component for displaying interactive tutorials.

  Uses Raxol.Docs.InteractiveTutorial to manage state and content.
  """
  use Raxol.Core.Runtime.Application
  import Raxol.View.Elements

  # Removed unused aliases for CodeBlock, MarkdownRenderer
  # alias Raxol.Components.{MarkdownRenderer, CodeBlock}

  alias Raxol.Docs.InteractiveTutorial
  alias Raxol.Docs.InteractiveTutorial.{Tutorial, Step} # Removed unused State alias

  # --- State ---

  defmodule ComponentState do
    @moduledoc false
    defstruct status: :selecting_tutorial, # :selecting_tutorial | :viewing_step
              available_tutorials: [],
              current_tutorial_id: nil,
              current_step_id: nil,
              exercise_input: "", # Added for exercise input
              feedback_message: nil # Added for validation/hint feedback
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
            {_backend_state, {tutorial, step}} = InteractiveTutorial.get_current_position()
            new_model = %{model |
              status: :viewing_step,
              current_tutorial_id: tutorial.id,
              current_step_id: step.id,
              exercise_input: "", # Clear input on start
              feedback_message: nil # Clear feedback on start
            }
            {:ok, new_model}
          {:error, reason} ->
             IO.inspect(reason, label: "Error starting tutorial")
             {:ok, %{model | feedback_message: "Error: #{reason}"}} # Show error
        end

      :next_step ->
        case InteractiveTutorial.next_step() do
          {:ok, next_step} ->
            new_model = %{model |
              current_step_id: next_step.id,
              exercise_input: "", # Clear input on next step
              feedback_message: nil # Clear feedback on next step
            }
            {:ok, new_model}
          :tutorial_completed ->
            # TODO: Show completion message? For now, go back to list.
             IO.puts("Tutorial completed!")
             new_model = %{model |
               status: :selecting_tutorial,
               current_tutorial_id: nil,
               current_step_id: nil,
               exercise_input: "", # Clear input on complete
               feedback_message: "Tutorial Completed!" # Show completion message
             }
             {:ok, new_model}
          {:error, reason} ->
            IO.inspect(reason, label: "Error going to next step")
             # Don't clear feedback here, might be useful ("already at last step")
            {:ok, model} # Stay on current step
        end

      :prev_step ->
        case InteractiveTutorial.previous_step() do
          {:ok, prev_step} ->
            new_model = %{model |
              current_step_id: prev_step.id,
              exercise_input: "", # Clear input on prev step
              feedback_message: nil # Clear feedback on prev step
            }
            {:ok, new_model}
          {:error, reason} ->
            IO.inspect(reason, label: "Error going to previous step")
            # Don't clear feedback here, might be useful ("already at first step")
            {:ok, model} # Stay on current step
        end

      :back_to_list ->
        # Optional: Call InteractiveTutorial.reset() or similar if it exists.
        # Assuming start_tutorial will handle overwriting state correctly.
        new_model = %{model |
          status: :selecting_tutorial,
          current_tutorial_id: nil,
          current_step_id: nil,
          exercise_input: "", # Clear input on back
          feedback_message: nil # Clear feedback on back
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

      _ ->
        IO.inspect(message, label: "Unhandled TutorialViewer message")
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
                 render_tutorial_selection(model.available_tutorials, error: "Error: No tutorial active.")
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
      # TODO: Add sorting or better display if many tutorials
      Enum.map(tutorials, fn tutorial = %Tutorial{} ->
        # Assuming Tutorial struct has :id, :title, :description
        panel(title: tutorial.title, style: "margin-bottom: 10px;") do
          column(gap: 5) do
            text(content: tutorial.description)
            # Add more details like difficulty, time?
             button(content: "Start Tutorial", on_click: {:start_tutorial, tutorial.id})
          end
        end
      end)
    end
  end

  defp render_step_view(tutorial = %Tutorial{}, step = %Step{}, model = %ComponentState{}) do
    # Basic rendering of step content. Assumes content is markdown-like text.
    # TODO: Use a proper Markdown renderer component if available.

    # Determine button disabled states
    step_ids = Enum.map(tutorial.steps, & &1.id)
    first_step? = step.id == List.first(step_ids)
    last_step? = step.id == List.last(step_ids)

    column(gap: 15, padding: 10) do
       text(content: "Tutorial: #{tutorial.title}", style: "font-weight: bold; text-decoration: underline;")
       text(content: "Step #{step.id}: #{step.title}", style: "font-weight: bold; font-size: 1.2em;")

       # Render Content
       panel(title: "Content") do
         # Use the MarkdownRenderer component
         # Assuming step.content is the markdown string
         # MarkdownRenderer(markdown_text: step.content || "") # Commented out problematic component call
         text(content: step.content || "", style: "font-family: monospace;") # TEMP: Render as plain text for now
       end

       # Render Example Code (if any)
       if step.example_code do
         panel(title: "Example Code") do
           # TODO: Use a syntax-highlighting code block component if available
           # Use the CodeBlock component
           # CodeBlock(content: step.example_code, language: step.language || "elixir") # Commented out problematic component call

           # Fallback if code_block doesn't exist:
           text(content: step.example_code, style: "font-family: monospace;") # Uncommented fallback
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
                on_change: :update_exercise_input # Assumes simple value forwarding
                # Or maybe on_change: fn val -> {:update_exercise_input, val} end
              )

              # Display feedback if present
              if model.feedback_message do
                feedback_style = if String.starts_with?(model.feedback_message, ["Validation OK", "Hint"]) do
                  "color: green; margin-top: 5px;" # Green for success/hints
                else
                  "color: red; margin-top: 5px;" # Red for errors/failures
                end
                text(content: model.feedback_message, style: feedback_style)
              end

              row(gap: 10, style: "margin-top: 10px;") do
                button(content: "Validate", on_click: :validate_exercise)
                # TODO: Check if hints are available for the step before enabling?
                button(content: "Get Hint", on_click: :get_hint)
              end
            end
          end
       end

       # Navigation
       row(gap: 10, justify: :space_between, style: "margin-top: 15px;") do
         # TODO: Determine if first/last step to disable buttons -> DONE
         # first_step? = false # Replace with actual check -> REMOVED
         # last_step? = false # Replace with actual check -> REMOVED

         button(content: "< Previous", on_click: :prev_step, disabled: first_step?)
         button(content: "Back to List", on_click: :back_to_list)
         button(content: "Next >", on_click: :next_step, disabled: last_step?)
       end
    end
  end

  # Add missing Application behaviour callbacks
  @impl true
  def handle_event(event) do # Correct signature handle_event/1
    # Handle UI events based on the event structure
    # IO.inspect(event, label: "TutorialViewer Event") # Optional: Debugging
    case event do
      {:ui, _ui_event_details} ->
        :ok # TODO: Handle UI events if needed
      _ ->
        :ok # Ignore other events for now
    end
  end

  @impl true
  def handle_message(_message, state), do: {:ok, state} # No async messages handled yet

  @impl true
  def handle_tick(_state), do: :ok # No tick handling needed

  @impl true
  def subscriptions(_state), do: [] # No subscriptions needed

  @impl true
  def terminate(_reason, _state), do: :ok # Basic terminate

end
