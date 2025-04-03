defmodule Raxol.Metrics do
  @moduledoc """
  Handles collection and management of system metrics.
  """

  use GenServer
  alias Raxol.Repo

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_) do
    schedule_metrics_collection()
    {:ok, %{
      cpu_usage: 0,
      memory_usage: 0,
      active_sessions: 0,
      database_connections: 0,
      response_times: [],
      error_rates: %{},
      last_updated: DateTime.utc_now()
    }}
  end

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

  defp schedule_metrics_collection do
    Process.send_after(self(), :collect_metrics, 5000)
  end

  defp get_cpu_usage do
    # Implement CPU usage collection
    :rand.uniform(100)
  end

  defp get_memory_usage do
    # Implement memory usage collection
    :rand.uniform(100)
  end

  defp get_active_sessions do
    # Get active sessions from session storage
    Raxol.Session.count_active_sessions()
  end

  defp get_db_connections do
    # Get database connection count
    Repo.checkout(fn -> :ok end)
    |> case do
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
    %{
      "api" => :rand.uniform(100) / 100,
      "web" => :rand.uniform(100) / 100,
      "terminal" => :rand.uniform(100) / 100
    }
  end
end 