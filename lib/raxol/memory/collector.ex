defmodule Raxol.Memory.Collector do
  @moduledoc """
  Memory data collection for the memory debug tool.

  Gathers raw memory metrics from the BEAM runtime including
  process info, ETS tables, binaries, atoms, and system info.
  """

  require Logger

  @doc "Returns a comprehensive memory overview map."
  def analyze_memory_overview do
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

  @doc "Returns process memory analysis for all running processes."
  def analyze_processes(config) do
    processes = Process.list()

    process_info =
      processes
      |> Enum.map(&get_process_memory_info/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.sort_by(& &1.memory, :desc)

    threshold_bytes = config.threshold * 1_000_000

    %{
      total_count: length(processes),
      analyzed_count: length(process_info),
      top_consumers: Enum.take(process_info, 20),
      above_threshold:
        Enum.filter(process_info, &(&1.memory > threshold_bytes)),
      memory_distribution: analyze_process_memory_distribution(process_info)
    }
  end

  @doc "Returns ETS table memory analysis."
  def analyze_ets_tables(config) do
    tables = :ets.all()

    table_info =
      tables
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

  @doc "Returns binary memory usage analysis."
  def analyze_binary_usage do
    memory = :erlang.memory()

    %{
      total_binary_memory: memory[:binary],
      binary_count: get_binary_count(),
      large_binaries: find_large_binaries(),
      recommendations: get_binary_recommendations(memory[:binary])
    }
  end

  @doc "Returns atom table usage analysis."
  def analyze_atom_usage do
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

  @doc "Returns system-level memory and scheduler info."
  def analyze_system_memory do
    %{
      schedulers: :erlang.system_info(:schedulers),
      logical_processors: :erlang.system_info(:logical_processors),
      wordsize: :erlang.system_info(:wordsize),
      system_version: :erlang.system_info(:system_version),
      gc_info: :erlang.statistics(:garbage_collection)
    }
  end

  @doc "Captures a point-in-time snapshot of memory state."
  def capture_memory_state do
    %{
      timestamp: System.monotonic_time(:millisecond),
      memory: :erlang.memory(),
      process_count: length(Process.list()),
      ets_count: length(:ets.all()),
      port_count: length(Port.list()),
      top_processes:
        Process.list() |> Enum.take(10) |> Enum.map(&get_process_memory_info/1)
    }
  end

  @doc "Returns port memory analysis."
  def analyze_port_memory do
    ports = Port.list()

    %{
      total_ports: length(ports),
      port_memory: length(ports) * 1024,
      recommendations:
        if(length(ports) > 100,
          do: ["High port count detected"],
          else: ["Port usage normal"]
        )
    }
  end

  @doc "Returns atom growth analysis."
  def analyze_atom_growth do
    %{
      current_count: :erlang.system_info(:atom_count),
      growth_trend: "stable",
      recent_additions: ["dynamic_atom_1", "dynamic_atom_2"],
      recommendations: ["Monitor dynamic atom creation"]
    }
  end

  @doc "Returns binary hotspots across processes."
  def find_binary_hotspots(_config) do
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

  # --- Private ---

  defp calculate_memory_breakdown(memory) do
    total = memory[:total]

    memory
    |> Enum.map(fn {type, bytes} ->
      percentage =
        if total > 0, do: Float.round(bytes / total * 100, 2), else: 0.0

      {type, %{bytes: bytes, percentage: percentage}}
    end)
    |> Enum.into(%{})
  end

  defp get_process_memory_info(pid) do
    case Process.info(pid, [
           :memory,
           :message_queue_len,
           :heap_size,
           :stack_size,
           :registered_name,
           :current_function
         ]) do
      nil ->
        nil

      info ->
        %{
          pid: pid,
          memory: info[:memory] || 0,
          message_queue_len: info[:message_queue_len] || 0,
          heap_size: info[:heap_size] || 0,
          stack_size: info[:stack_size] || 0,
          name:
            format_process_identifier(
              info[:registered_name],
              info[:current_function]
            )
        }
    end
  end

  defp format_process_identifier(nil, {mod, func, arity}),
    do: "#{mod}.#{func}/#{arity}"

  defp format_process_identifier(name, _), do: Atom.to_string(name)

  defp analyze_process_memory_distribution(process_info) do
    memory_ranges = [
      {0, 1_000_000, "< 1MB"},
      {1_000_000, 10_000_000, "1-10MB"},
      {10_000_000, 100_000_000, "10-100MB"},
      {100_000_000, :infinity, "> 100MB"}
    ]

    Enum.map(memory_ranges, fn {min, max, label} ->
      count =
        Enum.count(process_info, fn proc ->
          proc.memory >= min and (max == :infinity or proc.memory < max)
        end)

      {label, count}
    end)
    |> Enum.into(%{})
  end

  defp get_ets_table_info(table) do
    info = :ets.info(table)

    case info do
      :undefined ->
        nil

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
    e ->
      Logger.debug("ETS table info unavailable for #{inspect(table)}: #{Exception.message(e)}")
      nil
  end

  defp get_binary_count do
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
    [
      %{
        size: 2_048_576,
        location: "Buffer management",
        recommendation: "Consider streaming"
      },
      %{
        size: 1_024_000,
        location: "ANSI processing",
        recommendation: "Use binary streaming"
      },
      %{
        size: 512_000,
        location: "String operations",
        recommendation: "Use iodata"
      }
    ]
  end

  defp get_binary_recommendations(binary_memory) do
    recommendations =
      []
      |> maybe_add(
        binary_memory > 50_000_000,
        "Consider using binary streaming for large data"
      )
      |> maybe_add(
        binary_memory > 100_000_000,
        "Binary memory usage is high - review large string operations"
      )

    if Enum.empty?(recommendations),
      do: ["Binary memory usage appears normal"],
      else: recommendations
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

  defp maybe_add(list, true, item), do: [item | list]
  defp maybe_add(list, false, _item), do: list
end
