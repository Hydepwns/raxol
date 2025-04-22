defmodule Raxol.Examples.Button do
  @moduledoc """
  A sample button component that demonstrates various testable features.

  This component includes:
  - Click handling
  - Disabled state
  - Visual styling
  - Responsive layout
  - Theme support
  """

  use GenServer
  use Raxol.Component
  alias Raxol.Core.Events.Event

  @behaviour Raxol.App

  @default_theme %{
    normal: %{fg: :blue, bg: :white, style: :bold},
    disabled: %{fg: :gray, bg: :white, style: :dim},
    pressed: %{fg: :blue, bg: :white, style: :reverse}
  }

  @type state :: map()

  @impl true
  def init(_opts) do
    {:ok, %{count: 0, theme: @default_theme}}
  end

  @impl true
  def update(%Event{type: :mouse, data: %{state: :pressed}} = _event, state) do
    {:noreply, %{state | count: state.count + 1}}
  end

  @impl true
  def update(_msg, state), do: {:noreply, state}

  @impl Raxol.Component
  def handle_event(%Event{type: :resize} = _event, state) do
    # TODO: Implement resize handling
    state
  end

  def handle_event(:focus, state) do
    {state, []}
  end

  def handle_event(:blur, state) do
    {state, []}
  end

  def handle_event(:trigger_error, _state) do
    raise "Simulated error for testing"
  end

  @impl true
  def render(state) do
    # Generate the DSL representation
    dsl_result =
      Raxol.View.Components.button(state.label,
        id: state.id,
        style: state.style,
        on_click: state.on_click,
        disabled: state.disabled,
        pressed: state.pressed
      )

    # Convert to Element struct
    Raxol.View.to_element(dsl_result)
  end

  # Private Helpers
end
