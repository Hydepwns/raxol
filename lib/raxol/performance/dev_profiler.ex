defmodule Raxol.Performance.DevProfiler do
  @mix_env Mix.env()
  alias Raxol.Core.Runtime.Log

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

  if @mix_env == :dev do
    def profile(opts, fun) when is_list(opts) and is_function(fun) do
      do_profile(Keyword.merge(@default_opts, opts), fun)
    end
  else
    def profile(opts, fun) when is_list(opts) and is_function(fun) do
      Log.warning("DevProfiler: development mode only")
      fun.()
    end
  end

  @doc """
  Start continuous profiling for ongoing performance monitoring.

  ## Options

  - `:interval` - Profiling interval in milliseconds (default: 30_000)
  - `:duration` - Duration of each profiling session (default: 5000)
  - `:auto_hints` - Enable automatic performance hints (default: true)

  ## Example

      # Start continuous profiling every 30 seconds
      DevProfiler.start_continuous(interval: 30_000, duration: 5_000)
  """
  if @mix_env == :dev do
    def start_continuous(opts \\ []) do
      interval = Keyword.get(opts, :interval, 30_000)
      duration = Keyword.get(opts, :duration, 5_000)
      auto_hints = Keyword.get(opts, :auto_hints, true)

      spawn_link(fn ->
        continuous_profiling_loop(interval, duration, auto_hints)
      end)
    end
  else
    def start_continuous(_opts \\ []) do
      Log.warning("Continuous profiling: development only")
      :ignored
    end
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
    Log.info("Memory profiling: #{duration}ms")

    samples = []
    start_time = System.monotonic_time(:millisecond)
    end_time = start_time + duration

    collect_memory_samples(samples, end_time)
  end

  # Dev-only private functions -- only reachable from profile/2 and
  # start_continuous/1 which short-circuit in non-dev environments.
  if @mix_env == :dev do
    defp do_profile(opts, fun) do
      Log.info("Starting profiling")

      start_time = System.monotonic_time(:microsecond)
      memory_before = if opts[:memory], do: get_memory_info(), else: nil

      profiling_ref = start_profiling_tools(opts)

      result =
        try do
          fun.()
        catch
          kind, error ->
            _ = stop_profiling_tools(profiling_ref)
            :erlang.raise(kind, error, __STACKTRACE__)
        end

      profile_data = stop_profiling_tools(profiling_ref)

      end_time = System.monotonic_time(:microsecond)
      duration = end_time - start_time
      memory_after = if opts[:memory], do: get_memory_info(), else: nil

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

    defp start_profiling_tools(opts) do
      alias Raxol.Performance.FprofWrapper
      tools = %{}

      tools =
        if opts[:call_graph] do
          _ = Application.ensure_all_started(:tools)
          _ = FprofWrapper.start()
          _ = FprofWrapper.trace(:start)
          Map.put(tools, :fprof, true)
        else
          tools
        end

      if opts[:processes] do
        Map.put(tools, :process_monitor, spawn_process_monitor())
      else
        tools
      end
    end

    defp stop_profiling_tools(tools) do
      profile_data = %{}
      profile_data = stop_fprof(profile_data, Map.get(tools, :fprof))
      stop_process_monitor(profile_data, Map.get(tools, :process_monitor))
    end

    defp stop_fprof(profile_data, nil), do: profile_data
    defp stop_fprof(profile_data, false), do: profile_data

    defp stop_fprof(profile_data, true) do
      alias Raxol.Performance.FprofWrapper
      _ = FprofWrapper.trace(:stop)
      _ = FprofWrapper.profile()
      fprof_data = capture_fprof_analysis()
      _ = FprofWrapper.stop()
      Map.put(profile_data, :fprof, fprof_data)
    end

    defp stop_process_monitor(profile_data, nil), do: profile_data

    defp stop_process_monitor(profile_data, monitor_pid) do
      send(monitor_pid, :stop)

      receive do
        {:process_data, data} -> Map.put(profile_data, :processes, data)
      after
        1000 -> profile_data
      end
    end

    defp capture_fprof_analysis do
      temp_file =
        System.tmp_dir!() <> "/raxol_fprof_#{:os.system_time()}.analysis"

      try do
        _ =
          Raxol.Performance.FprofWrapper.analyse(
            dest: String.to_charlist(temp_file)
          )

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
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(& &1.memory, :desc)
      |> Enum.take(count)
    end

    defp generate_report(data) do
      duration_ms = data.duration / 1000

      report = """

      [STATS] Performance Profile Report
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

      if suggestions != [] do
        report <>
          """

          [TIP] Optimization Suggestions:
          #{Enum.map_join(suggestions, "\n", &"  • #{&1}")}
          """
      else
        report <> "\n\n[OK] No obvious optimizations detected"
      end
    end

    defp generate_optimization_suggestions(data) do
      duration_ms = data.duration / 1000
      memory_growth = memory_growth(data)

      []
      |> maybe_add(
        duration_ms > 1000,
        "Consider async execution or breaking into smaller operations (#{Float.round(duration_ms, 1)}ms)"
      )
      |> maybe_add(
        memory_growth > 50 * 1024 * 1024,
        "High memory allocation detected - consider memory pooling or streaming"
      )
    end

    defp memory_growth(%{memory_before: before, memory_after: after_mem})
         when not is_nil(before) and not is_nil(after_mem) do
      after_mem.total - before.total
    end

    defp memory_growth(_), do: 0

    defp output_report(report, format) do
      case format do
        :text ->
          Log.info(report)

        :html ->
          html_report = generate_html_report(report)
          filename = "/tmp/raxol_profile_#{:os.system_time()}.html"
          _ = File.write!(filename, html_report)
          Log.info("HTML report written to: #{filename}")

        :json ->
          json_report = Jason.encode!(parse_report_to_map(report))
          Log.info("JSON Report: #{json_report}")
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
  end

  # Always-available private functions

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
      |> Enum.reject(&is_nil/1)

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

  defp analyze_memory(memory_info) do
    total_mb = memory_info.total / (1024 * 1024)
    binary_percent = memory_info.binary / memory_info.total * 100

    issues =
      []
      |> maybe_add(
        total_mb > 100,
        "High total memory usage: #{Float.round(total_mb, 1)}MB"
      )
      |> maybe_add(
        binary_percent > 30,
        "High binary memory usage: #{Float.round(binary_percent, 1)}%"
      )

    %{
      total_mb: Float.round(total_mb, 2),
      issues: issues,
      breakdown: memory_info
    }
  end

  defp analyze_processes(process_info) do
    heavy_count =
      Enum.count(process_info.top_by_memory, &(&1.memory > 10 * 1024 * 1024))

    issues =
      []
      |> maybe_add(
        process_info.count > 1000,
        "High process count: #{process_info.count}"
      )
      |> maybe_add(
        heavy_count > 0,
        "#{heavy_count} processes using >10MB memory"
      )

    %{
      count: process_info.count,
      issues: issues,
      top_by_memory: Enum.take(process_info.top_by_memory, 5)
    }
  end

  defp analyze_system(system_info) do
    atom_usage_percent = system_info.atom_count / system_info.atom_limit * 100

    issues =
      maybe_add(
        [],
        atom_usage_percent > 80,
        "High atom usage: #{Float.round(atom_usage_percent, 1)}%"
      )

    %{
      issues: issues,
      atom_usage_percent: Float.round(atom_usage_percent, 2),
      scheduler_count: system_info.schedulers
    }
  end

  defp generate_performance_hints(analysis) do
    hints =
      Enum.map(analysis.memory.issues, &"Memory: #{&1}") ++
        Enum.map(analysis.processes.issues, &"Process: #{&1}") ++
        Enum.map(analysis.system.issues, &"System: #{&1}")

    case hints do
      [] ->
        Log.info("No issues detected")

      _ ->
        Log.warning("Analysis hints:")
        Enum.each(hints, &Log.warning("  * #{&1}"))
    end

    hints
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
      Log.info("Complete. #{length(samples)} samples.")

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

      Log.info("Growth: #{Float.round(growth_mb, 2)}MB/#{duration}ms")

      if growth_mb > 10 do
        Log.warning("Significant memory growth")
      end
    end

    samples
  end

  defp maybe_add(list, true, item), do: [item | list]
  defp maybe_add(list, false, _item), do: list
end
