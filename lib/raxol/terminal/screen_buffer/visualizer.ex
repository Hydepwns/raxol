defmodule Raxol.Terminal.ScreenBuffer.Visualizer do
  @moduledoc """
  Deprecated: This module is not used in the codebase.

  Originally intended for chart visualization but never integrated.
  """

  defstruct [:charts]

  @type t :: %__MODULE__{
          charts: list(map())
        }

  def init do
    %__MODULE__{
      charts: []
    }
  end

  def create_chart(%__MODULE__{} = state, data, options) do
    chart = %{
      data: data,
      options: options,
      id: System.unique_integer([:positive])
    }

    %{state | charts: [chart | state.charts]}
  end
end
