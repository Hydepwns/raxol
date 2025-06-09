defmodule Raxol.UI.Components.Base.ComponentTest.TestComponent do
  use Raxol.UI.Components.Base.Component

  @impl true
  def init(_props) do
    {:ok, %{count: 0}}
  end

  @impl Raxol.UI.Components.Base.Component
  def update(component, new_props) do
    %{component | props: new_props}
  end

  @impl Raxol.UI.Components.Base.Component
  def handle_event(component, :increment, _context) do
    {:ok,
     %{component | state: %{component.state | count: component.state.count + 1}}}
  end

  @impl Raxol.UI.Components.Base.Component
  def render(component, _context) do
    Raxol.Core.Renderer.View.column do
      [
        Raxol.Core.Renderer.View.text("Count: #{component.state.count}"),
        Raxol.Core.Renderer.View.button("Increment", on_click: :increment)
      ]
    end
  end
end
