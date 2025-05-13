defmodule Raxol.Test.PerformanceHelpers do
  @moduledoc """
  Helpers for performance testing and benchmarking in Raxol.
  Provides utilities for measuring and asserting performance metrics.
  """

  import ExUnit.Assertions

  @doc """
  Measures the execution time of an operation.
  Returns {time_in_ms, result}.
  """
  def measure_time(operation) do
    start = System.monotonic_time()
    result = operation.()
    end_time = System.monotonic_time()
    time = System.convert_time_unit(end_time - start, :native, :millisecond)
    {time, result}
  end

  @doc """
  Measures the average execution time of an operation over multiple iterations.
  Returns the average time in milliseconds.
  """
  def measure_average_time(operation, iterations \\ 1000) do
    {time, _} =
      measure_time(fn ->
        Enum.each(1..iterations, fn _ ->
          operation.()
        end)
      end)

    time / iterations
  end

  @doc """
  Asserts that an operation's average execution time is below a threshold.
  """
  def assert_performance(
        operation,
        name,
        threshold \\ 0.001,
        iterations \\ 1000
      ) do
    avg_time = measure_average_time(operation, iterations)

    assert avg_time < threshold,
           "Average time for #{name} operation (#{avg_time}ms) exceeds #{threshold}ms threshold"
  end

  @doc """
  Asserts that a set of concurrent operations' average execution time is below a threshold.
  """
  def assert_concurrent_performance(
        operations,
        name,
        threshold \\ 0.002,
        iterations \\ 1000
      ) do
    {time, _} =
      measure_time(fn ->
        Enum.each(1..iterations, fn _ ->
          Enum.each(operations, fn operation ->
            operation.()
          end)
        end)
      end)

    avg_time = time / (iterations * length(operations))

    assert avg_time < threshold,
           "Average time for #{name} operations (#{avg_time}ms) exceeds #{threshold}ms threshold"
  end

  @doc """
  Measures memory usage of an operation.
  Returns {memory_in_bytes, result}.
  """
  def measure_memory(operation) do
    :erlang.garbage_collect()
    before = :erlang.memory(:total)
    result = operation.()
    :erlang.garbage_collect()
    after_memory = :erlang.memory(:total)
    {after_memory - before, result}
  end

  @doc """
  Asserts that an operation's memory usage is below a threshold.
  """
  def assert_memory_usage(operation, name, threshold \\ 1_000_000) do
    {memory, _} = measure_memory(operation)

    assert memory < threshold,
           "Memory usage for #{name} operation (#{memory} bytes) exceeds #{threshold} bytes threshold"
  end

  @doc """
  Measures and asserts both time and memory performance.
  """
  def assert_performance_metrics(
        operation,
        name,
        time_threshold \\ 0.001,
        memory_threshold \\ 1_000_000
      ) do
    {time, _} = measure_time(operation)
    {memory, _} = measure_memory(operation)

    assert time < time_threshold,
           "Time for #{name} operation (#{time}ms) exceeds #{time_threshold}ms threshold"

    assert memory < memory_threshold,
           "Memory usage for #{name} operation (#{memory} bytes) exceeds #{memory_threshold} bytes threshold"
  end
end
