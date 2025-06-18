defmodule Raxol.Terminal.ScreenBuffer.Visualizer do
  @moduledoc '''
  Handles screen visualization and chart creation.
  '''

  defstruct [:charts]

  @type t :: %__MODULE__{
          charts: list(map())
        }

  @doc '''
  Initializes a new visualizer state.
  '''
  def init do
    %__MODULE__{
      charts: []
    }
  end

  @doc '''
  Creates a new chart with the given data and options.
  '''
  def create_chart(%__MODULE__{} = state, data, options) do
    chart = %{
      data: data,
      options: options,
      id: System.unique_integer([:positive])
    }

    %{state | charts: [chart | state.charts]}
  end
end
