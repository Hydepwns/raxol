defmodule Raxol.Core.Metrics.UnifiedCollector do
  @moduledoc """
  Unified metrics collector for the Raxol terminal emulator.

  This module serves as the central point for all metrics collection,
  supporting various metric types and providing a unified interface
  for metric recording and retrieval.
  """

  use GenServer
  alias Raxol.Core.Metrics.{Config, Cloud}
  require Logger

  @type metric_type :: :performance | :resource | :operation | :system | :custom
  @type metric_value :: number() | map()
  @type metric_tags :: [atom() | String.t()]

  # Client API

  @doc """
  Starts the metrics collector.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Records a performance metric.
  """
  def record_performance(name, value, tags \\ []) do
    GenServer.cast(__MODULE__, {:record, :performance, name, value, tags})
  end

  @doc """
  Records a resource metric.
  """
  def record_resource(name, value, tags \\ []) do
    GenServer.cast(__MODULE__, {:record, :resource, name, value, tags})
  end

  @doc """
  Records an operation metric.
  """
  def record_operation(name, value, tags \\ []) do
    GenServer.cast(__MODULE__, {:record, :operation, name, value, tags})
  end

  @doc """
  Records a system metric.
  """
  def record_system(name, value, tags \\ []) do
    GenServer.cast(__MODULE__, {:record, :system, name, value, tags})
  end

  @doc """
  Records a custom metric.
  """
  def record_custom(name, value, tags \\ []) do
    GenServer.cast(__MODULE__, {:record, :custom, name, value, tags})
  end

  @doc """
  Gets metrics for the specified type and name.
  """
  def get_metrics(type, name) do
    GenServer.call(__MODULE__, {:get_metrics, type, name})
  end

  @doc """
  Gets all metrics of the specified type.
  """
  def get_metrics_by_type(type) do
    GenServer.call(__MODULE__, {:get_metrics_by_type, type})
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    config = Config.default_config()
    state = %{
      metrics: %{},
      config: config,
      cloud_enabled: Keyword.get(opts, :cloud_enabled, false)
    }
    schedule_metrics_collection()
    {:ok, state}
  end

  @impl true
  def handle_cast({:record, type, name, value, tags}, state) do
    if type in state.config.enabled_metrics do
      new_metrics = update_metrics(state.metrics, type, name, value, tags)

      if state.cloud_enabled do
        send_to_cloud(type, name, value, tags)
      end

      {:noreply, %{state | metrics: new_metrics}}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_call({:get_metrics, type, name}, _from, state) do
    metrics = get_metrics_for_name(state.metrics, type, name)
    {:reply, metrics, state}
  end

  @impl true
  def handle_call({:get_metrics_by_type, type}, _from, state) do
    metrics = get_metrics_by_type(state.metrics, type)
    {:reply, metrics, state}
  end

  @impl true
  def handle_info(:collect_metrics, state) do
    new_state = collect_system_metrics(state)
    schedule_metrics_collection()
    {:noreply, new_state}
  end

  # Private Functions

  defp update_metrics(metrics, type, name, value, tags) do
    timestamp = System.system_time(:millisecond)
    metric_key = {type, name}
    metric = %{
      value: value,
      timestamp: timestamp,
      tags: tags
    }

    case metrics do
      %{^metric_key => existing_metrics} ->
        updated_metrics = [metric | existing_metrics]
        |> Enum.sort_by(& &1.timestamp, :desc)
        |> Enum.take(Config.get(:max_samples))
        Map.put(metrics, metric_key, updated_metrics)

      _ ->
        Map.put(metrics, metric_key, [metric])
    end
  end

  defp get_metrics_for_name(metrics, type, name) do
    case metrics do
      %{{^type, ^name} => metric_list} -> metric_list
      _ -> []
    end
  end

  defp get_metrics_by_type(metrics, type) do
    metrics
    |> Enum.filter(fn {{metric_type, _}, _} -> metric_type == type end)
    |> Map.new()
  end

  defp collect_system_metrics(state) do
    if :system in state.config.enabled_metrics do
      memory = :erlang.memory()
      process_count = :erlang.system_info(:process_count)
      runtime = :erlang.statistics(:runtime)
      gc_stats = :erlang.statistics(:garbage_collection)

      state
      |> record_system_metric(:memory, memory)
      |> record_system_metric(:process_count, process_count)
      |> record_system_metric(:runtime, runtime)
      |> record_system_metric(:gc_stats, gc_stats)
    else
      state
    end
  end

  defp record_system_metric(state, name, value) do
    new_metrics = update_metrics(state.metrics, :system, name, value, [])
    %{state | metrics: new_metrics}
  end

  defp schedule_metrics_collection do
    Process.send_after(self(), :collect_metrics, Config.get(:flush_interval))
  end

  defp send_to_cloud(type, name, value, tags) do
    if Process.whereis(Cloud) do
      send(Cloud, {:metrics, type, name, value, tags})
    end
  end
end
