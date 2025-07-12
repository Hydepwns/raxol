defmodule Raxol.Terminal.Scroll.Optimizer do
  @moduledoc """
  Handles scroll optimization for better performance.
  Dynamically adjusts batch size based on recent scroll patterns and (optionally) performance metrics.
  """

  @history_size 10

  @type scroll_event :: %{
          direction: :up | :down,
          lines: non_neg_integer(),
          timestamp: integer()
        }
  @type t :: %__MODULE__{
          batch_size: non_neg_integer(),
          last_optimization: non_neg_integer(),
          history: [scroll_event()]
        }

  defstruct batch_size: 10,
            last_optimization: 0,
            history: []

  @doc """
  Creates a new optimizer instance.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{
      batch_size: 10,
      last_optimization: System.monotonic_time(),
      history: []
    }
  end

  @doc """
  Optimizes scroll operations for better performance.

  - Increases batch size for large/rapid scrolls.
  - Decreases batch size for small/precise or alternating scrolls.
  - Uses recent scroll history to adapt.
  """
  @spec optimize(t(), :up | :down, non_neg_integer()) :: t()
  def optimize(%__MODULE__{} = optimizer, direction, lines) do
    now = System.monotonic_time()
    event = %{direction: direction, lines: lines, timestamp: now}
    history = [event | Enum.take(optimizer.history, @history_size - 1)]

    new_batch_size = calculate_batch_size(optimizer.batch_size, history)

    %{
      optimizer
      | batch_size: new_batch_size,
        last_optimization: now,
        history: history
    }
  end

  defp calculate_batch_size(current_batch_size, history) do
    avg_lines = calculate_average_lines(history)
    alternation_ratio = calculate_alternation_ratio(history)

    cond do
      alternation_ratio > 0.5 -> max(current_batch_size - 2, 1)
      avg_lines >= 50 -> min(current_batch_size + 10, 100)
      avg_lines >= 20 -> min(current_batch_size + 5, 50)
      avg_lines <= 2 -> max(current_batch_size - 2, 1)
      avg_lines <= 5 -> max(current_batch_size - 1, 1)
      true -> current_batch_size
    end
  end

  defp calculate_average_lines([]), do: 0

  defp calculate_average_lines(history) do
    Enum.sum(Enum.map(history, & &1.lines)) / length(history)
  end

  defp calculate_alternation_ratio(history) when length(history) <= 1, do: 0

  defp calculate_alternation_ratio(history) do
    alternations =
      history
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.count(fn [a, b] -> a.direction != b.direction end)

    alternations / (length(history) - 1)
  end
end
