defmodule Raxol.UI.Components.Base.ComponentTest.TestComponent do
  @behaviour Raxol.UI.Components.Base.Component

  # Stub implementation for required callback
  @impl Raxol.UI.Components.Base.Component
  def handle_event(_event, state, _context) do
    {state, []}
  end

  @impl Raxol.UI.Components.Base.Component
  def init(props), do: props

  @impl Raxol.UI.Components.Base.Component
  def update(_msg, state), do: {state, []}

  @impl Raxol.UI.Components.Base.Component
  def render(state, _context), do: state
end
