defmodule Raxol.Core.Renderer.Views.PerformanceTest.TestHostComponent do
  @moduledoc """
  Test component for performance testing the rendering pipeline.
  """
  # @behaviour Raxol.UI.Components.Base.Component # If a specific behaviour is defined and required

  # Make sure View macros are available
  alias Raxol.Core.Renderer.View

  def init(props) do
    # The state of this component is simply the view map it's supposed to render.
    # Default to an empty box if no view provided
    Map.get(props, :initial_view, View.box(%{}))
  end

  def mount(current_view_state) do
    # No commands on mount
    {current_view_state, []}
  end

  def update({:set_view, new_view_to_render}, _current_view_state) do
    # This update message is used by the `update_test_host_view_and_measure_render` helper
    # to change the view map that this host component will render.
    {new_view_to_render, []}
  end

  def render(view_to_render) do
    # Simply return the view map that is its current state.
    view_to_render
  end
end
