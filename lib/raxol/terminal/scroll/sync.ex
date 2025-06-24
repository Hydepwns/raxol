defmodule Raxol.Terminal.Scroll.Sync do
  @moduledoc """
  Handles scroll synchronization across terminal splits.
  Tracks recent sync events for analytics and smarter sync strategies.
  """

  @history_size 10

  @type sync_event :: %{
          direction: :up | :down,
          lines: non_neg_integer(),
          timestamp: integer()
        }
  @type t :: %__MODULE__{
          sync_enabled: boolean(),
          last_sync: non_neg_integer(),
          history: [sync_event()]
        }

  defstruct sync_enabled: true,
            last_sync: 0,
            history: []

  @doc """
  Creates a new sync instance.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{
      sync_enabled: true,
      last_sync: System.monotonic_time(),
      history: []
    }
  end

  @doc """
  Synchronizes scroll operations across splits and records the event.
  """
  @spec sync(t(), :up | :down, non_neg_integer()) :: t()
  def sync(sync, direction, lines) do
    now = System.monotonic_time()
    event = %{direction: direction, lines: lines, timestamp: now}
    history = [event | Enum.take(sync.history, @history_size - 1)]
    %{sync | last_sync: now, history: history}
  end

  @doc """
  Analyzes recent sync patterns: returns average lines per sync and alternation ratio.
  """
  @spec analyze_patterns(t()) :: %{
          avg_lines: float(),
          alternation_ratio: float()
        }
  def analyze_patterns(%__MODULE__{history: []}),
    do: %{avg_lines: 0.0, alternation_ratio: 0.0}

  def analyze_patterns(%__MODULE__{history: history}) do
    avg_lines = Enum.sum(Enum.map(history, & &1.lines)) / length(history)

    alternations =
      history
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.count(fn [a, b] -> a.direction != b.direction end)

    alternation_ratio =
      if length(history) > 1,
        do: alternations / (length(history) - 1),
        else: 0.0

    %{avg_lines: avg_lines, alternation_ratio: alternation_ratio}
  end
end
