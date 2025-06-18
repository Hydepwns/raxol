defmodule Raxol.Test.PerformanceHelper do
  @moduledoc '''
  Provides utilities for performance testing and benchmarking in Raxol.

  This module includes:
  - Benchmarking utilities
  - Performance test setup and teardown
  - Common performance test scenarios
  - Metrics collection and reporting
  '''

  use ExUnit.CaseTemplate
  import ExUnit.Callbacks
  require Raxol.Core.Runtime.Log

  @doc '''
  Sets up a test environment optimized for performance testing.

  Returns a context map with initialized services and performance monitoring.
  '''
  def setup_performance_test_env do
    # Start performance monitoring
    {:ok, monitor_pid} = start_supervised(Raxol.Core.Performance.Monitor)

    # Initialize test environment
    {:ok, env} = Raxol.Test.TestHelper.setup_test_env()

    # Add performance monitoring to context
    context = Map.put(env, :performance_monitor, monitor_pid)
    {:ok, context}
  end

  @doc '''
  Runs a benchmark with the given function and options.

  ## Options
    * `:iterations` - Number of iterations to run (default: 1000)
    * `:warmup` - Number of warmup iterations (default: 100)
    * `:timeout` - Maximum time to run in milliseconds (default: 5000)
  '''
  def benchmark(fun, opts \\ []) do
    iterations = Keyword.get(opts, :iterations, 1000)
    warmup = Keyword.get(opts, :warmup, 100)
    _timeout = Keyword.get(opts, :timeout, 5000)

    # Warmup phase
    for _ <- 1..warmup do
      fun.()
    end

    # Actual benchmark
    start_time = System.monotonic_time()

    results =
      for _ <- 1..iterations do
        iteration_start = System.monotonic_time()
        result = fun.()
        iteration_end = System.monotonic_time()
        {result, iteration_end - iteration_start}
      end

    end_time = System.monotonic_time()

    # Calculate statistics
    times = Enum.map(results, fn {_, time} -> time end)
    total_time = end_time - start_time
    avg_time = Enum.sum(times) / length(times)
    min_time = Enum.min(times)
    max_time = Enum.max(times)

    %{
      total_time: total_time,
      average_time: avg_time,
      min_time: min_time,
      max_time: max_time,
      iterations: iterations,
      results: results
    }
  end

  @doc '''
  Asserts that a benchmark meets performance requirements.

  ## Options
    * `:max_average_time` - Maximum allowed average time in microseconds
    * `:max_p95_time` - Maximum allowed 95th percentile time in microseconds
    * `:min_iterations` - Minimum number of iterations required
  '''
  def assert_performance(benchmark_result, opts \\ []) do
    max_avg = Keyword.get(opts, :max_average_time)
    max_p95 = Keyword.get(opts, :max_p95_time)
    min_iterations = Keyword.get(opts, :min_iterations)

    if max_avg && benchmark_result.average_time > max_avg do
      flunk(
        "Average time #{benchmark_result.average_time} exceeds maximum allowed #{max_avg}"
      )
    end

    if max_p95 do
      p95_time = calculate_percentile(benchmark_result.times, 95)

      if p95_time > max_p95 do
        flunk(
          "95th percentile time #{p95_time} exceeds maximum allowed #{max_p95}"
        )
      end
    end

    if min_iterations && length(benchmark_result.times) < min_iterations do
      flunk(
        "Number of iterations #{length(benchmark_result.times)} is less than required #{min_iterations}"
      )
    end

    :ok
  end

  @doc '''
  Calculates the nth percentile from a list of times.
  '''
  def calculate_percentile(times, percentile) do
    sorted_times = Enum.sort(times)
    index = trunc(length(sorted_times) * percentile / 100)
    Enum.at(sorted_times, index)
  end

  @doc '''
  Formats benchmark results for human-readable output.
  '''
  def format_benchmark_results(results) do
    '''
    Benchmark Results:
    ----------------
    Total Time: #{format_time(results.total_time)}
    Average Time: #{format_time(results.average_time)}
    Min Time: #{format_time(results.min_time)}
    Max Time: #{format_time(results.max_time)}
    Iterations: #{results.iterations}
    '''
  end

  defp format_time(time) do
    cond do
      time >= 1_000_000 -> "#{time / 1_000_000} s"
      time >= 1_000 -> "#{time / 1_000} ms"
      true -> "#{time} μs"
    end
  end

  @doc '''
  Measures the execution time of an operation.
  Returns {time_in_ms, result}.
  '''
  def measure_time(operation) do
    start = System.monotonic_time()
    result = operation.()
    end_time = System.monotonic_time()
    time = System.convert_time_unit(end_time - start, :native, :millisecond)
    {time, result}
  end

  @doc '''
  Measures the average execution time of an operation over multiple iterations.
  Returns the average time in milliseconds.
  '''
  def measure_average_time(operation, iterations \\ 1000) do
    {time, _} =
      measure_time(fn ->
        Enum.each(1..iterations, fn _ ->
          operation.()
        end)
      end)

    time / iterations
  end

  @doc '''
  Asserts that an operation's average execution time is below a threshold.
  Use this for direct operation timing, not for benchmark result structs.
  '''
  def assert_operation_performance(
        operation,
        name,
        threshold \\ 0.001,
        iterations \\ 1000
      ) do
    avg_time = measure_average_time(operation, iterations)

    ExUnit.Assertions.assert(
      avg_time < threshold,
      "Average time for #{name} operation (#{avg_time}ms) exceeds #{threshold}ms threshold"
    )
  end

  @doc '''
  Asserts that a set of concurrent operations' average execution time is below a threshold.
  '''
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

    ExUnit.Assertions.assert(
      avg_time < threshold,
      "Average time for #{name} operations (#{avg_time}ms) exceeds #{threshold}ms threshold"
    )
  end

  @doc '''
  Measures memory usage of an operation.
  Returns {memory_in_bytes, result}.
  '''
  def measure_memory(operation) do
    :erlang.garbage_collect()
    before = :erlang.memory(:total)
    result = operation.()
    :erlang.garbage_collect()
    after_memory = :erlang.memory(:total)
    {after_memory - before, result}
  end

  @doc '''
  Asserts that an operation's memory usage is below a threshold.
  '''
  def assert_memory_usage(operation, name, threshold \\ 1_000_000) do
    {memory, _} = measure_memory(operation)

    ExUnit.Assertions.assert(
      memory < threshold,
      "Memory usage for #{name} operation (#{memory} bytes) exceeds #{threshold} bytes threshold"
    )
  end

  @doc '''
  Measures and asserts both time and memory performance.
  '''
  def assert_performance_metrics(
        operation,
        name,
        time_threshold \\ 0.001,
        memory_threshold \\ 1_000_000
      ) do
    {time, _} = measure_time(operation)
    {memory, _} = measure_memory(operation)

    ExUnit.Assertions.assert(
      time < time_threshold,
      "Time for #{name} operation (#{time}ms) exceeds #{time_threshold}ms threshold"
    )

    ExUnit.Assertions.assert(
      memory < memory_threshold,
      "Memory usage for #{name} operation (#{memory} bytes) exceeds #{memory_threshold} bytes threshold"
    )
  end
end
