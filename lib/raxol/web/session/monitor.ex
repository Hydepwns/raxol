defmodule Raxol.Web.Session.Monitor do
  @moduledoc """
  Handles session monitoring for Raxol applications.

  This module provides functionality to monitor active sessions, track usage
  patterns, and detect potential issues.
  """

  use GenServer

  alias Raxol.Web.Session.Storage
  alias Raxol.Cloud.Monitoring

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_session_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  def get_active_users do
    GenServer.call(__MODULE__, :get_active_users)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Initialize monitoring state
    state = %{
      stats: %{
        total_sessions: 0,
        active_sessions: 0,
        expired_sessions: 0,
        avg_session_duration: 0,
        peak_concurrent: 0
      },
      active_users: %{},
      monitoring_interval: :timer.minutes(1)
    }

    # Start monitoring timer
    schedule_monitoring(state)

    {:ok, state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    {:reply, state.stats, state}
  end

  @impl true
  def handle_call(:get_active_users, _from, state) do
    {:reply, state.active_users, state}
  end

  @impl true
  def handle_info(:monitor, state) do
    # Schedule next monitoring
    schedule_monitoring(state)

    # Get current sessions
    sessions = Storage.get_active_sessions()

    # Update stats
    stats = update_stats(state.stats, sessions)

    # Update active users
    active_users = update_active_users(sessions)

    # Report metrics
    report_metrics(stats)

    {:noreply, %{state | stats: stats, active_users: active_users}}
  end

  # Private functions

  defp update_stats(stats, sessions) do
    # Calculate session durations
    durations = Enum.map(sessions, fn session ->
      DateTime.diff(DateTime.utc_now(), session.created_at)
    end)

    # Update stats
    %{
      total_sessions: stats.total_sessions + length(sessions),
      active_sessions: length(sessions),
      expired_sessions: stats.expired_sessions,
      avg_session_duration: calculate_avg_duration(durations),
      peak_concurrent: max(stats.peak_concurrent, length(sessions))
    }
  end

  defp update_active_users(sessions) do
    # Group sessions by user
    sessions
    |> Enum.group_by(& &1.user_id)
    |> Map.new(fn {user_id, user_sessions} ->
      {user_id, %{
        session_count: length(user_sessions),
        last_active: Enum.max_by(user_sessions, & &1.last_active).last_active
      }}
    end)
  end

  defp calculate_avg_duration(durations) do
    if durations == [] do
      0
    else
      Enum.sum(durations) / length(durations)
    end
  end

  defp report_metrics(stats) do
    # Report session metrics
    Monitoring.record_metric("sessions.active", stats.active_sessions)
    Monitoring.record_metric("sessions.total", stats.total_sessions)
    Monitoring.record_metric("sessions.avg_duration", stats.avg_session_duration)
    Monitoring.record_metric("sessions.peak_concurrent", stats.peak_concurrent)
  end

  defp schedule_monitoring(state) do
    Process.send_after(self(), :monitor, state.monitoring_interval)
  end
end
