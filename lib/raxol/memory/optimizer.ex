defmodule Raxol.Memory.Optimizer do
  @moduledoc """
  Memory optimization analysis and recommendations.

  Analyzes configuration, processes, binaries, ETS tables, and GC
  to produce actionable optimization suggestions.
  """

  alias Raxol.Memory.Collector

  @doc "Builds a full optimization analysis map."
  def run_optimization_analysis(config) do
    %{
      timestamp: DateTime.utc_now(),
      configuration_recommendations: analyze_configuration_optimizations(),
      process_optimizations: analyze_process_optimizations(config),
      binary_optimizations: analyze_binary_optimizations(),
      ets_optimizations: analyze_ets_optimizations(config),
      gc_optimizations: analyze_gc_optimizations(),
      general_recommendations: get_general_recommendations()
    }
  end

  # --- Private ---

  defp analyze_configuration_optimizations do
    vm_args = get_vm_args()

    recommendations =
      []
      |> maybe_add(
        should_recommend_heap_tuning(vm_args),
        "Consider tuning heap sizes for better memory efficiency"
      )
      |> maybe_add(
        should_recommend_gc_tuning(),
        "Consider adjusting garbage collection parameters"
      )

    %{current_config: vm_args, recommendations: recommendations}
  end

  defp get_vm_args do
    %{
      heap_size: :erlang.system_info(:heap_type),
      schedulers: :erlang.system_info(:schedulers),
      async_threads: :erlang.system_info(:thread_pool_size)
    }
  end

  defp should_recommend_heap_tuning(_vm_args) do
    memory = :erlang.memory()
    memory[:processes] > memory[:total] * 0.6
  end

  defp should_recommend_gc_tuning do
    {_gc_count, _words_reclaimed, _reductions} =
      :erlang.statistics(:garbage_collection)

    false
  end

  defp analyze_process_optimizations(_config) do
    long_queues = find_processes_with_long_queues()
    large_heaps = find_processes_with_large_heaps()

    %{
      long_message_queues: long_queues,
      large_heap_processes: large_heaps,
      recommendations:
        generate_process_recommendations(long_queues, large_heaps)
    }
  end

  defp find_processes_with_long_queues do
    Process.list()
    |> Enum.map(fn pid ->
      case Process.info(pid, [:message_queue_len, :registered_name]) do
        nil ->
          nil

        [message_queue_len: len, registered_name: name] when len > 1000 ->
          %{pid: pid, name: name, queue_length: len}

        _ ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp find_processes_with_large_heaps do
    Process.list()
    |> Enum.map(fn pid ->
      case Process.info(pid, [:heap_size, :registered_name]) do
        nil ->
          nil

        [heap_size: size, registered_name: name] when size > 100_000 ->
          %{pid: pid, name: name, heap_size: size}

        _ ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp generate_process_recommendations(long_queues, large_heaps) do
    recommendations =
      []
      |> maybe_add(
        length(long_queues) > 0,
        "Consider implementing backpressure for processes with long queues"
      )
      |> maybe_add(
        length(large_heaps) > 0,
        "Review processes with large heaps for memory optimization"
      )

    if Enum.empty?(recommendations),
      do: ["Process memory usage appears optimal"],
      else: recommendations
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
    tables = Collector.analyze_ets_tables(config)

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

  defp maybe_add(list, true, item), do: [item | list]
  defp maybe_add(list, false, _item), do: list
end
