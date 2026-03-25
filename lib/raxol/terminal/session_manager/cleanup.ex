defmodule Raxol.Terminal.SessionManager.Cleanup do
  @moduledoc """
  Session cleanup: expired session removal and resource monitoring.
  """

  alias Raxol.Core.Runtime.Log

  @doc """
  Cleans up all resources associated with a session (terminals, clients).
  Returns updated state with clients removed.
  """
  def cleanup_session(session, state) do
    session.windows
    |> Enum.flat_map(& &1.panes)
    |> Enum.each(&stop_terminal_if_alive/1)

    updated_clients =
      Enum.reduce(session.clients, state.clients, fn client, acc ->
        Map.delete(acc, client.id)
      end)

    %{state | clients: updated_clients}
  end

  @doc """
  Removes expired sessions from state based on timeout configuration.
  """
  def cleanup_expired_sessions(state) do
    now = System.monotonic_time(:millisecond)
    timeout_ms = state.config.session_timeout_minutes * 60 * 1000

    {expired, active} =
      Enum.split_with(state.sessions, fn {_id, session} ->
        session.status == :detached and
          now - session.last_activity > timeout_ms
      end)

    do_cleanup_expired(expired, active, state)
  end

  @doc """
  Initializes the resource monitor configuration.
  """
  def init_resource_monitor(enabled) do
    %{
      enabled: enabled,
      # 1GB
      memory_limit: 1_000_000_000,
      # 80%
      cpu_limit: 80.0
    }
  end

  defp do_cleanup_expired([], _active, state), do: state

  defp do_cleanup_expired(expired, active, state) do
    Log.info("Cleaning up #{length(expired)} expired sessions")

    Enum.each(expired, fn {_id, session} ->
      cleanup_session(session, state)
    end)

    active_sessions = Map.new(active)
    %{state | sessions: active_sessions}
  end

  defp stop_terminal_if_alive(pane) do
    if Process.alive?(pane.terminal) do
      GenServer.stop(pane.terminal)
    else
      :ok
    end
  end
end
