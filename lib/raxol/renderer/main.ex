defmodule Raxol.Renderer.Main do
  @moduledoc """
  Default renderer module for the Raxol pipeline.
  Delegates to the main UI rendering process.
  """

  @doc """
  Handles the final painted output from the rendering pipeline.
  Delegates to Raxol.UI.Rendering.Renderer.
  """
  def render(painted_output) do
    Raxol.UI.Rendering.Renderer.render(painted_output)
    :ok
  end
end
