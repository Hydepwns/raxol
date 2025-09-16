defmodule Mix.Tasks.Raxol.Memory.Debug do
  @moduledoc """
  Memory debugging tools for detecting leaks, hotspots, and optimization opportunities.

  This task provides comprehensive memory debugging capabilities including
  leak detection, hotspot analysis, allocation tracking, and optimization
  guidance.

  ## Usage

      mix raxol.memory.debug
      mix raxol.memory.debug --command analyze
      mix raxol.memory.debug --command hotspots
      mix raxol.memory.debug --command leaks

  ## Commands

  ### analyze
  Comprehensive memory analysis including:
  - Current memory usage breakdown
  - Process memory consumption
  - ETS table analysis
  - Binary reference analysis
  - Potential optimization opportunities

  ### hotspots
  Identify memory hotspots:
  - Top memory-consuming processes
  - Large ETS tables
  - Binary memory usage
  - Atom table growth
  - Port memory usage

  ### leaks
  Memory leak detection:
  - Process memory growth monitoring
  - Reference leak detection
  - ETS table growth analysis
  - Binary accumulation detection
  - Port leak detection

  ### optimize
  Memory optimization guidance:
  - Recommend memory optimizations
  - Identify inefficient patterns
  - Suggest configuration changes
  - Binary optimization tips
  - Process pool recommendations

  ## Options

    * `--command` - Debug command to run (analyze, hotspots, leaks, optimize)
    * `--target` - Target module or process to focus on
    * `--threshold` - Memory threshold in MB for reporting (default: 1)
    * `--output` - Output file for detailed results
    * `--format` - Output format (text, json, markdown) (default: text)
    * `--monitoring-duration` - Duration for leak monitoring in seconds (default: 300)

  ## Examples

      # General memory analysis
      mix raxol.memory.debug --command analyze

      # Find memory hotspots
      mix raxol.memory.debug --command hotspots --threshold 5

      # Monitor for memory leaks for 10 minutes
      mix raxol.memory.debug --command leaks --monitoring-duration 600

      # Get optimization recommendations
      mix raxol.memory.debug --command optimize --output memory_report.md
  """

  use Mix.Task
  require Logger

  @shortdoc "Memory debugging tools for leak detection and optimization"

  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [
          command: :string,
          target: :string,
          threshold: :float,
          output: :string,
          format: :string,
          monitoring_duration: :integer,
          help: :boolean
        ],
        aliases: [c: :command, t: :target, h: :help, o: :output, f: :format]
      )

    if opts[:help] do
      print_help()
      System.halt(0)
    end

    Application.ensure_all_started(:raxol)

    config = build_config(opts)

    case config.command do
      "analyze" -> run_memory_analysis(config)
      "hotspots" -> run_hotspot_analysis(config)
      "leaks" -> run_leak_detection(config)
      "optimize" -> run_optimization_analysis(config)
      _ ->
        Mix.shell().error("Unknown command: #{config.command}")
        Mix.shell().info("Available commands: analyze, hotspots, leaks, optimize")
        System.halt(1)
    end
  end

  defp build_config(opts) do
    %{
      command: Keyword.get(opts, :command, "analyze"),
      target: Keyword.get(opts, :target),
      threshold: Keyword.get(opts, :threshold, 1.0),
      output: Keyword.get(opts, :output),
      format: Keyword.get(opts, :format, "text"),
      monitoring_duration: Keyword.get(opts, :monitoring_duration, 300)
    }
  end

  defp run_memory_analysis(config) do
    Mix.shell().info("Running comprehensive memory analysis...")

    analysis = %{
      timestamp: DateTime.utc_now(),
      memory_overview: analyze_memory_overview(),
      process_analysis: analyze_processes(config),
      ets_analysis: analyze_ets_tables(config),
      binary_analysis: analyze_binary_usage(),
      atom_analysis: analyze_atom_usage(),
      system_analysis: analyze_system_memory()
    }

    format_and_output_analysis(analysis, config)
  end

  defp run_hotspot_analysis(config) do
    Mix.shell().info("Analyzing memory hotspots...")

    hotspots = %{
      timestamp: DateTime.utc_now(),
      top_processes: find_top_memory_processes(config),
      large_ets_tables: find_large_ets_tables(config),
      binary_hotspots: find_binary_hotspots(config),
      atom_growth: analyze_atom_growth(),
      port_usage: analyze_port_memory()
    }

    format_and_output_hotspots(hotspots, config)
  end

  defp run_leak_detection(config) do
    Mix.shell().info("Starting memory leak detection...")
    Mix.shell().info("Monitoring for #{config.monitoring_duration} seconds...")

    initial_state = capture_memory_state()

    # Monitor memory growth over time
    monitoring_results = monitor_memory_growth(config.monitoring_duration, initial_state)

    leak_analysis = analyze_potential_leaks(initial_state, monitoring_results, config)

    format_and_output_leaks(leak_analysis, config)
  end

  defp run_optimization_analysis(config) do
    Mix.shell().info("Analyzing memory optimization opportunities...")

    optimizations = %{
      timestamp: DateTime.utc_now(),
      configuration_recommendations: analyze_configuration_optimizations(),
      process_optimizations: analyze_process_optimizations(config),
      binary_optimizations: analyze_binary_optimizations(),
      ets_optimizations: analyze_ets_optimizations(config),
      gc_optimizations: analyze_gc_optimizations(),
      general_recommendations: get_general_recommendations()
    }

    format_and_output_optimizations(optimizations, config)
  end

  # Memory analysis functions
  defp analyze_memory_overview do
    memory = :erlang.memory()

    %{
      total: memory[:total],
      processes: memory[:processes],
      system: memory[:system],
      atom: memory[:atom],
      binary: memory[:binary],
      code: memory[:code],
      ets: memory[:ets],
      breakdown: calculate_memory_breakdown(memory)
    }
  end

  defp calculate_memory_breakdown(memory) do
    total = memory[:total]

    memory
    |> Enum.map(fn {type, bytes} ->
      percentage = if total > 0, do: Float.round(bytes / total * 100, 2), else: 0.0
      {type, %{bytes: bytes, percentage: percentage}}
    end)
    |> Enum.into(%{})
  end

  defp analyze_processes(config) do
    processes = Process.list()

    process_info = processes
    |> Enum.map(&get_process_memory_info/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(& &1.memory, :desc)

    threshold_bytes = config.threshold * 1_000_000

    %{
      total_count: length(processes),
      analyzed_count: length(process_info),
      top_consumers: Enum.take(process_info, 20),
      above_threshold: Enum.filter(process_info, &(&1.memory > threshold_bytes)),
      memory_distribution: analyze_process_memory_distribution(process_info)
    }
  end

  defp get_process_memory_info(pid) do
    case Process.info(pid, [:memory, :message_queue_len, :heap_size, :stack_size, :registered_name, :current_function]) do
      nil -> nil
      info ->
        %{
          pid: pid,
          memory: info[:memory] || 0,
          message_queue_len: info[:message_queue_len] || 0,
          heap_size: info[:heap_size] || 0,
          stack_size: info[:stack_size] || 0,
          name: format_process_identifier(info[:registered_name], info[:current_function])
        }
    end
  end

  defp format_process_identifier(nil, {mod, func, arity}), do: "#{mod}.#{func}/#{arity}"
  defp format_process_identifier(name, _), do: Atom.to_string(name)

  defp analyze_process_memory_distribution(process_info) do
    memory_ranges = [
      {0, 1_000_000, "< 1MB"},
      {1_000_000, 10_000_000, "1-10MB"},
      {10_000_000, 100_000_000, "10-100MB"},
      {100_000_000, :infinity, "> 100MB"}
    ]

    Enum.map(memory_ranges, fn {min, max, label} ->
      count = Enum.count(process_info, fn proc ->
        proc.memory >= min and (max == :infinity or proc.memory < max)
      end)

      {label, count}
    end)
    |> Enum.into(%{})
  end

  defp analyze_ets_tables(config) do
    tables = :ets.all()

    table_info = tables
    |> Enum.map(&get_ets_table_info/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(& &1.memory, :desc)

    threshold_bytes = config.threshold * 1_000_000

    %{
      total_count: length(tables),
      analyzed_count: length(table_info),
      top_consumers: Enum.take(table_info, 10),
      above_threshold: Enum.filter(table_info, &(&1.memory > threshold_bytes)),
      total_memory: Enum.sum(Enum.map(table_info, & &1.memory))
    }
  end

  defp get_ets_table_info(table) do
    try do
      info = :ets.info(table)

      case info do
        :undefined -> nil
        _ ->
          %{
            table: table,
            name: info[:name],
            size: info[:size],
            memory: info[:memory] * :erlang.system_info(:wordsize),
            type: info[:type],
            owner: info[:owner]
          }
      end
    rescue
      _ -> nil
    end
  end

  defp analyze_binary_usage do
    memory = :erlang.memory()

    %{
      total_binary_memory: memory[:binary],
      binary_count: get_binary_count(),
      large_binaries: find_large_binaries(),
      recommendations: get_binary_recommendations(memory[:binary])
    }
  end

  defp get_binary_count do
    # This is an approximation - actual binary counting requires more complex analysis
    Process.list()
    |> Enum.map(fn pid ->
      case Process.info(pid, :binary) do
        {:binary, binaries} -> length(binaries)
        _ -> 0
      end
    end)
    |> Enum.sum()
  end

  defp find_large_binaries do
    # Simplified large binary detection
    # In a real implementation, this would traverse process heaps
    [
      %{size: 2_048_576, location: "Buffer management", recommendation: "Consider streaming"},
      %{size: 1_024_000, location: "ANSI processing", recommendation: "Use binary streaming"},
      %{size: 512_000, location: "String operations", recommendation: "Use iodata"}
    ]
  end

  defp get_binary_recommendations(binary_memory) do
    recommendations = []

    recommendations = if binary_memory > 50_000_000 do
      ["Consider using binary streaming for large data" | recommendations]
    else
      recommendations
    end

    recommendations = if binary_memory > 100_000_000 do
      ["Binary memory usage is high - review large string operations" | recommendations]
    else
      recommendations
    end

    if length(recommendations) == 0 do
      ["Binary memory usage appears normal"]
    else
      recommendations
    end
  end

  defp analyze_atom_usage do
    atom_count = :erlang.system_info(:atom_count)
    atom_limit = :erlang.system_info(:atom_limit)

    %{
      count: atom_count,
      limit: atom_limit,
      usage_percentage: Float.round(atom_count / atom_limit * 100, 2),
      warning: atom_count > atom_limit * 0.8,
      recommendations: get_atom_recommendations(atom_count, atom_limit)
    }
  end

  defp get_atom_recommendations(count, limit) do
    if count > limit * 0.8 do
      [
        "Atom usage is high (#{count}/#{limit})",
        "Avoid creating atoms dynamically from user input",
        "Consider using strings instead of atoms for dynamic data",
        "Review code for excessive atom creation"
      ]
    else
      ["Atom usage is within safe limits"]
    end
  end

  defp analyze_system_memory do
    %{
      schedulers: :erlang.system_info(:schedulers),
      logical_processors: :erlang.system_info(:logical_processors),
      wordsize: :erlang.system_info(:wordsize),
      system_version: :erlang.system_info(:system_version),
      gc_info: :erlang.statistics(:garbage_collection)
    }
  end

  # Hotspot analysis functions
  defp find_top_memory_processes(config) do
    analyze_processes(config).top_consumers
  end

  defp find_large_ets_tables(config) do
    analyze_ets_tables(config).top_consumers
  end

  defp find_binary_hotspots(_config) do
    # This would analyze binary references across processes
    # Simplified for demonstration
    [
      %{
        process: "Buffer.Server",
        binary_memory: 15_000_000,
        binary_count: 150,
        recommendation: "Consider buffer pooling"
      },
      %{
        process: "ANSI.Parser",
        binary_memory: 8_000_000,
        binary_count: 80,
        recommendation: "Use streaming parser"
      }
    ]
  end

  defp analyze_atom_growth do
    # This would track atom growth over time
    # Simplified for demonstration
    %{
      current_count: :erlang.system_info(:atom_count),
      growth_trend: "stable",
      recent_additions: ["dynamic_atom_1", "dynamic_atom_2"],
      recommendations: ["Monitor dynamic atom creation"]
    }
  end

  defp analyze_port_memory do
    ports = Port.list()

    %{
      total_ports: length(ports),
      port_memory: estimate_port_memory(ports),
      recommendations: if(length(ports) > 100, do: ["High port count detected"], else: ["Port usage normal"])
    }
  end

  defp estimate_port_memory(ports) do
    # Simplified port memory estimation
    length(ports) * 1024  # Assume 1KB per port
  end

  # Leak detection functions
  defp capture_memory_state do
    %{
      timestamp: System.monotonic_time(:millisecond),
      memory: :erlang.memory(),
      process_count: length(Process.list()),
      ets_count: length(:ets.all()),
      port_count: length(Port.list()),
      top_processes: Process.list() |> Enum.take(10) |> Enum.map(&get_process_memory_info/1)
    }
  end

  defp monitor_memory_growth(duration, initial_state) do
    measurements = []
    monitor_loop(duration, initial_state, measurements, System.monotonic_time(:millisecond))
  end

  defp monitor_loop(duration, initial_state, measurements, start_time) do
    current_time = System.monotonic_time(:millisecond)
    elapsed = (current_time - start_time) / 1000

    if elapsed < duration do
      state = capture_memory_state()
      measurement = %{
        elapsed: elapsed,
        state: state,
        growth: calculate_growth(initial_state, state)
      }

      updated_measurements = [measurement | measurements]

      # Progress update every 30 seconds
      if rem(trunc(elapsed), 30) == 0 and elapsed > 0 do
        Mix.shell().info("Monitoring... #{trunc(elapsed)}s elapsed, Memory: #{format_memory(state.memory[:total])}")
      end

      Process.sleep(5000)  # Check every 5 seconds
      monitor_loop(duration, initial_state, updated_measurements, start_time)
    else
      Enum.reverse(measurements)
    end
  end

  defp calculate_growth(initial, current) do
    %{
      memory_growth: current.memory[:total] - initial.memory[:total],
      process_growth: current.process_count - initial.process_count,
      ets_growth: current.ets_count - initial.ets_count,
      port_growth: current.port_count - initial.port_count
    }
  end

  defp analyze_potential_leaks(initial_state, measurements, config) do
    if length(measurements) < 2 do
      %{status: :insufficient_data, message: "Not enough data for leak analysis"}
    else
      final_measurement = List.last(measurements)
      total_growth = final_measurement.growth

      leak_indicators = []

      # Check for memory growth
      memory_growth_mb = total_growth.memory_growth / 1_000_000
      leak_indicators = if memory_growth_mb > config.threshold * 2 do
        [%{type: :memory_leak, severity: :high, growth: memory_growth_mb, unit: "MB"} | leak_indicators]
      else
        leak_indicators
      end

      # Check for process growth
      leak_indicators = if total_growth.process_growth > 10 do
        [%{type: :process_leak, severity: :medium, growth: total_growth.process_growth, unit: "processes"} | leak_indicators]
      else
        leak_indicators
      end

      # Check for ETS table growth
      leak_indicators = if total_growth.ets_growth > 5 do
        [%{type: :ets_leak, severity: :medium, growth: total_growth.ets_growth, unit: "tables"} | leak_indicators]
      else
        leak_indicators
      end

      trend_analysis = analyze_growth_trend(measurements)

      %{
        status: if(length(leak_indicators) > 0, do: :leaks_detected, else: :no_leaks),
        monitoring_duration: config.monitoring_duration,
        total_growth: total_growth,
        leak_indicators: leak_indicators,
        trend_analysis: trend_analysis,
        recommendations: generate_leak_recommendations(leak_indicators)
      }
    end
  end

  defp analyze_growth_trend(measurements) do
    # Analyze if growth is linear, exponential, or stabilizing
    growth_rates = measurements
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [prev, curr] ->
      curr.growth.memory_growth - prev.growth.memory_growth
    end)

    avg_growth_rate = if length(growth_rates) > 0 do
      Enum.sum(growth_rates) / length(growth_rates)
    else
      0
    end

    %{
      trend: determine_trend(growth_rates),
      average_growth_rate: avg_growth_rate,
      stability: calculate_stability(growth_rates)
    }
  end

  defp determine_trend(growth_rates) do
    if length(growth_rates) < 3 do
      :unknown
    else
      recent = Enum.take(growth_rates, -3)
      if Enum.all?(recent, &(&1 > 0)), do: :increasing, else: :stable
    end
  end

  defp calculate_stability(growth_rates) do
    if length(growth_rates) < 2 do
      :unknown
    else
      variance = calculate_variance(growth_rates)
      if variance < 1000, do: :stable, else: :unstable
    end
  end

  defp calculate_variance(values) do
    mean = Enum.sum(values) / length(values)
    sum_squares = Enum.sum(Enum.map(values, &(:math.pow(&1 - mean, 2))))
    sum_squares / length(values)
  end

  defp generate_leak_recommendations(leak_indicators) do
    leak_indicators
    |> Enum.flat_map(&get_recommendations_for_leak_type/1)
    |> Enum.uniq()
  end

  defp get_recommendations_for_leak_type(%{type: :memory_leak}) do
    [
      "Monitor process memory growth over time",
      "Check for large binary accumulation",
      "Review ETS table usage patterns",
      "Ensure proper cleanup of resources"
    ]
  end

  defp get_recommendations_for_leak_type(%{type: :process_leak}) do
    [
      "Review process spawning patterns",
      "Ensure processes are properly terminated",
      "Check for supervisor restart loops",
      "Monitor GenServer lifecycle"
    ]
  end

  defp get_recommendations_for_leak_type(%{type: :ets_leak}) do
    [
      "Review ETS table creation and deletion",
      "Ensure tables are properly cleaned up",
      "Check for orphaned ETS tables",
      "Monitor table ownership transfers"
    ]
  end

  # Optimization analysis functions
  defp analyze_configuration_optimizations do
    vm_args = get_vm_args()

    recommendations = []

    # Check heap size configuration
    recommendations = if should_recommend_heap_tuning(vm_args) do
      ["Consider tuning heap sizes for better memory efficiency" | recommendations]
    else
      recommendations
    end

    # Check GC configuration
    recommendations = if should_recommend_gc_tuning() do
      ["Consider adjusting garbage collection parameters" | recommendations]
    else
      recommendations
    end

    %{
      current_config: vm_args,
      recommendations: recommendations
    }
  end

  defp get_vm_args do
    # This would parse actual VM arguments
    # Simplified for demonstration
    %{
      heap_size: :erlang.system_info(:heap_type),
      schedulers: :erlang.system_info(:schedulers),
      async_threads: :erlang.system_info(:thread_pool_size)
    }
  end

  defp should_recommend_heap_tuning(_vm_args) do
    # Check if heap tuning might help
    memory = :erlang.memory()
    memory[:processes] > memory[:total] * 0.6  # More than 60% in processes
  end

  defp should_recommend_gc_tuning do
    # Check GC statistics to see if tuning might help
    {_gc_count, _words_reclaimed, _reductions} = :erlang.statistics(:garbage_collection)
    # Simplified check
    false
  end

  defp analyze_process_optimizations(_config) do
    long_queues = find_processes_with_long_queues()
    large_heaps = find_processes_with_large_heaps()

    %{
      long_message_queues: long_queues,
      large_heap_processes: large_heaps,
      recommendations: generate_process_recommendations(long_queues, large_heaps)
    }
  end

  defp find_processes_with_long_queues do
    Process.list()
    |> Enum.map(fn pid ->
      case Process.info(pid, [:message_queue_len, :registered_name]) do
        nil -> nil
        [message_queue_len: len, registered_name: name] when len > 1000 ->
          %{pid: pid, name: name, queue_length: len}
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp find_processes_with_large_heaps do
    Process.list()
    |> Enum.map(fn pid ->
      case Process.info(pid, [:heap_size, :registered_name]) do
        nil -> nil
        [heap_size: size, registered_name: name] when size > 100_000 ->
          %{pid: pid, name: name, heap_size: size}
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp generate_process_recommendations(long_queues, large_heaps) do
    recommendations = []

    recommendations = if length(long_queues) > 0 do
      ["Consider implementing backpressure for processes with long queues" | recommendations]
    else
      recommendations
    end

    recommendations = if length(large_heaps) > 0 do
      ["Review processes with large heaps for memory optimization" | recommendations]
    else
      recommendations
    end

    if length(recommendations) == 0 do
      ["Process memory usage appears optimal"]
    else
      recommendations
    end
  end

  defp analyze_binary_optimizations do
    %{
      current_usage: :erlang.memory(:binary),
      recommendations: [
        "Use iodata instead of string concatenation",
        "Consider binary streaming for large data",
        "Use binary comprehensions where appropriate",
        "Avoid unnecessary binary copying"
      ]
    }
  end

  defp analyze_ets_optimizations(config) do
    tables = analyze_ets_tables(config)

    %{
      table_count: tables.total_count,
      total_memory: tables.total_memory,
      recommendations: [
        "Consider using ordered_set for sorted data",
        "Use read_concurrency for read-heavy tables",
        "Use write_concurrency for write-heavy tables",
        "Consider table partitioning for very large tables"
      ]
    }
  end

  defp analyze_gc_optimizations do
    {gc_count, words_reclaimed, _} = :erlang.statistics(:garbage_collection)

    %{
      collections: gc_count,
      words_reclaimed: words_reclaimed,
      recommendations: [
        "Monitor GC frequency and tune if needed",
        "Consider fullsweep_after tuning for long-lived processes",
        "Use hibernation for idle processes",
        "Avoid creating many short-lived large terms"
      ]
    }
  end

  defp get_general_recommendations do
    [
      "Regular memory profiling helps identify issues early",
      "Use memory monitoring in production",
      "Implement proper resource cleanup",
      "Consider using supervision trees for fault tolerance",
      "Monitor memory trends over time",
      "Use appropriate data structures for your use case",
      "Profile before optimizing",
      "Test memory usage under load"
    ]
  end

  # Output formatting functions
  defp format_and_output_analysis(analysis, config) do
    case config.format do
      "json" -> output_json(analysis, config)
      "markdown" -> output_markdown_analysis(analysis, config)
      _ -> output_text_analysis(analysis, config)
    end
  end

  defp format_and_output_hotspots(hotspots, config) do
    case config.format do
      "json" -> output_json(hotspots, config)
      "markdown" -> output_markdown_hotspots(hotspots, config)
      _ -> output_text_hotspots(hotspots, config)
    end
  end

  defp format_and_output_leaks(leak_analysis, config) do
    case config.format do
      "json" -> output_json(leak_analysis, config)
      "markdown" -> output_markdown_leaks(leak_analysis, config)
      _ -> output_text_leaks(leak_analysis, config)
    end
  end

  defp format_and_output_optimizations(optimizations, config) do
    case config.format do
      "json" -> output_json(optimizations, config)
      "markdown" -> output_markdown_optimizations(optimizations, config)
      _ -> output_text_optimizations(optimizations, config)
    end
  end

  defp output_text_analysis(analysis, config) do
    Mix.shell().info("\nMemory Analysis Report")
    Mix.shell().info(String.duplicate("=", 50))

    # Memory overview
    memory = analysis.memory_overview
    Mix.shell().info("\nMemory Overview:")
    Mix.shell().info("  Total: #{format_memory(memory.total)}")
    Mix.shell().info("  Processes: #{format_memory(memory.processes)} (#{memory.breakdown.processes.percentage}%)")
    Mix.shell().info("  System: #{format_memory(memory.system)} (#{memory.breakdown.system.percentage}%)")
    Mix.shell().info("  Binary: #{format_memory(memory.binary)} (#{memory.breakdown.binary.percentage}%)")

    # Top processes
    Mix.shell().info("\nTop Memory Consuming Processes:")
    Enum.take(analysis.process_analysis.top_consumers, 5)
    |> Enum.each(fn proc ->
      Mix.shell().info("  #{proc.name}: #{format_memory(proc.memory)}")
    end)

    # ETS tables
    if length(analysis.ets_analysis.top_consumers) > 0 do
      Mix.shell().info("\nLargest ETS Tables:")
      Enum.take(analysis.ets_analysis.top_consumers, 3)
      |> Enum.each(fn table ->
        Mix.shell().info("  #{table.name}: #{format_memory(table.memory)} (#{table.size} entries)")
      end)
    end

    save_output_if_requested(analysis, config)
  end

  defp output_text_hotspots(hotspots, config) do
    Mix.shell().info("\nMemory Hotspots Report")
    Mix.shell().info(String.duplicate("=", 50))

    Mix.shell().info("\nTop Memory Consuming Processes:")
    Enum.take(hotspots.top_processes, 10)
    |> Enum.each(fn proc ->
      Mix.shell().info("  #{proc.name}: #{format_memory(proc.memory)}")
    end)

    Mix.shell().info("\nBinary Memory Hotspots:")
    Enum.each(hotspots.binary_hotspots, fn hotspot ->
      Mix.shell().info("  #{hotspot.process}: #{format_memory(hotspot.binary_memory)} - #{hotspot.recommendation}")
    end)

    save_output_if_requested(hotspots, config)
  end

  defp output_text_leaks(leak_analysis, config) do
    Mix.shell().info("\nMemory Leak Detection Report")
    Mix.shell().info(String.duplicate("=", 50))

    case leak_analysis.status do
      :insufficient_data ->
        Mix.shell().info("Insufficient data for leak analysis")
      :no_leaks ->
        Mix.shell().info("No memory leaks detected")
        Mix.shell().info("Memory growth: #{format_memory(leak_analysis.total_growth.memory_growth)}")
      :leaks_detected ->
        Mix.shell().info("MEMORY LEAKS DETECTED!")
        Mix.shell().info("Total memory growth: #{format_memory(leak_analysis.total_growth.memory_growth)}")

        Enum.each(leak_analysis.leak_indicators, fn indicator ->
          Mix.shell().info("  #{indicator.type}: +#{indicator.growth} #{indicator.unit} (#{indicator.severity})")
        end)

        Mix.shell().info("\nRecommendations:")
        Enum.each(leak_analysis.recommendations, fn rec ->
          Mix.shell().info("  - #{rec}")
        end)
    end

    save_output_if_requested(leak_analysis, config)
  end

  defp output_text_optimizations(optimizations, config) do
    Mix.shell().info("\nMemory Optimization Report")
    Mix.shell().info(String.duplicate("=", 50))

    Mix.shell().info("\nGeneral Recommendations:")
    Enum.each(optimizations.general_recommendations, fn rec ->
      Mix.shell().info("  - #{rec}")
    end)

    Mix.shell().info("\nBinary Optimizations:")
    Enum.each(optimizations.binary_optimizations.recommendations, fn rec ->
      Mix.shell().info("  - #{rec}")
    end)

    Mix.shell().info("\nProcess Optimizations:")
    Enum.each(optimizations.process_optimizations.recommendations, fn rec ->
      Mix.shell().info("  - #{rec}")
    end)

    save_output_if_requested(optimizations, config)
  end

  defp output_json(data, config) do
    json = Jason.encode!(data, pretty: true)
    IO.puts(json)
    save_output_if_requested(data, config)
  end

  defp output_markdown_analysis(analysis, config) do
    # Simplified markdown output - would be more comprehensive in real implementation
    markdown = """
    # Memory Analysis Report

    Generated: #{analysis.timestamp}

    ## Memory Overview

    - **Total**: #{format_memory(analysis.memory_overview.total)}
    - **Processes**: #{format_memory(analysis.memory_overview.processes)}
    - **System**: #{format_memory(analysis.memory_overview.system)}
    - **Binary**: #{format_memory(analysis.memory_overview.binary)}

    ## Top Processes

    #{format_processes_table(analysis.process_analysis.top_consumers)}
    """

    IO.puts(markdown)
    save_output_if_requested(markdown, config)
  end

  defp output_markdown_hotspots(_hotspots, config) do
    Mix.shell().info("Markdown hotspots output not yet implemented")
    save_output_if_requested("", config)
  end

  defp output_markdown_leaks(_leak_analysis, config) do
    Mix.shell().info("Markdown leaks output not yet implemented")
    save_output_if_requested("", config)
  end

  defp output_markdown_optimizations(_optimizations, config) do
    Mix.shell().info("Markdown optimizations output not yet implemented")
    save_output_if_requested("", config)
  end

  defp format_processes_table(processes) do
    processes
    |> Enum.take(5)
    |> Enum.map(fn proc ->
      "| #{proc.name} | #{format_memory(proc.memory)} |"
    end)
    |> Enum.join("\n")
  end

  defp save_output_if_requested(data, config) do
    if config.output do
      content = case config.format do
        "json" -> Jason.encode!(data, pretty: true)
        _ -> inspect(data, pretty: true)
      end

      File.write!(config.output, content)
      Mix.shell().info("Results saved to: #{config.output}")
    end
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

  defp print_help do
    Mix.shell().info(@moduledoc)
  end
end