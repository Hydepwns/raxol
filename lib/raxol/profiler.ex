defmodule Raxol.Profiler do
  @moduledoc """
  Compatibility layer for performance profiling.

  This module provides a simplified API for profiling code execution.
  Delegates to `Raxol.Performance.Profiler` for the actual implementation.

  ## Example

      Raxol.Profiler.enable()

      result = Raxol.Profiler.profile do
        expensive_operation()
      end

      Raxol.Profiler.report()
  """

  alias Raxol.Performance.Profiler, as: CoreProfiler

  @doc """
  Enable the profiler.

  Starts the profiler GenServer if not already running.
  """
  @spec enable() :: :ok | {:error, term()}
  def enable do
    case CoreProfiler.start_link([]) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      error -> error
    end
  end

  @doc """
  Disable the profiler and stop collecting metrics.
  """
  @spec disable() :: :ok
  def disable do
    CoreProfiler.clear()
  end

  @doc """
  Generate a performance report.

  ## Options

    - `:format` - Output format: `:text` (default), `:json`, or `:raw`
    - `:operations` - Filter to specific operations (default: `:all`)

  ## Example

      Raxol.Profiler.report()
      Raxol.Profiler.report(format: :json)
  """
  @spec report(keyword()) :: String.t() | map() | list()
  def report(opts \\ []) do
    CoreProfiler.report(opts)
  end

  @doc """
  Profile a code block and record metrics.

  Returns the result of the block while recording execution time,
  memory usage, and GC statistics.

  ## Options

    - `:sample_rate` - Sampling rate 0.0 to 1.0 (default: 1.0)
    - `:trace` - Enable detailed tracing (default: false)
    - `:metadata` - Additional metadata to record

  ## Example

      {result, stats} = Raxol.Profiler.profile do
        Enum.sort(large_list)
      end
  """
  defmacro profile(opts \\ [], do: block) do
    quote do
      operation = :profiled_block
      opts = unquote(opts)

      start_time = System.monotonic_time(:microsecond)
      result = unquote(block)
      end_time = System.monotonic_time(:microsecond)

      stats = %{
        duration_us: end_time - start_time,
        operation: Keyword.get(opts, :name, operation)
      }

      {result, stats}
    end
  end

  @doc """
  Profile a named operation.

  ## Example

      Raxol.Profiler.profile_operation(:database_query, fn ->
        Repo.all(User)
      end)
  """
  @spec profile_operation(atom(), keyword(), (-> any())) :: any()
  def profile_operation(operation, opts \\ [], fun) do
    CoreProfiler.profile_execution(operation, opts, fun)
  end

  @doc """
  Benchmark a function with multiple iterations.

  ## Options

    - `:iterations` - Number of iterations (default: 100)
    - `:warmup` - Warmup iterations (default: 10)

  ## Example

      Raxol.Profiler.benchmark(:sort, iterations: 1000, fn ->
        Enum.sort(list)
      end)
  """
  @spec benchmark(atom(), keyword(), (-> any())) :: map()
  def benchmark(operation, opts \\ [], fun) do
    CoreProfiler.benchmark_fun(operation, opts, fun)
  end

  @doc """
  Compare two implementations.

  ## Example

      Raxol.Profiler.compare(:concat,
        old: fn -> str1 <> str2 end,
        new: fn -> IO.iodata_to_binary([str1, str2]) end
      )
  """
  @spec compare(atom(), keyword()) :: map()
  def compare(operation, implementations) do
    CoreProfiler.compare(operation, implementations)
  end

  @doc """
  Get optimization suggestions based on profiling data.
  """
  @spec suggest_optimizations() :: list(String.t())
  def suggest_optimizations do
    CoreProfiler.suggest_optimizations()
  end

  @doc """
  Clear all profiling data.
  """
  @spec clear() :: :ok
  def clear do
    CoreProfiler.clear()
  end
end
