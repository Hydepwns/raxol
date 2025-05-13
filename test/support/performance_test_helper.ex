defmodule Raxol.Test.PerformanceTestHelper do
  use ExUnit.Case
  import ExUnit.Assertions

  @moduledoc """
  DEPRECATED: Use Raxol.Test.PerformanceHelper instead.
  This module is deprecated and will be removed in a future release.
  Please update your tests to use Raxol.Test.PerformanceHelper.
  """
  @deprecated "Use Raxol.Test.PerformanceHelper instead."

  @doc """
  Measures the average execution time of an operation over multiple iterations.
  Returns the average time in milliseconds.
  """
  def measure_average_time(operation, iterations \\ 1000) do
    {time, _} =
      Raxol.Test.PerformanceHelper.measure_time(fn ->
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
      Raxol.Test.PerformanceHelper.measure_time(fn ->
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
end
