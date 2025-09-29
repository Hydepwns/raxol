defmodule Raxol.Core.Metrics.UnifiedCollector do
  @moduledoc """
  Manages unified metrics collection across the application.
  """

  use Raxol.Core.Behaviours.BaseManager


  defstruct [
    :metrics,
    :start_time,
    :last_update,
    :collectors
  ]

  @type t :: %__MODULE__{
          metrics: map(),
          start_time: integer(),
          last_update: integer(),
          collectors: map()
        }

  @history_limit 1000

  # --- Public API ---

  # BaseManager provides start_link/1 which handles GenServer initialization
  # Usage: Raxol.Core.Metrics.UnifiedCollector.start_link(name: __MODULE__, opts...)

  @doc """
  Records a metric value.
  """
  @spec record_metric(atom(), atom(), number(), keyword()) :: :ok
  def record_metric(name, type, value, opts \\ []) do
    GenServer.cast(__MODULE__, {:record_metric, name, type, value, opts})
  end

  @doc """
  Gets a metric value.
  """
  def get_metric(name, type, opts \\ []) do
    GenServer.call(__MODULE__, {:get_metric, name, type, opts})
  end

  @doc """
  Gets all metrics grouped by type.
  """
  def get_metrics do
    GenServer.call(__MODULE__, :get_all_metrics)
  end

  @doc """
  Gets all metrics (alias for get_metrics/0).
  """
  def get_all_metrics do
    GenServer.call(__MODULE__, :get_all_metrics)
  end

  @doc """
  Clears all metrics.
  """
  def clear_metrics do
    GenServer.cast(__MODULE__, :clear_metrics)
  end

  @doc """
  Clears all metrics (with optional parameter for compatibility).
  """
  def clear_metrics(_collector) do
    clear_metrics()
  end

  @doc """
  Gets metrics for a specific metric name and tags.
  """
  @spec get_metrics(String.t(), map()) :: {:ok, list(map())} | {:error, term()}
  def get_metrics(metric_name, tags) do
    GenServer.call(__MODULE__, {:get_metrics, metric_name, tags})
  end

  @doc """
  Gets metrics by type.
  """
  @spec get_metrics_by_type(atom()) :: map()
  def get_metrics_by_type(type) do
    GenServer.call(__MODULE__, {:get_metrics_by_type, type})
  end

  @doc """
  Records a performance metric.
  """
  @spec record_performance(atom(), number()) :: :ok
  def record_performance(name, value) do
    record_metric(name, :performance, value)
  end

  @doc """
  Records a performance metric with tags.
  """
  @spec record_performance(atom(), number(), keyword()) :: :ok
  def record_performance(name, value, opts) do
    record_metric(name, :performance, value, opts)
  end

  @doc """
  Records a resource metric.
  """
  @spec record_resource(atom(), number()) :: :ok
  def record_resource(name, value) do
    record_metric(name, :resource, value)
  end

  @doc """
  Records a resource metric with tags.
  """
  @spec record_resource(atom(), number(), keyword()) :: :ok
  def record_resource(name, value, opts) do
    record_metric(name, :resource, value, opts)
  end

  @doc """
  Records an operation metric.
  """
  @spec record_operation(atom(), number()) :: :ok
  def record_operation(name, value) do
    record_metric(name, :operation, value)
  end

  @doc """
  Records a custom metric.
  """
  @spec record_custom(String.t() | atom(), number()) :: :ok
  def record_custom(name, value) when is_binary(name) do
    # Store custom metrics with string keys to preserve original key format
    GenServer.cast(__MODULE__, {:record_custom_string, name, value})
  end

  def record_custom(name, value) when is_atom(name) do
    record_metric(name, :custom, value)
  end

  @doc """
  Stops the unified collector.
  """
  def stop(pid \\ __MODULE__) do
    GenServer.stop(pid)
  end

  # --- GenServer Callbacks ---

  @impl Raxol.Core.Behaviours.BaseManager
  def init_manager(opts) do
    state = %__MODULE__{
      metrics: %{},
      start_time: System.monotonic_time(),
      last_update: System.monotonic_time(),
      collectors: Keyword.get(opts, :collectors, %{})
    }

    # Start periodic system metrics collection
    _ =
      case Keyword.get(opts, :auto_collect_system_metrics, true) do
        true -> schedule_system_metrics_collection()
        false -> :ok
      end

    {:ok, state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_cast({:record_metric, name, type, value, opts}, state) do
    tags = Keyword.get(opts, :tags, [])
    timestamp = DateTime.utc_now()

    metric_entry = %{
      value: value,
      timestamp: timestamp,
      tags: tags
    }

    # Update metrics by type
    updated_metrics =
      Map.update(
        state.metrics,
        type,
        %{name => [metric_entry]},
        fn type_metrics ->
          Map.update(type_metrics, name, [metric_entry], fn existing_entries ->
            # Add new entry and limit history
            [metric_entry | existing_entries] |> Enum.take(@history_limit)
          end)
        end
      )

    {:noreply,
     %{state | metrics: updated_metrics, last_update: System.monotonic_time()}}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_cast(:clear_metrics, state) do
    {:noreply, %{state | metrics: %{}, last_update: System.monotonic_time()}}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_cast({:record_custom_string, name, value}, state)
      when is_binary(name) do
    timestamp = DateTime.utc_now()

    metric_entry = %{
      value: value,
      timestamp: timestamp,
      tags: []
    }

    # Update custom metrics with string keys preserved
    updated_metrics =
      Map.update(
        state.metrics,
        :custom,
        %{name => [metric_entry]},
        fn type_metrics ->
          Map.update(type_metrics, name, [metric_entry], fn existing_entries ->
            # Add new entry and limit history
            [metric_entry | existing_entries] |> Enum.take(@history_limit)
          end)
        end
      )

    {:noreply,
     %{state | metrics: updated_metrics, last_update: System.monotonic_time()}}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call({:get_metric, name, type, opts}, _from, state) do
    tags = Keyword.get(opts, :tags, [])
    type_metrics = Map.get(state.metrics, type, %{})
    metric_entries = Map.get(type_metrics, name, [])

    # Filter by tags if specified
    filtered_entries =
      case tags do
        [] -> metric_entries
        _ -> Enum.filter(metric_entries, fn entry -> entry.tags == tags end)
      end

    {:reply, filtered_entries, state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call(:get_all_metrics, _from, state) do
    {:reply, state.metrics, state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call({:get_metrics, metric_name, tags}, _from, state) do
    # Return all metrics matching the name and tags across all types
    result =
      state.metrics
      |> Enum.flat_map(fn {type, type_metrics} ->
        get_metrics_for_name_and_type(type_metrics, metric_name, type, tags)
      end)

    {:reply, {:ok, result}, state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call({:get_metrics_by_type, type}, _from, state) do
    # Return all metrics for the specified type
    type_metrics = Map.get(state.metrics, type, %{})
    {:reply, type_metrics, state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_info(:collect_system_metrics, state) do
    # Collect system metrics
    :ok = collect_system_metrics()

    # Schedule next collection
    _ref = schedule_system_metrics_collection()

    {:noreply, state}
  end

  # Private helper functions

  @spec get_metrics_for_name_and_type(any(), String.t() | atom(), any(), any()) ::
          any() | nil
  defp get_metrics_for_name_and_type(type_metrics, metric_name, type, tags) do
    case Map.get(type_metrics, metric_name) do
      nil -> []
      entries -> filter_and_map_entries(entries, type, tags)
    end
  end

  @spec filter_and_map_entries(any(), any(), any()) :: any()
  defp filter_and_map_entries(entries, type, tags) do
    filtered =
      case tags do
        %{} -> entries
        _ -> Enum.filter(entries, &(&1.tags == tags))
      end

    Enum.map(filtered, &Map.put(&1, :type, type))
  end

  defp schedule_system_metrics_collection do
    Process.send_after(self(), :collect_system_metrics, 100)
  end

  defp collect_system_metrics do
    # Process count
    process_count = Process.list() |> length()
    :ok = record_resource(:process_count, process_count)

    # Runtime ratio (simplified)
    {_, runtime} = :erlang.statistics(:runtime)
    runtime_ratio = runtime / 1000.0
    :ok = record_resource(:runtime_ratio, runtime_ratio)

    # GC stats (simplified)
    {gc_count, words_reclaimed, _} = :erlang.statistics(:garbage_collection)
    :ok = record_resource(:gc_count, gc_count)
    :ok = record_resource(:gc_words_reclaimed, words_reclaimed)

    :ok =
      record_resource(:gc_stats, %{
        count: gc_count,
        words_reclaimed: words_reclaimed
      })

    :ok
  end
end
