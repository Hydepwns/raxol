defmodule Raxol.PerformanceCase do
  @moduledoc """
  Test case helper for performance-related tests.

  Provides helper functions for benchmarking and asserting on performance.

  ## Example

      defmodule PerformanceTest do
        use Raxol.PerformanceCase

        @tag :performance
        test "renders in under 1ms" do
          component = create_large_component()

          assert_performance fn ->
            render(component)
          end, max_ms: 1
        end
      end
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Raxol.PerformanceCase
    end
  end

  setup tags do
    if tags[:performance] || tags[:memory] do
      # Ensure clean state for performance tests
      :erlang.garbage_collect()
    end

    {:ok, %{}}
  end

  @doc """
  Assert that a function executes within the specified time.

  ## Options

    - `:max_ms` - Maximum allowed execution time in milliseconds
    - `:max_us` - Maximum allowed execution time in microseconds
    - `:iterations` - Number of iterations to average (default: 10)
    - `:warmup` - Number of warmup iterations (default: 3)

  ## Example

      assert_performance fn ->
        expensive_operation()
      end, max_ms: 1
  """
  def assert_performance(fun, opts) when is_function(fun, 0) do
    iterations = Keyword.get(opts, :iterations, 10)
    warmup = Keyword.get(opts, :warmup, 3)
    max_us = get_max_microseconds(opts)

    # Warmup
    for _ <- 1..warmup, do: fun.()

    # Measure
    times =
      for _ <- 1..iterations do
        {time, _result} = :timer.tc(fun)
        time
      end

    avg_time = Enum.sum(times) / iterations

    if avg_time > max_us do
      fail_assertion(
        "Performance assertion failed: avg #{format_time(avg_time)} > max #{format_time(max_us)}"
      )
    end

    {:ok, %{avg_us: avg_time, min_us: Enum.min(times), max_us: Enum.max(times)}}
  end

  @doc """
  Assert that a function uses no more than the specified memory.

  ## Options

    - `:max_mb` - Maximum allowed memory in megabytes
    - `:max_kb` - Maximum allowed memory in kilobytes
    - `:max_bytes` - Maximum allowed memory in bytes

  ## Example

      assert_memory fn ->
        create_large_data_structure()
      end, max_mb: 10
  """
  def assert_memory(fun, opts) when is_function(fun, 0) do
    max_bytes = get_max_bytes(opts)

    :erlang.garbage_collect()
    {:memory, before_mem} = Process.info(self(), :memory)

    _result = fun.()

    {:memory, after_mem} = Process.info(self(), :memory)
    used = after_mem - before_mem

    if used > max_bytes do
      fail_assertion(
        "Memory assertion failed: used #{format_bytes(used)} > max #{format_bytes(max_bytes)}"
      )
    end

    {:ok, %{used_bytes: used}}
  end

  @doc """
  Benchmark a function and return statistics.

  ## Example

      stats = benchmark fn ->
        operation()
      end, iterations: 100

      IO.puts("Average: \#{stats.avg_us}us")
  """
  def benchmark(fun, opts \\ []) when is_function(fun, 0) do
    iterations = Keyword.get(opts, :iterations, 100)
    warmup = Keyword.get(opts, :warmup, 10)

    # Warmup
    for _ <- 1..warmup, do: fun.()

    # Measure
    times =
      for _ <- 1..iterations do
        {time, _result} = :timer.tc(fun)
        time
      end

    sorted = Enum.sort(times)
    count = length(sorted)

    %{
      iterations: count,
      min_us: Enum.min(sorted),
      max_us: Enum.max(sorted),
      avg_us: Enum.sum(sorted) / count,
      median_us: Enum.at(sorted, div(count, 2)),
      p95_us: Enum.at(sorted, round(count * 0.95)),
      p99_us: Enum.at(sorted, round(count * 0.99))
    }
  end

  # Private helpers

  defp get_max_microseconds(opts) do
    cond do
      Keyword.has_key?(opts, :max_us) -> Keyword.get(opts, :max_us)
      Keyword.has_key?(opts, :max_ms) -> Keyword.get(opts, :max_ms) * 1000
      true -> 1000
    end
  end

  defp get_max_bytes(opts) do
    cond do
      Keyword.has_key?(opts, :max_bytes) ->
        Keyword.get(opts, :max_bytes)

      Keyword.has_key?(opts, :max_kb) ->
        Keyword.get(opts, :max_kb) * 1024

      Keyword.has_key?(opts, :max_mb) ->
        Keyword.get(opts, :max_mb) * 1024 * 1024

      true ->
        1024 * 1024
    end
  end

  defp format_time(us) when us < 1000, do: "#{round(us)}us"
  defp format_time(us) when us < 1_000_000, do: "#{Float.round(us / 1000, 2)}ms"
  defp format_time(us), do: "#{Float.round(us / 1_000_000, 2)}s"

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes}B"

  defp format_bytes(bytes) when bytes < 1_048_576,
    do: "#{Float.round(bytes / 1024, 2)}KB"

  defp format_bytes(bytes), do: "#{Float.round(bytes / 1_048_576, 2)}MB"

  defp fail_assertion(message) do
    raise ExUnit.AssertionError, message: message
  end
end
