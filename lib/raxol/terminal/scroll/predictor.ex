defmodule Raxol.Terminal.Scroll.Predictor do
  @moduledoc """
  Handles predictive scrolling operations for the terminal.
  """

  @type t :: %__MODULE__{
          window_size: non_neg_integer(),
          history: [map()]
        }

  defstruct [
    :window_size,
    :history
  ]

  @doc """
  Creates a new predictor instance.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{
      window_size: 10,
      history: []
    }
  end

  @doc """
  Predicts the next scroll operation based on history.
  """
  @spec predict(t(), :up | :down, non_neg_integer()) :: t()
  def predict(predictor, direction, lines) do
    # Add current operation to history
    history = [
      %{direction: direction, lines: lines, timestamp: System.monotonic_time()}
      | predictor.history
    ]

    # Keep only the window size worth of history
    history = Enum.take(history, predictor.window_size)

    %{predictor | history: history}
  end
end
