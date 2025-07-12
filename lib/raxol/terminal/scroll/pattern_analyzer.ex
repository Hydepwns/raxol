defmodule Raxol.Terminal.Scroll.PatternAnalyzer do
  @moduledoc """
  Shared utilities for analyzing scroll patterns.
  """

  @doc """
  Analyzes recent scroll patterns: returns average scroll size and alternation ratio.
  """
  @spec analyze_patterns([map()]) :: %{
          avg_lines: float(),
          alternation_ratio: float()
        }
  def analyze_patterns([]),
    do: %{avg_lines: 0.0, alternation_ratio: 0.0}

  def analyze_patterns(history) do
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
