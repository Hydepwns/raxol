defmodule Raxol.UI.Components.Input.MultiLineInput.RenderHelper do
  @moduledoc """
  UI adapter for MultiLineInput's RenderHelper. Delegates to the implementation in
  Raxol.Components.Input.MultiLineInput.RenderHelper.
  """

  alias Raxol.Components.Input.MultiLineInput.RenderHelper, as: ComponentRenderHelper

  @doc """
  Renders the multi-line input component with proper styling based on the state.
  Returns a grid of cell data for the visible portion of text.

  Delegates to the implementation in Raxol.Components.Input.MultiLineInput.RenderHelper.

  ## Parameters
  - state: The MultiLineInput state
  - context: The render context
  - theme: The theme containing style information
  """
  def render(state, context, theme) do
    ComponentRenderHelper.render(state, context, theme)
  end
end
