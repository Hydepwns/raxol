defmodule Raxol.Terminal.Input do
  @moduledoc '''
  Handles input processing for the terminal.
  '''

  @doc '''
  Creates a new input handler.
  '''
  def new do
    %{
      buffer: [],
      state: :normal
    }
  end
end
