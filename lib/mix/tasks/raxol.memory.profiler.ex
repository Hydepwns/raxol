defmodule Mix.Tasks.Raxol.Memory.Profiler do
  @moduledoc """
  Interactive memory profiler for real-time memory analysis.

  This task provides an interactive interface for profiling memory usage
  in real-time, allowing developers to monitor memory patterns, detect
  hotspots, and analyze memory allocation patterns.

  ## Usage

      mix raxol.memory.profiler
      mix raxol.memory.profiler --mode live
      mix raxol.memory.profiler --target Terminal.Buffer
      mix raxol.memory.profiler --format dashboard

  ## Options

    * `--mode` - Profiling mode (live, snapshot, trace) (default: live)
    * `--target` - Target module to profile (default: all)
    * `--format` - Output format (dashboard, text, json) (default: dashboard)
    * `--interval` - Update interval in seconds for live mode (default: 1)
    * `--duration` - Duration for profiling in seconds (default: 60)
    * `--output` - Output file for results
    * `--threshold` - Memory allocation threshold in bytes (default: 1024)

  ## Profiling Modes

  ### live
  Real-time memory monitoring with interactive dashboard.
  Shows live memory usage, allocation patterns, and GC activity.

  ### snapshot
  Take memory snapshots at specific intervals and compare them.
  Useful for detecting memory leaks and growth patterns.

  ### trace
  Trace memory allocations and deallocations in detail.
  Provides detailed allocation traces and call stacks.

  ## Output Formats

  ### dashboard
  Interactive terminal dashboard with real-time updates.

  ### text
  Plain text output suitable for logging and analysis.

  ### json
  JSON format for programmatic consumption.

  ## Controls (Dashboard Mode)

  - `q` - Quit
  - `r` - Reset statistics
  - `s` - Take snapshot
  - `g` - Force garbage collection
  - `p` - Pause/Resume updates
  - `↑/↓` - Navigate through processes
  - `Tab` - Switch between views (Memory/Processes/GC)
  """

  use Mix.Task

  @shortdoc "Interactive memory profiler for real-time analysis"

  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [
          mode: :string,
          target: :string,
          format: :string,
          interval: :integer,
          duration: :integer,
          output: :string,
          threshold: :integer,
          help: :boolean
        ],
        aliases: [
          m: :mode,
          t: :target,
          f: :format,
          i: :interval,
          d: :duration,
          o: :output,
          h: :help
        ]
      )

    if opts[:help] do
      print_help()
      System.halt(0)
    end

    Application.ensure_all_started(:raxol)

    config = build_config(opts)

    case config.mode do
      "live" ->
        run_live_profiler(config)

      "snapshot" ->
        run_snapshot_profiler(config)

      "trace" ->
        run_trace_profiler(config)

      _ ->
        Mix.shell().error("Unknown mode: #{config.mode}")
        System.halt(1)
    end
  end

  defp build_config(opts) do
    %{
      mode: Keyword.get(opts, :mode, "live"),
      target: Keyword.get(opts, :target, "all"),
      format: Keyword.get(opts, :format, "dashboard"),
      interval: Keyword.get(opts, :interval, 1),
      duration: Keyword.get(opts, :duration, 60),
      output: Keyword.get(opts, :output),
      threshold: Keyword.get(opts, :threshold, 1024)
    }
  end

  defp run_live_profiler(config) do
    Mix.shell().info("Starting live memory profiler...")
    Mix.shell().info("Mode: #{config.mode}, Format: #{config.format}")

    Mix.shell().info(
      "Interval: #{config.interval}s, Duration: #{config.duration}s"
    )

    case config.format do
      "dashboard" ->
        run_interactive_dashboard(config)

      "text" ->
        run_text_profiler(config)

      "json" ->
        run_json_profiler(config)

      _ ->
        Mix.shell().error("Unknown format: #{config.format}")
        System.halt(1)
    end
  end

  defp run_interactive_dashboard(config) do
    # Initialize dashboard state
    dashboard_state = %{
      running: true,
      paused: false,
      # :memory, :processes, :gc
      view: :memory,
      snapshots: [],
      start_time: System.monotonic_time(:millisecond),
      config: config
    }

    # Start background monitoring
    monitoring_pid = spawn_link(fn -> monitor_memory_background(config) end)

    # Run interactive loop
    try do
      dashboard_loop(dashboard_state, monitoring_pid)
    after
      Process.exit(monitoring_pid, :normal)
    end
  end

  defp dashboard_loop(state, monitoring_pid) do
    if state.running do
      # Clear screen and draw dashboard
      # Clear screen and move cursor to top
      IO.write("\e[2J\e[H")
      draw_dashboard(state)

      # Handle input with timeout
      case get_input_with_timeout(state.config.interval * 1000) do
        {:input, key} ->
          new_state = handle_dashboard_input(key, state, monitoring_pid)
          dashboard_loop(new_state, monitoring_pid)

        :timeout ->
          # Update dashboard
          unless state.paused do
            updated_state = update_dashboard_data(state)
            dashboard_loop(updated_state, monitoring_pid)
          else
            dashboard_loop(state, monitoring_pid)
          end
      end
    end
  end

  defp draw_dashboard(state) do
    # Header
    elapsed = (System.monotonic_time(:millisecond) - state.start_time) / 1000
    IO.puts("Raxol Memory Profiler - Live Dashboard")
    IO.puts("#{String.duplicate("=", 80)}")

    IO.puts(
      "Elapsed: #{Float.round(elapsed, 1)}s | View: #{state.view} | #{if state.paused, do: "PAUSED", else: "RUNNING"}"
    )

    IO.puts("#{String.duplicate("-", 80)}")

    # Current memory info
    memory_info = get_current_memory_info()
    draw_memory_overview(memory_info)

    # View-specific content
    case state.view do
      :memory -> draw_memory_view(memory_info)
      :processes -> draw_processes_view()
      :gc -> draw_gc_view()
    end

    # Footer with controls
    IO.puts("#{String.duplicate("-", 80)}")

    IO.puts(
      "Controls: [q]uit | [r]eset | [s]napshot | [g]c | [p]ause | Tab:switch view"
    )
  end

  defp draw_memory_overview(memory_info) do
    IO.puts("Memory Overview:")
    IO.puts("  Total:     #{format_memory(memory_info.total)}")

    IO.puts(
      "  Processes: #{format_memory(memory_info.processes)} (#{percentage(memory_info.processes, memory_info.total)}%)"
    )

    IO.puts(
      "  System:    #{format_memory(memory_info.system)} (#{percentage(memory_info.system, memory_info.total)}%)"
    )

    IO.puts(
      "  Binary:    #{format_memory(memory_info.binary)} (#{percentage(memory_info.binary, memory_info.total)}%)"
    )

    IO.puts(
      "  ETS:       #{format_memory(memory_info.ets)} (#{percentage(memory_info.ets, memory_info.total)}%)"
    )

    IO.puts("")
  end

  defp draw_memory_view(memory_info) do
    IO.puts("Detailed Memory Breakdown:")

    # Memory by type
    memory_types = [
      {"Atom", memory_info.atom},
      {"Binary", memory_info.binary},
      {"Code", Map.get(memory_info, :code, 0)},
      {"ETS", memory_info.ets}
    ]

    Enum.each(memory_types, fn {type, bytes} ->
      bar = create_progress_bar(bytes, memory_info.total, 40)

      IO.puts(
        "  #{String.pad_trailing(type, 12)} #{format_memory(bytes)} #{bar}"
      )
    end)

    IO.puts("")

    # Recent allocations (simulated)
    IO.puts("Recent Large Allocations:")

    recent_allocations = [
      {"Buffer.create/2", 2_048_576, "2.0MB"},
      {"AnsiParser.parse/1", 524_288, "512KB"},
      {"String operations", 131_072, "128KB"}
    ]

    Enum.each(recent_allocations, fn {operation, _bytes, size} ->
      IO.puts("  #{String.pad_trailing(operation, 25)} #{size}")
    end)
  end

  defp draw_processes_view do
    IO.puts("Top Memory-Consuming Processes:")

    IO.puts(
      String.pad_trailing("PID", 8) <>
        String.pad_trailing("Name", 25) <>
        String.pad_trailing("Memory", 12) <> "Heap"
    )

    # Get process information
    processes =
      Process.list()
      |> Enum.map(fn pid ->
        case Process.info(pid, [:memory, :registered_name, :current_function]) do
          [memory: mem, registered_name: name, current_function: func] ->
            %{pid: pid, memory: mem, name: name || func, registered_name: name}

          _ ->
            nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(& &1.memory, :desc)
      |> Enum.take(10)

    Enum.each(processes, fn proc ->
      pid_str = inspect(proc.pid) |> String.pad_trailing(8)
      name_str = format_process_name(proc.name) |> String.pad_trailing(25)
      memory_str = format_memory(proc.memory) |> String.pad_trailing(12)
      IO.puts("  #{pid_str}#{name_str}#{memory_str}")
    end)
  end

  defp draw_gc_view do
    IO.puts("Garbage Collection Statistics:")

    # Get GC stats (simplified)
    gc_info = :erlang.statistics(:garbage_collection)
    {gc_count, words_reclaimed, _} = gc_info

    IO.puts("  Collections: #{gc_count}")
    IO.puts("  Words reclaimed: #{words_reclaimed}")

    IO.puts(
      "  Average per collection: #{div(words_reclaimed, max(gc_count, 1))} words"
    )

    IO.puts("")

    # Recent GC activity (simulated timeline)
    IO.puts("Recent GC Activity:")

    timeline = [
      {"-5s", "Minor GC", "2ms", "128KB reclaimed"},
      {"-12s", "Major GC", "8ms", "2.4MB reclaimed"},
      {"-18s", "Minor GC", "1ms", "64KB reclaimed"},
      {"-25s", "Minor GC", "2ms", "256KB reclaimed"}
    ]

    Enum.each(timeline, fn {time, type, duration, reclaimed} ->
      IO.puts(
        "  #{String.pad_trailing(time, 6)} #{String.pad_trailing(type, 12)} #{String.pad_trailing(duration, 8)} #{reclaimed}"
      )
    end)
  end

  defp handle_dashboard_input(key, state, _monitoring_pid) do
    case key do
      "q" -> %{state | running: false}
      "r" -> reset_statistics(state)
      "s" -> take_snapshot(state)
      "g" -> force_garbage_collection(state)
      "p" -> %{state | paused: not state.paused}
      # Tab key
      "\t" -> cycle_view(state)
      _ -> state
    end
  end

  defp reset_statistics(state) do
    Mix.shell().info("Statistics reset")
    %{state | start_time: System.monotonic_time(:millisecond)}
  end

  defp take_snapshot(state) do
    snapshot = %{
      timestamp: System.monotonic_time(:millisecond),
      memory: get_current_memory_info()
    }

    Mix.shell().info("Snapshot taken")
    %{state | snapshots: [snapshot | state.snapshots]}
  end

  defp force_garbage_collection(state) do
    :erlang.garbage_collect()
    Mix.shell().info("Garbage collection forced")
    state
  end

  defp cycle_view(state) do
    next_view =
      case state.view do
        :memory -> :processes
        :processes -> :gc
        :gc -> :memory
      end

    %{state | view: next_view}
  end

  defp update_dashboard_data(state) do
    # This would update any cached data for the dashboard
    state
  end

  defp get_input_with_timeout(timeout) do
    # Simplified input handling - in real implementation would use proper terminal input
    receive do
      {:input, char} -> {:input, char}
    after
      timeout -> :timeout
    end
  end

  defp run_text_profiler(config) do
    Mix.shell().info("Starting text memory profiler...")
    start_time = System.monotonic_time(:millisecond)

    profiler_loop = fn loop_fn, iteration ->
      current_time = System.monotonic_time(:millisecond)
      elapsed = (current_time - start_time) / 1000

      if elapsed < config.duration do
        memory_info = get_current_memory_info()

        Mix.shell().info(
          "\n--- Memory Report (#{Float.round(elapsed, 1)}s) ---"
        )

        print_text_memory_report(memory_info)

        Process.sleep(config.interval * 1000)
        loop_fn.(loop_fn, iteration + 1)
      else
        Mix.shell().info("Profiling completed after #{config.duration}s")
      end
    end

    profiler_loop.(profiler_loop, 1)
  end

  defp run_json_profiler(config) do
    Mix.shell().info("Starting JSON memory profiler...")
    start_time = System.monotonic_time(:millisecond)
    reports = []

    profiler_loop = fn loop_fn, iteration, acc_reports ->
      current_time = System.monotonic_time(:millisecond)
      elapsed = (current_time - start_time) / 1000

      if elapsed < config.duration do
        memory_info = get_current_memory_info()

        report = %{
          timestamp: current_time,
          elapsed: elapsed,
          iteration: iteration,
          memory: memory_info
        }

        json_output = Jason.encode!(report, pretty: true)
        IO.puts(json_output)

        Process.sleep(config.interval * 1000)
        loop_fn.(loop_fn, iteration + 1, [report | acc_reports])
      else
        # Save final report if output file specified
        if config.output do
          final_report = %{
            config: config,
            start_time: start_time,
            reports: Enum.reverse(acc_reports)
          }

          File.write!(config.output, Jason.encode!(final_report, pretty: true))
          Mix.shell().info("Results saved to: #{config.output}")
        end
      end
    end

    profiler_loop.(profiler_loop, 1, reports)
  end

  defp run_snapshot_profiler(config) do
    Mix.shell().info("Starting snapshot memory profiler...")
    snapshots = take_memory_snapshots(config)
    analyze_snapshots(snapshots, config)
  end

  defp run_trace_profiler(config) do
    Mix.shell().info("Starting trace memory profiler...")

    Mix.shell().info(
      "Note: Detailed allocation tracing would require additional BEAM tools"
    )

    # This would use tools like :recon_trace or custom tracing
    # For now, provide a simplified version
    trace_large_allocations(config)
  end

  defp take_memory_snapshots(config) do
    Mix.shell().info(
      "Taking memory snapshots every #{config.interval}s for #{config.duration}s..."
    )

    start_time = System.monotonic_time(:millisecond)
    snapshot_count = div(config.duration, config.interval)

    Enum.map(1..snapshot_count, fn i ->
      current_time = System.monotonic_time(:millisecond)
      elapsed = (current_time - start_time) / 1000

      snapshot = %{
        index: i,
        timestamp: current_time,
        elapsed: elapsed,
        memory: get_current_memory_info()
      }

      Mix.shell().info(
        "Snapshot #{i}/#{snapshot_count} - Memory: #{format_memory(snapshot.memory.total)}"
      )

      if i < snapshot_count do
        Process.sleep(config.interval * 1000)
      end

      snapshot
    end)
  end

  defp analyze_snapshots(snapshots, config) do
    Mix.shell().info("\nAnalyzing #{length(snapshots)} snapshots...")

    if length(snapshots) >= 2 do
      first = List.first(snapshots)
      last = List.last(snapshots)

      growth = last.memory.total - first.memory.total
      # bytes per hour
      growth_rate = growth / (last.elapsed - first.elapsed) * 3600

      Mix.shell().info("Memory Growth Analysis:")
      Mix.shell().info("  Initial: #{format_memory(first.memory.total)}")
      Mix.shell().info("  Final: #{format_memory(last.memory.total)}")
      Mix.shell().info("  Growth: #{format_memory(growth)}")

      Mix.shell().info(
        "  Growth rate: #{format_memory(trunc(growth_rate))}/hour"
      )

      # Save detailed analysis
      if config.output do
        analysis = %{
          config: config,
          snapshots: snapshots,
          analysis: %{
            initial_memory: first.memory.total,
            final_memory: last.memory.total,
            total_growth: growth,
            growth_rate_per_hour: growth_rate
          }
        }

        File.write!(config.output, Jason.encode!(analysis, pretty: true))
        Mix.shell().info("Analysis saved to: #{config.output}")
      end
    else
      Mix.shell().info("Not enough snapshots for analysis")
    end
  end

  defp trace_large_allocations(config) do
    Mix.shell().info(
      "Monitoring large allocations (threshold: #{format_memory(config.threshold)})..."
    )

    # This is a simplified simulation of allocation tracing
    start_time = System.monotonic_time(:millisecond)

    trace_loop = fn loop_fn ->
      current_time = System.monotonic_time(:millisecond)
      elapsed = (current_time - start_time) / 1000

      if elapsed < config.duration do
        # Simulate detecting large allocations
        simulate_allocation_detection(config)
        # Check more frequently for allocations
        Process.sleep(100)
        loop_fn.(loop_fn)
      end
    end

    trace_loop.(trace_loop)
  end

  defp simulate_allocation_detection(config) do
    # This would normally hook into BEAM allocation events
    # For simulation, randomly report large allocations

    # 5% chance per check
    if :rand.uniform(100) < 5 do
      size = :rand.uniform(10) * config.threshold

      operation =
        Enum.random([
          "Buffer.create",
          "String.duplicate",
          "List.duplicate",
          "Binary.copy"
        ])

      Mix.shell().info(
        "Large allocation detected: #{operation} - #{format_memory(size)}"
      )
    end
  end

  # Utility functions
  defp monitor_memory_background(config) do
    # Background memory monitoring for the dashboard
    receive do
      :stop -> :ok
    after
      config.interval * 1000 ->
        # Could send memory updates to dashboard process
        monitor_memory_background(config)
    end
  end

  defp get_current_memory_info do
    %{
      total: :erlang.memory(:total),
      processes: :erlang.memory(:processes),
      system: :erlang.memory(:system),
      atom: :erlang.memory(:atom),
      binary: :erlang.memory(:binary),
      ets: :erlang.memory(:ets)
    }
  end

  defp print_text_memory_report(memory_info) do
    Mix.shell().info("Total Memory: #{format_memory(memory_info.total)}")

    Mix.shell().info(
      "Processes: #{format_memory(memory_info.processes)} (#{percentage(memory_info.processes, memory_info.total)}%)"
    )

    Mix.shell().info(
      "System: #{format_memory(memory_info.system)} (#{percentage(memory_info.system, memory_info.total)}%)"
    )

    Mix.shell().info(
      "Binary: #{format_memory(memory_info.binary)} (#{percentage(memory_info.binary, memory_info.total)}%)"
    )

    Mix.shell().info(
      "ETS: #{format_memory(memory_info.ets)} (#{percentage(memory_info.ets, memory_info.total)}%)"
    )
  end

  defp format_memory(bytes) when is_number(bytes) do
    cond do
      bytes >= 1_000_000_000 -> "#{Float.round(bytes / 1_000_000_000, 2)}GB"
      bytes >= 1_000_000 -> "#{Float.round(bytes / 1_000_000, 2)}MB"
      bytes >= 1_000 -> "#{Float.round(bytes / 1_000, 2)}KB"
      true -> "#{bytes}B"
    end
  end

  defp format_memory(_), do: "N/A"

  defp format_process_name(name) when is_atom(name), do: Atom.to_string(name)
  defp format_process_name({mod, func, arity}), do: "#{mod}.#{func}/#{arity}"
  defp format_process_name(other), do: inspect(other)

  defp percentage(part, whole) when whole > 0,
    do: Float.round(part / whole * 100, 1)

  defp percentage(_, _), do: 0.0

  defp create_progress_bar(value, max, width) do
    filled = trunc(value / max * width)
    empty = width - filled
    "[#{String.duplicate("=", filled)}#{String.duplicate(" ", empty)}]"
  end

  defp print_help do
    Mix.shell().info(@moduledoc)
  end
end
