defmodule Raxol.Core.Metrics.UnifiedCollector do
  @moduledoc """
  Manages unified metrics collection across the application.
  """

  use GenServer

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

  # --- Public API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Records a metric value.
  """
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
  Gets all metrics.
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
  Gets metrics for a specific metric name and tags.
  """
  @spec get_metrics(String.t(), map()) :: {:ok, list(map())} | {:error, term()}
  def get_metrics(metric_name, tags) do
    GenServer.call(__MODULE__, {:get_metrics, metric_name, tags})
  end

  @doc """
  Gets all metrics without parameters.
  """
  @spec get_metrics() :: {:ok, list(map())} | {:error, term()}
  def get_metrics() do
    GenServer.call(__MODULE__, :get_all_metrics)
  end

  @doc """
  Gets metrics by type.
  """
  @spec get_metrics_by_type(atom()) :: {:ok, list(map())} | {:error, term()}
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
  @spec record_custom(String.t(), number()) :: :ok
  def record_custom(name, value) do
    record_metric(name, :custom, value)
  end

  # --- GenServer Callbacks ---

  @impl true
  def init(opts) do
    state = %__MODULE__{
      metrics: %{},
      start_time: System.monotonic_time(),
      last_update: System.monotonic_time(),
      collectors: Keyword.get(opts, :collectors, %{})
    }

    {:ok, state}
  end

  @impl true
  def handle_cast({:record_metric, name, type, value, opts}, state) do
    tags = Keyword.get(opts, :tags, %{})
    metric_key = {name, type, tags}

    metrics =
      Map.update(state.metrics, metric_key, [value], fn current ->
        [value | current]
      end)

    {:noreply,
     %{state | metrics: metrics, last_update: System.monotonic_time()}}
  end

  @impl true
  def handle_cast(:clear_metrics, state) do
    {:noreply, %{state | metrics: %{}, last_update: System.monotonic_time()}}
  end

  @impl true
  def handle_call({:get_metric, name, type, opts}, _from, state) do
    tags = Keyword.get(opts, :tags, %{})
    metric_key = {name, type, tags}
    {:reply, Map.get(state.metrics, metric_key), state}
  end

  @impl true
  def handle_call(:get_all_metrics, _from, state) do
    {:reply, state.metrics, state}
  end

  @impl true
  def handle_call({:get_metrics, metric_name, tags}, _from, state) do
    # Return all metrics matching the name and tags (type-agnostic)
    result =
      state.metrics
      |> Enum.filter(fn {{name, _type, metric_tags}, _values} ->
        name == metric_name and Map.equal?(metric_tags, tags)
      end)
      |> Enum.map(fn {key, values} ->
        %{key: key, values: Enum.reverse(values)}
      end)

    {:reply, {:ok, result}, state}
  end

  @impl true
  def handle_call({:get_metrics_by_type, type}, _from, state) do
    # Return all metrics matching the type
    result =
      state.metrics
      |> Enum.filter(fn {{_name, metric_type, _tags}, _values} ->
        metric_type == type
      end)
      |> Enum.map(fn {key, values} ->
        %{key: key, values: Enum.reverse(values)}
      end)

    {:reply, {:ok, result}, state}
  end
end
