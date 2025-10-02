defmodule Raxol.Benchmark do
  @moduledoc """
  Benchmarking utilities for Raxol.
  """

  alias Raxol.Core.Runtime.Log
  alias Raxol.SequenceExecutor
  alias Raxol.Sequence

  @doc """
  Run a benchmark with the given configuration.
  """
  def run_benchmark(config) do
    sequences = read_sequences()
    results = Enum.map(sequences, &benchmark_sequence(&1, config))
    :ok = print_results(results)
    {:ok, results}
  end

  defp read_sequences do
    # Read sequences from a file or generate them
    # For now, return a simple test sequence
    [%Sequence{name: "test", steps: ["step1", "step2"]}]
  end

  defp benchmark_sequence(sequence, config) do
    start_time = System.monotonic_time()
    result = SequenceExecutor.execute_sequence(sequence, config)
    end_time = System.monotonic_time()

    duration =
      System.convert_time_unit(end_time - start_time, :native, :millisecond)

    %{
      sequence: sequence,
      result: result,
      duration: duration
    }
  end

  defp print_results(results) do
    Log.console("\nBenchmark Results:")
    Log.console("=================")

    Enum.each(results, fn %{sequence: sequence, duration: duration} ->
      Log.console("Sequence: #{sequence.name}")
      Log.console("Duration: #{duration}ms")
      Log.console("---")
    end)

    :ok
  end
end
