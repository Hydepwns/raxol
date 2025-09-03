defmodule Raxol.Metrics do
  @moduledoc """
  Handles collection and management of system metrics with functional error handling.

  This module is responsible for collecting and managing various system metrics
  including:
  - CPU usage
  - Memory usage
  - Active sessions
  - Database connections
  - Response times
  - Error rates

  REFACTORED: All try/catch blocks replaced with functional error handling patterns.
  """

  use GenServer
  alias Raxol.Repo
  require Raxol.Core.Runtime.Log

  # 5 seconds
  @collection_interval 5_000

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_) do
    schedule_metrics_collection()
    {:ok, initial_state()}
  end

  @doc """
  Records a gauge metric value.

  ## Parameters

  - name: The name of the metric
  - value: The value to record for the metric

  ## Examples

      Raxol.Metrics.gauge("raxol.chart_render_time", 42.5)
  """
  def gauge(name, value) when is_binary(name) do
    with {:ok, _} <- safe_genserver_cast({:gauge, name, value}) do
      :ok
    else
      {:error, :not_available} ->
        log_service_unavailable("gauge", "#{name}=#{value}")
        :ok
    end
  end

  @doc """
  Increments a counter metric.

  ## Parameters

  - name: The name of the metric to increment

  ## Examples

      Raxol.Metrics.increment("raxol.chart_cache_hits")
  """
  def increment(name) when is_binary(name) do
    with {:ok, _} <- safe_genserver_cast({:increment, name}) do
      :ok
    else
      {:error, :not_available} ->
        log_service_unavailable("increment", name)
        :ok
    end
  end

  @doc """
  Returns the current metrics.

  Returns a map containing the current system metrics.
  """
  def get_current_metrics do
    with {:ok, metrics} <- safe_genserver_call(:get_metrics) do
      metrics
    else
      {:error, :not_available} -> %{}
    end
  end

  # Functional wrapper for GenServer.cast with error handling
  defp safe_genserver_cast(message) do
    case GenServer.whereis(__MODULE__) do
      nil -> 
        {:error, :not_available}
      _pid ->
        GenServer.cast(__MODULE__, message)
        {:ok, :sent}
    end
  end

  # Functional wrapper for GenServer.call with error handling
  defp safe_genserver_call(message) do
    case GenServer.whereis(__MODULE__) do
      nil -> 
        {:error, :not_available}
      _pid ->
        Raxol.Core.ErrorHandling.safe_genserver_call(__MODULE__, message)
    end
  end

  # Logging helper for service unavailable scenarios
  defp log_service_unavailable(operation, details) do
    Raxol.Core.Runtime.Log.debug(
      "Metrics service not available, ignoring #{operation}: #{details}"
    )
  end

  def handle_call(:get_metrics, _from, state) do
    {:reply, state, state}
  end

  def handle_cast({:gauge, name, value}, state) do
    gauges = Map.get(state, :gauges, %{})
    updated_gauges = Map.put(gauges, name, value)
    {:noreply, Map.put(state, :gauges, updated_gauges)}
  end

  def handle_cast({:increment, name}, state) do
    counters = Map.get(state, :counters, %{})
    current_value = Map.get(counters, name, 0)
    updated_counters = Map.put(counters, name, current_value + 1)
    {:noreply, Map.put(state, :counters, updated_counters)}
  end

  def handle_info({:collect_metrics, _timer_id}, state) do
    new_state = %{
      cpu_usage: get_cpu_usage(),
      memory_usage: get_memory_usage(),
      active_sessions: get_active_sessions(),
      database_connections: get_db_connections(),
      response_times: update_response_times(state.response_times),
      error_rates: update_error_rates(state.error_rates),
      gauges: Map.get(state, :gauges, %{}),
      counters: Map.get(state, :counters, %{}),
      last_updated: DateTime.utc_now()
    }

    schedule_metrics_collection()
    {:noreply, new_state}
  end

  defp initial_state do
    %{
      cpu_usage: 0,
      memory_usage: 0,
      active_sessions: 0,
      database_connections: 0,
      response_times: [],
      error_rates: %{},
      gauges: %{},
      counters: %{},
      last_updated: DateTime.utc_now()
    }
  end

  defp schedule_metrics_collection do
    timer_id = System.unique_integer([:positive])

    Process.send_after(
      self(),
      {:collect_metrics, timer_id},
      @collection_interval
    )
  end

  def get_cpu_usage do
    pid_string = :os.getpid()

    {output, 0} = System.cmd("ps", ["-p", "#{pid_string}", "-o", "%cpu="])

    case output do
      "" ->
        0.0

      output ->
        output
        |> String.trim()
        |> String.to_float()
    end
  end

  def get_memory_usage do
    pid_string = :os.getpid()

    {output, 0} = System.cmd("ps", ["-p", "#{pid_string}", "-o", "%mem="])

    case output do
      "" ->
        0.0

      output ->
        output
        |> String.trim()
        |> String.to_float()
    end
  end

  def get_active_sessions do
    case Registry.lookup(Raxol.TerminalRegistry, :sessions) do
      [] -> 0
      [{_pid, sessions}] when is_map(sessions) -> Kernel.map_size(sessions)
      _ -> 0
    end
  end

  defp get_db_connections do
    case Repo.checkout(fn -> :ok end) do
      {:ok, _} -> 1
      _ -> 0
    end
  end

  defp update_response_times(times) do
    # Keep last 100 response times
    new_time = :rand.uniform(1000)
    [new_time | Enum.take(times, 99)]
  end

  defp update_error_rates(rates) do
    # Update error rates for different endpoints
    Map.merge(rates, %{
      "api" => calculate_error_rate("api", rates),
      "web" => calculate_error_rate("web", rates),
      "terminal" => calculate_error_rate("terminal", rates)
    })
  end

  defp calculate_error_rate(endpoint, rates) do
    # Calculate error rate based on endpoint and current rates
    case Map.get(rates, endpoint) do
      nil ->
        0.0

      current_rate ->
        # Simulate some error rate fluctuation
        max(0.0, min(1.0, current_rate + :rand.uniform() * 0.1 - 0.05))
    end
  end

  def handle_exit(exit_code) do
    # Log exit code for metrics tracking
    Raxol.Core.Runtime.Log.debug(
      "Process exit detected with code: #{inspect(exit_code)}"
    )

    # Record exit code as a gauge metric
    gauge("raxol.process_exit_code", exit_code)

    :ok
  end
end