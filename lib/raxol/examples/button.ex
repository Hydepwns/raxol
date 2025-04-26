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

  use Raxol.UI.Components.Base.Component
  require Logger
  require Raxol.View.Elements

  @default_theme %{
    normal: %{fg: :blue, bg: :white, style: :bold},
    disabled: %{fg: :gray, bg: :white, style: :dim},
    pressed: %{fg: :blue, bg: :white, style: :reverse}
  }

  @type state :: map()

  @impl true
  def init(_opts) do
    %{count: 0, theme: @default_theme}
  end

  @impl true
  def update(%{type: :mouse, data: %{state: :pressed}} = _event, state) do
    IO.puts("Button clicked!")
    # Simulate an action
    {state, [:notify, "Button Action Performed"]}
  end

  @impl true
  def update(_event, state), do: {state, []}

  @impl true
  def handle_event(%{type: :resize} = _event, %{} = _props, state) do
    Logger.info("Button received resize event, ignoring.")
    {state, []}
  end

  # Fallback for other events if Component behaviour requires it
  def handle_event(_event, %{} = _props, state), do: {state, []}

  def handle_event(:focus, %{} = _props, state) do
    {state, []}
  end

  def handle_event(:blur, %{} = _props, state) do
    {state, []}
  end

  def handle_event(:trigger_error, %{} = _props, _state) do
    raise "Simulated error for testing"
  end

  @impl true
  def render(%{} = _props, state) do
    # Generate the DSL representation using the Raxol.View.Elements macro
    Raxol.View.Elements.button(
      label: state.label,
      id: state.id,
      style: state.style,
      on_click: state.on_click,
      disabled: state.disabled,
      pressed: state.pressed
    )
    # The button macro already returns the correct element map structure
  end

  # Private Helpers
end
