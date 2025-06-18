defmodule Raxol.Terminal.Plugins.Manager.Core do
  @moduledoc '''
  Core functionality for managing terminal plugins.
  '''

  @doc '''
  Creates a new plugin manager instance.
  '''
  def new do
    %{
      plugins: %{},
      config: %{},
      hooks: %{}
    }
  end
end
