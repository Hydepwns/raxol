defmodule Raxol.UI.Components.Base.ComponentTest.TestComponent do
  @behaviour Raxol.UI.Components.Base.Component

  # Stub implementation for required callback
  def handle_event(_event, state, _context) do
    {state, []}
  end
end
