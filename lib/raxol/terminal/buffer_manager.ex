defmodule Raxol.Terminal.BufferManager do
  @moduledoc """
  Manages buffer operations and tab stops for the terminal.
  """

  defstruct tab_stops: MapSet.new()

  @type t :: %__MODULE__{
          tab_stops: MapSet.t()
        }

  @doc """
  Creates a new BufferManager struct.
  """
  def new do
    %__MODULE__{}
  end

  @doc """
  Gets the default tab stops.
  """
  def default_tab_stops(%__MODULE__{} = state) do
    state.tab_stops
  end
end
