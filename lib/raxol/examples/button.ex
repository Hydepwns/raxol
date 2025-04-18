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

  use Raxol.Component

  alias Raxol.View

  @default_theme %{
    normal: %{fg: :blue, bg: :white, style: :bold},
    disabled: %{fg: :gray, bg: :white, style: :dim},
    pressed: %{fg: :blue, bg: :white, style: :reverse}
  }

  @impl true
  def init(props) do
    state = %{
      label: Map.get(props, :label, "Button"),
      disabled: Map.get(props, :disabled, false),
      pressed: false,
      on_click: Map.get(props, :on_click, fn -> :ok end),
      theme: Map.get(props, :theme, @default_theme)
    }

    {:ok, state}
  end

  @impl true
  def handle_event({:click, _pos} = _event, state) do
    # Don't process clicks if disabled
    if state.disabled do
      {state, []}
    else
      # Update the state to reflect pressed state
      updated_state = %{state | pressed: true}

      # Get the on_click function from state and call it
      command = state.on_click.()

      # Return updated state and commands
      {updated_state, [command]}
    end
  end

  def handle_event({:resize, _} = _event, state) do
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

  @impl Raxol.Component
  def render(state) do
    # Generate the DSL representation
    dsl_result =
      View.button(
        [
          id: state.id,
          style: state.style,
          on_click: state.on_click,
          disabled: state.disabled,
          pressed: state.pressed
        ],
        state.label
      )

    # Convert to Element struct
    Raxol.View.to_element(dsl_result)
  end

  # Private Helpers
end
