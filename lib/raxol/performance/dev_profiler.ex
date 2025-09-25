defmodule Raxol.Performance.DevProfiler do
  @moduledoc """
  Development-mode profiler for detailed performance analysis.

  Provides detailed profiling capabilities specifically for development,
  including function call tracing, memory analysis, and hot spot detection.

  ## Features

  - Function call tracing with timing
  - Memory allocation tracking
  - Process hot spot detection
  - Call graph generation
  - Profiling reports with optimization suggestions

  ## Usage

      # Profile a specific function
      DevProfiler.profile(fn ->
        SomeModule.expensive_function()
      end)

      # Profile with options
      DevProfiler.profile([duration: 5000, memory: true], fn ->
        run_workload()
      end)

      # Enable continuous profiling
      DevProfiler.start_continuous(interval: 10_000)
  """

  require Logger

  @type profile_opts :: [
          duration: pos_integer(),
          memory: boolean(),
          processes: boolean(),
          call_graph: boolean(),
          output_format: :text | :html | :json
        ]

  @default_opts [
    # 10 seconds
    duration: 10_000,
    memory: true,
    processes: true,
    call_graph: false,
    output_format: :text
  ]

  @doc """
  Profile a function call with detailed analysis.

  ## Options

  - `:duration` - Maximum profiling duration in milliseconds
  - `:memory` - Include memory profiling
  - `:processes` - Include process analysis
  - `:call_graph` - Generate call graph (expensive)
  - `:output_format` - Output format (:text, :html, :json)

  ## Examples

      # Basic profiling
      result = DevProfiler.profile(fn ->
        perform_complex_operation()
      end)

      # With memory analysis
      DevProfiler.profile([memory: true], fn ->
        process_large_buffer()
      end)
  """
  @spec profile(profile_opts() | (-> any()), (-> any()) | nil) :: any()
  def profile(opts_or_fun, fun \\ nil)

  def profile(fun, nil) when is_function(fun) do
    profile(@default_opts, fun)
  end

  def profile(opts, fun) when is_list(opts) and is_function(fun) do
    if Mix.env() != :dev do
      Logger.warning("DevProfiler should only be used in development mode")
      fun.()
    end

    opts = Keyword.merge(@default_opts, opts)

    Logger.info("🔬 Starting performance profiling...")

    start_time = System.monotonic_time(:microsecond)
    memory_before = if opts[:memory], do: get_memory_info(), else: nil

    # Start profiling tools
    profiling_ref = start_profiling_tools(opts)

    # Execute the function
    result =
      try do
        fun.()
      catch
        kind, error ->
          _ = stop_profiling_tools(profiling_ref)
          :erlang.raise(kind, error, __STACKTRACE__)
      end

    # Stop profiling and collect data
    profile_data = stop_profiling_tools(profiling_ref)

    end_time = System.monotonic_time(:microsecond)
    duration = end_time - start_time
    memory_after = if opts[:memory], do: get_memory_info(), else: nil

    # Generate report
    report =
      generate_report(%{
        duration: duration,
        memory_before: memory_before,
        memory_after: memory_after,
        profile_data: profile_data,
        opts: opts
      })

    output_report(report, opts[:output_format])

    result
  end

  @doc """
  Start continuous profiling for ongoing performance monitoring.

  ## Options

  - `:interval` - Profiling interval in milliseconds (default: 30000)
  - `:duration` - Duration of each profiling session (default: 5000)
  - `:auto_hints` - Enable automatic performance hints (default: true)

  ## Example

      # Start continuous profiling every 30 seconds
      DevProfiler.start_continuous(interval: 30_000, duration: 5_000)
  """
  def start_continuous(opts \\ []) do
    if Mix.env() != :dev do
      Logger.warning("Continuous profiling should only be used in development")
      :ignored
    end

    interval = Keyword.get(opts, :interval, 30_000)
    duration = Keyword.get(opts, :duration, 5_000)
    auto_hints = Keyword.get(opts, :auto_hints, true)

    spawn_link(fn ->
      continuous_profiling_loop(interval, duration, auto_hints)
    end)
  end

  @doc """
  Analyze current system performance and provide hints.
  """
  def analyze_current_performance do
    memory_info = get_memory_info()
    process_info = get_process_info()
    system_info = get_system_info()

    analysis = %{
      memory: analyze_memory(memory_info),
      processes: analyze_processes(process_info),
      system: analyze_system(system_info),
      timestamp: System.system_time(:millisecond)
    }

    _ = generate_performance_hints(analysis)
    analysis
  end

  @doc """
  Profile memory usage over time.
  """
  def profile_memory(duration \\ 10_000) do
    Logger.info("📊 Profiling memory usage for #{duration}ms...")

    samples = []
    start_time = System.monotonic_time(:millisecond)
    end_time = start_time + duration

    collect_memory_samples(samples, end_time)
  end

  # Private Functions

  defp start_profiling_tools(opts) do
    tools = %{}

    # Start :fprof if available
    tools =
      if opts[:call_graph] do
        _ = :fprof.start()
        _ = :fprof.trace(:start)
        Map.put(tools, :fprof, true)
      else
        tools
      end

    # Start process monitoring
    tools =
      if opts[:processes] do
        Map.put(tools, :process_monitor, spawn_process_monitor())
      else
        tools
      end

    tools
  end

  defp stop_profiling_tools(tools) do
    profile_data = %{}

    # Stop :fprof
    profile_data =
      if Map.get(tools, :fprof) do
        _ = :fprof.trace(:stop)
        _ = :fprof.profile()
        fprof_data = capture_fprof_analysis()
        _ = :fprof.stop()
        Map.put(profile_data, :fprof, fprof_data)
      else
        profile_data
      end

    # Stop process monitor
    profile_data =
      if monitor_pid = Map.get(tools, :process_monitor) do
        send(monitor_pid, :stop)

        receive do
          {:process_data, data} -> Map.put(profile_data, :processes, data)
        after
          1000 -> profile_data
        end
      else
        profile_data
      end

    profile_data
  end

  defp capture_fprof_analysis do
    temp_file =
      System.tmp_dir!() <> "/raxol_fprof_#{:os.system_time()}.analysis"

    try do
      _ = :fprof.analyse(dest: temp_file)
      File.read!(temp_file)
    catch
      _, _ -> "fprof analysis failed"
    after
      _ = File.rm(temp_file)
    end
  end

  defp spawn_process_monitor do
    parent = self()

    spawn(fn ->
      process_samples = collect_process_samples([])
      send(parent, {:process_data, process_samples})
    end)
  end

  defp collect_process_samples(samples) do
    receive do
      :stop -> samples
    after
      100 ->
        sample = %{
          timestamp: System.monotonic_time(:millisecond),
          process_count: length(Process.list()),
          memory_usage: get_memory_info(),
          top_processes: get_top_processes(5)
        }

        collect_process_samples([sample | samples])
    end
  end

  defp get_memory_info do
    %{
      total: :erlang.memory(:total),
      atom: :erlang.memory(:atom),
      binary: :erlang.memory(:binary),
      code: :erlang.memory(:code),
      ets: :erlang.memory(:ets),
      processes: :erlang.memory(:processes),
      system: :erlang.memory(:system)
    }
  end

  defp get_process_info do
    processes = Process.list()

    process_details =
      processes
      |> Enum.map(fn pid ->
        info =
          Process.info(pid, [
            :memory,
            :message_queue_len,
            :current_function,
            :initial_call
          ])

        if info do
          %{
            pid: pid,
            memory: info[:memory] || 0,
            message_queue_len: info[:message_queue_len] || 0,
            current_function: info[:current_function],
            initial_call: info[:initial_call]
          }
        else
          nil
        end
      end)
      |> Enum.filter(&(&1 != nil))

    %{
      count: length(processes),
      details: process_details,
      top_by_memory:
        Enum.sort_by(process_details, & &1.memory, :desc) |> Enum.take(10)
    }
  end

  defp get_system_info do
    %{
      schedulers: :erlang.system_info(:schedulers),
      scheduler_utilization:
        try do
          :scheduler.utilization(1)
        catch
          _, _ -> :not_available
        end,
      port_count: length(Port.list()),
      atom_count: :erlang.system_info(:atom_count),
      atom_limit: :erlang.system_info(:atom_limit)
    }
  end

  defp get_top_processes(count) do
    Process.list()
    |> Enum.map(fn pid ->
      case Process.info(pid, [:memory, :current_function]) do
        nil ->
          nil

        info ->
          %{
            pid: pid,
            memory: info[:memory] || 0,
            current_function: info[:current_function]
          }
      end
    end)
    |> Enum.filter(&(&1 != nil))
    |> Enum.sort_by(& &1.memory, :desc)
    |> Enum.take(count)
  end

  defp analyze_memory(memory_info) do
    total_mb = memory_info.total / (1024 * 1024)

    issues = []

    # Check for high memory usage
    issues =
      if total_mb > 100 do
        ["High total memory usage: #{Float.round(total_mb, 1)}MB" | issues]
      else
        issues
      end

    # Check binary memory
    binary_percent = memory_info.binary / memory_info.total * 100

    issues =
      if binary_percent > 30 do
        [
          "High binary memory usage: #{Float.round(binary_percent, 1)}%"
          | issues
        ]
      else
        issues
      end

    %{
      total_mb: Float.round(total_mb, 2),
      issues: issues,
      breakdown: memory_info
    }
  end

  defp analyze_processes(process_info) do
    issues = []

    # Check process count
    issues =
      if process_info.count > 1000 do
        ["High process count: #{process_info.count}" | issues]
      else
        issues
      end

    # Check for memory-heavy processes
    heavy_processes =
      Enum.filter(process_info.top_by_memory, &(&1.memory > 10 * 1024 * 1024))

    issues =
      if length(heavy_processes) > 0 do
        ["#{length(heavy_processes)} processes using >10MB memory" | issues]
      else
        issues
      end

    %{
      count: process_info.count,
      issues: issues,
      top_by_memory: Enum.take(process_info.top_by_memory, 5)
    }
  end

  defp analyze_system(system_info) do
    issues = []

    # Check atom usage
    atom_usage_percent = system_info.atom_count / system_info.atom_limit * 100

    issues =
      if atom_usage_percent > 80 do
        ["High atom usage: #{Float.round(atom_usage_percent, 1)}%" | issues]
      else
        issues
      end

    %{
      issues: issues,
      atom_usage_percent: Float.round(atom_usage_percent, 2),
      scheduler_count: system_info.schedulers
    }
  end

  defp generate_performance_hints(analysis) do
    hints = []

    # Memory hints
    hints = (hints ++ analysis.memory.issues) |> Enum.map(&"Memory: #{&1}")

    # Process hints
    hints = (hints ++ analysis.processes.issues) |> Enum.map(&"Process: #{&1}")

    # System hints
    hints = (hints ++ analysis.system.issues) |> Enum.map(&"System: #{&1}")

    if length(hints) > 0 do
      Logger.warning("🔍 Performance Analysis Hints:")

      Enum.each(hints, fn hint ->
        Logger.warning("  • #{hint}")
      end)
    else
      Logger.info("✅ No performance issues detected")
    end

    hints
  end

  defp generate_report(data) do
    duration_ms = data.duration / 1000

    report = """

    📊 Performance Profile Report
    ═══════════════════════════════════════

    Execution Time: #{Float.round(duration_ms, 2)}ms
    """

    # Add memory analysis
    report =
      if data.memory_before && data.memory_after do
        memory_diff = data.memory_after.total - data.memory_before.total
        memory_diff_mb = memory_diff / (1024 * 1024)

        report <>
          """

          Memory Usage:
          - Before: #{Float.round(data.memory_before.total / (1024 * 1024), 2)}MB
          - After:  #{Float.round(data.memory_after.total / (1024 * 1024), 2)}MB
          - Change: #{if memory_diff >= 0, do: "+", else: ""}#{Float.round(memory_diff_mb, 2)}MB
          """
      else
        report
      end

    # Add optimization suggestions
    suggestions = generate_optimization_suggestions(data)

    if length(suggestions) > 0 do
      report <>
        """

        💡 Optimization Suggestions:
        #{Enum.map_join(suggestions, "\n", &"  • #{&1}")}
        """
    else
      report <> "\n\n✅ No obvious optimizations detected"
    end
  end

  defp generate_optimization_suggestions(data) do
    suggestions = []
    duration_ms = data.duration / 1000

    # Suggest optimizations based on execution time
    suggestions =
      if duration_ms > 1000 do
        [
          "Consider async execution or breaking into smaller operations (#{Float.round(duration_ms, 1)}ms)"
          | suggestions
        ]
      else
        suggestions
      end

    # Memory-based suggestions
    suggestions =
      if data.memory_before && data.memory_after do
        memory_growth = data.memory_after.total - data.memory_before.total

        # 50MB growth
        if memory_growth > 50 * 1024 * 1024 do
          [
            "High memory allocation detected - consider memory pooling or streaming"
            | suggestions
          ]
        else
          suggestions
        end
      else
        suggestions
      end

    suggestions
  end

  defp output_report(report, format) do
    case format do
      :text ->
        Logger.info(report)

      :html ->
        html_report = generate_html_report(report)
        filename = "/tmp/raxol_profile_#{:os.system_time()}.html"
        _ = File.write!(filename, html_report)
        Logger.info("📄 HTML report written to: #{filename}")

      :json ->
        json_report = Jason.encode!(parse_report_to_map(report))
        Logger.info("📋 JSON Report: #{json_report}")
    end
  end

  defp generate_html_report(text_report) do
    """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Raxol Performance Report</title>
        <style>
            body { font-family: monospace; background: #1e1e1e; color: #d4d4d4; padding: 20px; }
            .report { background: #2d2d30; padding: 20px; border-radius: 8px; }
            .metric { color: #4ec9b0; }
            .suggestion { color: #ffd700; }
        </style>
    </head>
    <body>
        <div class="report">
            <pre>#{text_report}</pre>
        </div>
    </body>
    </html>
    """
  end

  defp parse_report_to_map(report) do
    %{
      type: "performance_report",
      content: report,
      timestamp: System.system_time(:millisecond)
    }
  end

  defp continuous_profiling_loop(interval, duration, auto_hints) do
    _ =
      if auto_hints do
        analyze_current_performance()
      end

    Process.sleep(interval)
    continuous_profiling_loop(interval, duration, auto_hints)
  end

  defp collect_memory_samples(samples, end_time) do
    current_time = System.monotonic_time(:millisecond)

    if current_time < end_time do
      sample = %{
        timestamp: current_time,
        memory: get_memory_info()
      }

      # Sample every 100ms
      Process.sleep(100)
      collect_memory_samples([sample | samples], end_time)
    else
      Logger.info(
        "📈 Memory profiling complete. #{length(samples)} samples collected."
      )

      analyze_memory_samples(samples)
    end
  end

  defp analyze_memory_samples(samples) do
    if length(samples) > 1 do
      first = List.last(samples)
      last = List.first(samples)

      growth = last.memory.total - first.memory.total
      growth_mb = growth / (1024 * 1024)
      duration = last.timestamp - first.timestamp

      Logger.info(
        "Memory growth: #{Float.round(growth_mb, 2)}MB over #{duration}ms"
      )

      if growth_mb > 10 do
        Logger.warning("⚠️  Significant memory growth detected during profiling")
      end
    end

    samples
  end
end
