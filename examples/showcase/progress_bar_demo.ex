defmodule Raxol.Examples.ProgressBarDemo do
  @moduledoc """
  A demo application showcasing various features of the progress bar component.
  """

  use Raxol.Component
  alias Raxol.Components.Progress.ProgressBar

  @impl true
  def init(_props) do
    schedule_next_update()
    
    %{
      basic_progress: 0,
      block_progress: 0,
      custom_progress: 0,
      gradient_progress: 0,
      running: true
    }
  end

  @impl true
  def update(:tick, state) when state.running do
    if state.basic_progress >= 100 do
      %{state | running: false}
    else
      schedule_next_update()
      
      %{state |
        basic_progress: min(state.basic_progress + 5, 100),
        block_progress: min(state.block_progress + 3, 100),
        custom_progress: min(state.custom_progress + 7, 100),
        gradient_progress: min(state.gradient_progress + 4, 100)
      }
    end
  end

  def update(:tick, state), do: state

  def update(:restart, state) do
    schedule_next_update()
    
    %{state |
      basic_progress: 0,
      block_progress: 0,
      custom_progress: 0,
      gradient_progress: 0,
      running: true
    }
  end

  def update(_msg, state), do: state

  defp schedule_next_update do
    schedule(:tick, 100)
  end

  @impl true
  def render(state) do
    box do
      column do
        text(content: "Progress Bar Demo", style: :bold)
        text(content: "")
        
        # Basic style
        component ProgressBar,
          value: state.basic_progress,
          width: 40,
          style: :basic,
          color: :blue,
          label: "Basic"

        text(content: "")

        # Block style
        component ProgressBar,
          value: state.block_progress,
          width: 40,
          style: :block,
          color: :green,
          label: "Block"

        text(content: "")

        # Custom style
        component ProgressBar,
          value: state.custom_progress,
          width: 40,
          style: :custom,
          characters: %{filled: "▣", empty: "□"},
          color: :yellow,
          label: "Custom"

        text(content: "")

        # Gradient style
        component ProgressBar,
          value: state.gradient_progress,
          width: 40,
          style: :block,
          gradient: [:red, :yellow, :green],
          label: "Gradient"

        text(content: "")
        
        if not state.running do
          text(content: "Press 'r' to restart")
        end
      end
    end
  end

  @impl true
  def handle_event(%Event{type: :key, key: "r"}, state) when not state.running do
    {update(:restart, state), []}
  end

  def handle_event(_event, state), do: {state, []}
end 