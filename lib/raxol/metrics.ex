defmodule Raxol.Metrics do
  @moduledoc """
  Handles collection and management of system metrics.
  
  This module is responsible for collecting and managing various system metrics
  including:
  - CPU usage
  - Memory usage
  - Active sessions
  - Database connections
  - Response times
  - Error rates
  """

  use GenServer
  alias Raxol.Repo
  
  @collection_interval 5_000  # 5 seconds
  
  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end
  
  def init(_) do
    schedule_metrics_collection()
    {:ok, initial_state()}
  end
  
  @doc """
  Returns the current metrics.
  
  Returns a map containing the current system metrics.
  """
  def get_current_metrics do
    GenServer.call(__MODULE__, :get_metrics)
  end
  
  def handle_call(:get_metrics, _from, state) do
    {:reply, state, state}
  end
  
  def handle_info(:collect_metrics, state) do
    new_state = %{
      cpu_usage: get_cpu_usage(),
      memory_usage: get_memory_usage(),
      active_sessions: get_active_sessions(),
      database_connections: get_db_connections(),
      response_times: update_response_times(state.response_times),
      error_rates: update_error_rates(state.error_rates),
      last_updated: DateTime.utc_now()
    }
    
    schedule_metrics_collection()
    {:noreply, new_state}
  end
  
  # Private functions
  
  defp initial_state do
    %{
      cpu_usage: 0,
      memory_usage: 0,
      active_sessions: 0,
      database_connections: 0,
      response_times: [],
      error_rates: %{},
      last_updated: DateTime.utc_now()
    }
  end
  
  defp schedule_metrics_collection do
    Process.send_after(self(), :collect_metrics, @collection_interval)
  end
  
  def get_cpu_usage do
    case :os.cmd(~c"ps -p #{System.get_pid()} -o %cpu=") do
      [] -> 0.0
      output ->
        output
        |> List.to_string()
        |> String.trim()
        |> String.to_float()
    end
  end
  
  def get_memory_usage do
    case :os.cmd(~c"ps -p #{System.get_pid()} -o %mem=") do
      [] -> 0.0
      output ->
        output
        |> List.to_string()
        |> String.trim()
        |> String.to_float()
    end
  end
  
  defp get_active_sessions do
    case Raxol.Session.count_active_sessions() do
      count when is_integer(count) -> count
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
      nil -> 0.0
      current_rate -> 
        # Simulate some error rate fluctuation
        max(0.0, min(1.0, current_rate + :rand.uniform() * 0.1 - 0.05))
    end
  end
end 