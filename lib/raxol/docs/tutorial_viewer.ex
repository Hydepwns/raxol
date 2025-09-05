defmodule Raxol.Docs.TutorialViewer do
  @moduledoc """
  Interactive tutorial viewer component.
  """

  use Raxol.Core.Runtime.Application
  require Raxol.View.Elements

  defstruct status: :selecting_tutorial,
            available_tutorials: [],
            active_tutorial: nil,
            current_step: nil,
            step_index: 0,
            user_input: "",
            validation_result: nil

  @type t :: %__MODULE__{
          status: :selecting_tutorial | :viewing_step,
          available_tutorials: list(map()),
          active_tutorial: map() | nil,
          current_step: map() | nil,
          step_index: non_neg_integer(),
          user_input: String.t(),
          validation_result: :ok | {:error, String.t()} | nil
        }

  # --- Lifecycle Callbacks ---

  @impl Raxol.Core.Runtime.Application
  def init(_props) do
    # Initialize with available tutorials
    tutorials = [
      %{
        id: :getting_started,
        title: "Getting Started",
        description: "Learn the basics of Raxol",
        steps: [
          %{
            title: "Welcome",
            content:
              "Welcome to Raxol! This tutorial will guide you through the basics.",
            type: :text
          },
          %{
            title: "First Steps",
            content: "Let's start with some basic concepts...",
            type: :text
          }
        ]
      }
    ]

    %__MODULE__{
      available_tutorials: tutorials
    }
  end

  @impl Raxol.Core.Runtime.Application
  def update({:select_tutorial, tutorial_id}, state) do
    tutorial = Enum.find(state.available_tutorials, &(&1.id == tutorial_id))
    step = List.first(tutorial.steps)

    {%{
       state
       | status: :viewing_step,
         active_tutorial: tutorial,
         current_step: step,
         step_index: 0
     }, []}
  end

  def update({:next_step}, state) do
    next_index = state.step_index + 1
    next_step = Enum.at(state.active_tutorial.steps, next_index)

    handle_next_step(next_step, state, next_index)
  end

  def update({:previous_step}, state) do
    prev_index = state.step_index - 1
    prev_step = Enum.at(state.active_tutorial.steps, prev_index)

    handle_previous_step(prev_index, prev_step, state)
  end

  def update({:update_input, input}, state) do
    {%{state | user_input: input}, []}
  end

  def update({:validate_exercise}, state) do
    # Simple validation for now
    result = validate_exercise_input(state.user_input)

    {%{state | validation_result: result}, []}
  end

  def update({:back_to_selection}, state) do
    {%{
       state
       | status: :selecting_tutorial,
         active_tutorial: nil,
         current_step: nil,
         step_index: 0
     }, []}
  end

  @impl Raxol.Core.Runtime.Application
  def handle_event(_event) do
    {:ok, %__MODULE__{}}
  end

  @impl Raxol.Core.Runtime.Application
  def handle_message(_message, model) do
    {:noreply, model}
  end

  @impl Raxol.Core.Runtime.Application
  def handle_tick(model) do
    {:noreply, model}
  end

  @impl Raxol.Core.Runtime.Application
  def subscriptions(_model) do
    []
  end

  @impl Raxol.Core.Runtime.Application
  def terminate(_reason, _model) do
    :ok
  end

  # --- View Functions ---

  @impl Raxol.Core.Runtime.Application
  def view(model = %__MODULE__{}) do
    case model.status do
      :selecting_tutorial ->
        render_tutorial_selection(model)

      :viewing_step ->
        render_current_step(model)

      _ ->
        render_fallback(model)
    end
  end

  # --- Helper Functions ---

  defp handle_next_step(nil, state, _next_index), do: {state, []}

  defp handle_next_step(next_step, state, next_index) do
    {%{state | current_step: next_step, step_index: next_index}, []}
  end

  defp handle_previous_step(prev_index, _prev_step, state) when prev_index < 0, do: {state, []}

  defp handle_previous_step(_prev_index, nil, state), do: {state, []}

  defp handle_previous_step(prev_index, prev_step, state) do
    {%{state | current_step: prev_step, step_index: prev_index}, []}
  end

  defp validate_exercise_input("correct"), do: :ok

  defp validate_exercise_input(_input), do: {:error, "Try again!"}

  defp render_step_content(nil, _current_step) do
    Raxol.View.Elements.label(content: "No active tutorial or step")
  end

  defp render_step_content(_active_tutorial, nil) do
    Raxol.View.Elements.label(content: "No active tutorial or step")
  end

  defp render_step_content(active_tutorial, current_step) do
    render_tutorial_step(active_tutorial, current_step)
  end

  defp render_tutorial_selection(model) do
    Raxol.View.Elements.panel title: "Interactive Tutorials" do
      Raxol.View.Elements.column gap: 1 do
        [
          Raxol.View.Elements.label(content: "Available Tutorials:"),
          Raxol.View.Elements.column gap: 1 do
            Enum.map(model.available_tutorials, fn tutorial ->
              Raxol.View.Elements.button(
                label: tutorial.title,
                on_click: {:select_tutorial, tutorial.id}
              )
            end)
          end
        ]
      end
    end
  end

  defp render_tutorial_step(tutorial, step) do
    Raxol.View.Elements.column gap: 1 do
      [
        Raxol.View.Elements.label(content: tutorial.title),
        Raxol.View.Elements.label(content: "Step #{step.title}"),
        Raxol.View.Elements.label(content: step.content),
        Raxol.View.Elements.row gap: 1 do
          [
            Raxol.View.Elements.button(
              label: "Previous",
              on_click: :previous_step,
              disabled: step.index == 0
            ),
            Raxol.View.Elements.button(
              label: "Next",
              on_click: :next_step,
              disabled: step.index == length(tutorial.steps) - 1
            )
          ]
        end
      ]
    end
  end

  defp render_current_step(model) do
    render_step_content(model.active_tutorial, model.current_step)
  end

  defp render_fallback(_model) do
    Raxol.View.Elements.label(content: "Unknown status")
  end
end
