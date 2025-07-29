defmodule Raxol.Core.Performance.Profiler do
  @moduledoc """
  Performance profiling and optimization tools for Raxol.

  Provides instrumentation, profiling, and analysis capabilities to identify
  and optimize performance bottlenecks in the application.

  ## Features

  - Function execution timing
  - Memory usage tracking
  - Hot path identification
  - Performance regression detection
  - Automatic optimization suggestions

  ## Usage

      import Raxol.Core.Performance.Profiler
      
      # Profile a function
      profile :my_operation do
        expensive_computation()
      end
      
      # Get performance report
      Profiler.report()
  """

  use GenServer
  require Logger

  @type metric_type :: :execution_time | :memory_usage | :call_count | :gc_runs
  @type profile_data :: %{
          operation: atom(),
          metrics: map(),
          timestamp: DateTime.t(),
          metadata: map()
        }

  defmodule Metrics do
    @moduledoc false
    defstruct [
      :operation,
      :start_time,
      :end_time,
      :duration_us,
      :memory_before,
      :memory_after,
      :memory_delta,
      :gc_before,
      :gc_after,
      :gc_runs,
      :reductions,
      :metadata
    ]
  end

  # Client API

  @doc """
  Starts the profiler GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Profiles a code block and records metrics.

  ## Options

  - `:sample_rate` - Sampling rate (0.0 to 1.0, default: 1.0)
  - `:trace` - Enable detailed tracing (default: false)
  - `:metadata` - Additional metadata to record

  ## Examples

      profile :database_query, metadata: %{query: "SELECT *"} do
        Repo.all(User)
      end
  """
  defmacro profile(operation, opts \\ [], do: block) do
    quote do
      Raxol.Core.Performance.Profiler.profile_execution(
        unquote(operation),
        unquote(opts),
        fn -> unquote(block) end
      )
    end
  end

  @doc """
  Executes and profiles a function.
  """
  def profile_execution(operation, opts, fun) do
    sample_rate = Keyword.get(opts, :sample_rate, 1.0)

    if :rand.uniform() <= sample_rate do
      do_profile(operation, opts, fun)
    else
      # Not sampled, just execute
      fun.()
    end
  end

  @doc """
  Benchmarks a function with multiple iterations.

  ## Examples

      benchmark(:sort_algorithm, iterations: 1000) do
        Enum.sort(large_list)
      end
  """
  defmacro benchmark(operation, opts \\ [], do: block) do
    quote do
      iterations = Keyword.get(unquote(opts), :iterations, 100)
      warmup = Keyword.get(unquote(opts), :warmup, 10)
      
      fun = fn -> unquote(block) end

      # Warmup runs
      for _ <- 1..warmup, do: fun.()

      # Actual benchmark
      results =
        for _ <- 1..iterations do
          {time, _result} = :timer.tc(fun)
          # Ensure minimum time of 1 microsecond to avoid 0
          max(time, 1)
        end

      Raxol.Core.Performance.Profiler.analyze_benchmark_results(unquote(operation), results)
    end
  end

  @doc """
  Benchmarks a function with multiple iterations (function version).
  """
  def benchmark_fun(operation, opts \\ [], fun) when is_function(fun) do
    iterations = Keyword.get(opts, :iterations, 100)
    warmup = Keyword.get(opts, :warmup, 10)

    # Warmup runs
    for _ <- 1..warmup, do: fun.()

    # Actual benchmark
    results =
      for _ <- 1..iterations do
        {time, _result} = :timer.tc(fun)
        time
      end

    analyze_benchmark_results(operation, results)
  end

  @doc """
  Compares performance of two implementations.

  ## Examples

      compare(:string_concat,
        old: fn -> str1 <> str2 end,
        new: fn -> [str1, str2] |> IO.iodata_to_binary() end
      )
  """
  def compare(operation, implementations) do
    old_fun = Keyword.fetch!(implementations, :old)
    new_fun = Keyword.fetch!(implementations, :new)

    old_results = benchmark_fun(:"#{operation}_old", [], old_fun)
    new_results = benchmark_fun(:"#{operation}_new", [], new_fun)

    %{
      operation: operation,
      old: old_results,
      new: new_results,
      improvement: calculate_improvement(old_results, new_results)
    }
  end

  @doc """
  Identifies hot paths in the application.
  """
  def identify_hot_paths(duration \\ 5000) do
    :fprof.start()
    :fprof.trace([:start, {:procs, :all}])

    Process.sleep(duration)

    :fprof.trace(:stop)
    :fprof.profile()
    :fprof.analyse(dest: "", cols: 120)
    :fprof.stop()

    parse_fprof_results()
  end

  @doc """
  Profiles memory usage of a function.
  """
  defmacro profile_memory(operation, do: block) do
    quote do
      :erlang.garbage_collect()
      before_info = Process.info(self(), [:memory, :garbage_collection])

      result = unquote(block)

      after_info = Process.info(self(), [:memory, :garbage_collection])

      memory_delta =
        Keyword.get(after_info, :memory, 0) - Keyword.get(before_info, :memory, 0)

      gc_runs = Raxol.Core.Performance.Profiler.get_gc_runs(after_info) - 
                Raxol.Core.Performance.Profiler.get_gc_runs(before_info)

      Raxol.Core.Performance.Profiler.record_memory_metrics(unquote(operation), memory_delta, gc_runs)

      result
    end
  end

  @doc """
  Profiles memory usage of a function (function version).
  """
  def profile_memory_fun(operation, fun) when is_function(fun) do
    :erlang.garbage_collect()
    before_info = Process.info(self(), [:memory, :garbage_collection])

    result = fun.()

    after_info = Process.info(self(), [:memory, :garbage_collection])

    memory_delta =
      Keyword.get(after_info, :memory, 0) - Keyword.get(before_info, :memory, 0)

    gc_runs = get_gc_runs(after_info) - get_gc_runs(before_info)

    record_memory_metrics(operation, memory_delta, gc_runs)

    result
  end

  @doc """
  Generates a performance report.
  """
  def report(opts \\ []) do
    format = Keyword.get(opts, :format, :text)
    operations = Keyword.get(opts, :operations, :all)
    
    # If operations are specified as a list, return raw data unless format is explicitly set
    format = 
      if is_list(operations) and not Keyword.has_key?(opts, :format) do
        :raw
      else
        format
      end

    GenServer.call(__MODULE__, {:generate_report, format, operations})
  end

  @doc """
  Suggests optimizations based on profiling data.
  """
  def suggest_optimizations do
    GenServer.call(__MODULE__, :suggest_optimizations)
  end

  @doc """
  Clears all profiling data.
  """
  def clear do
    GenServer.call(__MODULE__, :clear)
  end

  # Server callbacks

  @impl true
  def init(_opts) do
    state = %{
      profiles: [],
      hot_paths: %{},
      memory_profiles: %{},
      suggestions: []
    }

    # Schedule periodic analysis
    Process.send_after(self(), :analyze, 60_000)

    {:ok, state}
  end

  @impl true
  def handle_call({:record_profile, profile_data}, _from, state) do
    updated_profiles = [profile_data | state.profiles] |> Enum.take(10_000)
    {:reply, :ok, %{state | profiles: updated_profiles}}
  end

  @impl true
  def handle_call({:generate_report, format, operations}, _from, state) do
    report = build_report(state, operations)
    formatted_report = 
      case format do
        :raw -> report
        _ -> format_report(report, format)
      end
    {:reply, formatted_report, state}
  end

  @impl true
  def handle_call(:suggest_optimizations, _from, state) do
    suggestions = analyze_for_optimizations(state)
    {:reply, suggestions, %{state | suggestions: suggestions}}
  end

  @impl true
  def handle_call(:clear, _from, _state) do
    {:reply, :ok, init_state()}
  end

  @impl true
  def handle_info(:analyze, state) do
    # Periodic analysis of profiling data
    new_suggestions = analyze_for_optimizations(state)

    if new_suggestions != state.suggestions do
      Logger.info("New performance optimization suggestions available")
    end

    # Schedule next analysis
    Process.send_after(self(), :analyze, 60_000)

    {:noreply, %{state | suggestions: new_suggestions}}
  end

  # Private functions

  defp do_profile(operation, opts, fun) do
    metadata = Keyword.get(opts, :metadata, %{})
    trace = Keyword.get(opts, :trace, false)

    # Collect initial metrics
    gc_before = :erlang.statistics(:garbage_collection)
    {:memory, memory_before} = Process.info(self(), :memory)
    {reductions_before, _} = :erlang.statistics(:reductions)

    # Start timing
    start_time = System.monotonic_time(:microsecond)

    # Enable tracing if requested
    if trace, do: start_tracing()

    # Execute the function
    try do
      result = fun.()

      # Collect final metrics
      end_time = System.monotonic_time(:microsecond)
      gc_after = :erlang.statistics(:garbage_collection)
      {:memory, memory_after} = Process.info(self(), :memory)
      {reductions_after, _} = :erlang.statistics(:reductions)

      # Stop tracing
      if trace, do: stop_tracing()

      # Build metrics
      metrics = %Metrics{
        operation: operation,
        start_time: start_time,
        end_time: end_time,
        duration_us: end_time - start_time,
        memory_before: memory_before,
        memory_after: memory_after,
        memory_delta: memory_after - memory_before,
        gc_before: elem(gc_before, 0),
        gc_after: elem(gc_after, 0),
        gc_runs: elem(gc_after, 0) - elem(gc_before, 0),
        reductions: reductions_after - reductions_before,
        metadata: metadata
      }

      # Record the profile
      GenServer.call(__MODULE__, {:record_profile, metrics})

      # Log if slow
      # > 1 second
      if metrics.duration_us > 1_000_000 do
        Logger.warning(
          "[Performance] Slow operation #{operation}: #{metrics.duration_us / 1_000_000}s"
        )
      end

      result
    rescue
      error ->
        if trace, do: stop_tracing()
        reraise error, __STACKTRACE__
    end
  end

  def analyze_benchmark_results(operation, times) do
    sorted = Enum.sort(times)
    count = length(sorted)

    if count == 0 do
      %{
        operation: operation,
        min: 0,
        max: 0,
        mean: 0,
        median: 0,
        p95: 0,
        p99: 0,
        std_dev: 0
      }
    else
      %{
        operation: operation,
        min: Enum.min(sorted),
        max: Enum.max(sorted),
        mean: Enum.sum(sorted) / count,
        median: Enum.at(sorted, div(count, 2)),
        p95: Enum.at(sorted, round(count * 0.95)),
        p99: Enum.at(sorted, round(count * 0.99)),
        std_dev: calculate_std_dev(sorted)
      }
    end
  end

  defp calculate_improvement(old_results, new_results) do
    %{
      time_improvement:
        (old_results.mean - new_results.mean) / old_results.mean * 100,
      p95_improvement:
        (old_results.p95 - new_results.p95) / old_results.p95 * 100,
      consistency_improvement:
        (old_results.std_dev - new_results.std_dev) / old_results.std_dev * 100
    }
  end

  defp calculate_std_dev(times) do
    mean = Enum.sum(times) / length(times)

    variance =
      times
      |> Enum.map(fn x -> :math.pow(x - mean, 2) end)
      |> Enum.sum()
      |> Kernel./(length(times))

    :math.sqrt(variance)
  end

  def get_gc_runs(info) do
    info
    |> Keyword.get(:garbage_collection, [])
    |> Keyword.get(:number_of_gcs, 0)
  end

  def record_memory_metrics(operation, memory_delta, gc_runs) do
    metrics = %Metrics{
      operation: operation,
      memory_delta: memory_delta,
      gc_runs: gc_runs,
      duration_us: 0,
      metadata: %{type: :memory_profile}
    }

    GenServer.call(__MODULE__, {:record_profile, metrics})
  end

  defp parse_fprof_results do
    # Simplified - would parse actual fprof output
    %{
      hot_functions: [],
      call_graph: %{},
      recommendations: []
    }
  end

  defp build_report(state, :all) do
    profiles_by_op = Enum.group_by(state.profiles, & &1.operation)

    Enum.map(profiles_by_op, fn {operation, profiles} ->
      %{
        operation: operation,
        call_count: length(profiles),
        avg_duration: average_duration(profiles),
        max_duration: max_duration(profiles),
        total_duration: total_duration(profiles),
        avg_memory: average_memory(profiles),
        gc_pressure: calculate_gc_pressure(profiles)
      }
    end)
    |> Enum.sort_by(& &1.total_duration, :desc)
  end

  defp build_report(state, operations) when is_list(operations) do
    filtered_profiles = state.profiles
    |> Enum.filter(&(&1.operation in operations))
    
    build_report(%{state | profiles: filtered_profiles}, :all)
  end

  defp format_report(report, :text) do
    header =
      "Operation | Calls | Avg Time | Max Time | Total Time | Avg Memory | GC Pressure\n"

    separator = String.duplicate("-", 80) <> "\n"

    rows =
      Enum.map(report, fn r ->
        "#{r.operation} | #{r.call_count} | #{format_time(r.avg_duration)} | " <>
          "#{format_time(r.max_duration)} | #{format_time(r.total_duration)} | " <>
          "#{format_memory(r.avg_memory)} | #{r.gc_pressure}\n"
      end)

    header <> separator <> Enum.join(rows)
  end

  defp format_report(report, :json) do
    Jason.encode!(report)
  end

  defp analyze_for_optimizations(state) do
    profiles_by_op = Enum.group_by(state.profiles, & &1.operation)

    suggestions = []

    # Check for slow operations
    suggestions =
      suggestions ++
        Enum.flat_map(profiles_by_op, fn {op, profiles} ->
          avg = average_duration(profiles)
          # > 100ms
          if avg > 100_000 do
            [
              "Operation #{op} is slow (avg: #{format_time(avg)}). Consider optimization."
            ]
          else
            []
          end
        end)

    # Check for high memory operations
    suggestions =
      suggestions ++
        Enum.flat_map(profiles_by_op, fn {op, profiles} ->
          avg_mem = average_memory(profiles)
          # > 1MB
          if avg_mem > 1_000_000 do
            [
              "Operation #{op} uses high memory (avg: #{format_memory(avg_mem)}). Consider streaming."
            ]
          else
            []
          end
        end)

    # Check for GC pressure
    suggestions =
      suggestions ++
        Enum.flat_map(profiles_by_op, fn {op, profiles} ->
          gc_pressure = calculate_gc_pressure(profiles)
          # > 0.5 GCs per call
          if gc_pressure > 0.5 do
            [
              "Operation #{op} causes GC pressure. Consider reducing allocations."
            ]
          else
            []
          end
        end)

    suggestions
  end

  defp average_duration(profiles) do
    profiles
    |> Enum.map(& &1.duration_us)
    |> Enum.filter(& &1)
    |> case do
      [] -> 0
      times -> Enum.sum(times) / length(times)
    end
  end

  defp max_duration(profiles) do
    profiles
    |> Enum.map(& &1.duration_us)
    |> Enum.filter(& &1)
    |> Enum.max(fn -> 0 end)
  end

  defp total_duration(profiles) do
    profiles
    |> Enum.map(& &1.duration_us)
    |> Enum.filter(& &1)
    |> Enum.sum()
  end

  defp average_memory(profiles) do
    deltas =
      profiles
      |> Enum.map(& &1.memory_delta)
      |> Enum.filter(& &1)

    if length(deltas) > 0 do
      Enum.sum(deltas) / length(deltas)
    else
      0
    end
  end

  defp calculate_gc_pressure(profiles) do
    total_gcs =
      profiles
      |> Enum.map(& &1.gc_runs)
      |> Enum.filter(& &1)
      |> Enum.sum()

    if length(profiles) > 0 do
      total_gcs / length(profiles)
    else
      0
    end
  end

  defp format_time(microseconds) when microseconds < 1000 do
    "#{microseconds}μs"
  end

  defp format_time(microseconds) when microseconds < 1_000_000 do
    "#{Float.round(microseconds / 1000, 2)}ms"
  end

  defp format_time(microseconds) do
    "#{Float.round(microseconds / 1_000_000, 2)}s"
  end

  defp format_memory(bytes) when bytes < 1024 do
    "#{bytes}B"
  end

  defp format_memory(bytes) when bytes < 1_048_576 do
    "#{Float.round(bytes / 1024, 2)}KB"
  end

  defp format_memory(bytes) do
    "#{Float.round(bytes / 1_048_576, 2)}MB"
  end

  defp start_tracing do
    :dbg.start()
    :dbg.tracer()
    :dbg.p(:all, :call)
  end

  defp stop_tracing do
    :dbg.stop()
  end

  defp init_state do
    %{
      profiles: [],
      hot_paths: %{},
      memory_profiles: %{},
      suggestions: []
    }
  end
end
