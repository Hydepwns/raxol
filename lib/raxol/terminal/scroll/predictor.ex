defmodule Raxol.Terminal.Scroll.Predictor do
  @moduledoc """
  Handles predictive scrolling operations for the terminal.
  Tracks recent scrolls and provides pattern analysis for smarter prediction.
  """

  @type scroll_event :: %{
          direction: :up | :down,
          lines: non_neg_integer(),
          timestamp: integer()
        }
  @type t :: %__MODULE__{
          window_size: non_neg_integer(),
          history: [scroll_event()]
        }

  defstruct window_size: 10,
            history: []

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
  Adds a scroll event to the history and keeps only the window size worth of history.
  """
  @spec predict(t(), :up | :down, non_neg_integer()) :: t()
  def predict(predictor, direction, lines) do
    event = %{
      direction: direction,
      lines: lines,
      timestamp: System.monotonic_time()
    }

    history = [event | Enum.take(predictor.history, predictor.window_size - 1)]
    %{predictor | history: history}
  end

  @doc """
  Analyzes recent scroll patterns: returns average scroll size and alternation ratio.
  """
  @spec analyze_patterns(t()) :: %{
          avg_lines: float(),
          alternation_ratio: float()
        }
  def analyze_patterns(%__MODULE__{history: history}) do
    Raxol.Terminal.Scroll.PatternAnalyzer.analyze_patterns(history)
  end
end
