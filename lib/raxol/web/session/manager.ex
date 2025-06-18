defmodule Raxol.Web.Session.Manager do
  @moduledoc '''
  Manages web sessions for Raxol applications.

  This module provides comprehensive session management capabilities:
  * Session storage and retrieval
  * Session recovery and cleanup
  * Session limits and monitoring
  * Session metadata management
  '''

  use GenServer

  alias Raxol.Web.Session.{Storage, Recovery, Cleanup, Monitor, Session}
  require Raxol.Core.Runtime.Log

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def create_session(user_id, metadata \\ %{}) do
    GenServer.call(__MODULE__, {:create_session, user_id, metadata})
  end

  def get_session(session_id) do
    GenServer.call(__MODULE__, {:get_session, session_id})
  end

  def update_session(session_id, metadata) do
    GenServer.call(__MODULE__, {:update_session, session_id, metadata})
  end

  def end_session(session_id) do
    GenServer.call(__MODULE__, {:end_session, session_id})
  end

  def cleanup_sessions do
    GenServer.call(__MODULE__, :cleanup_sessions)
  end

  def get_active_sessions do
    GenServer.call(__MODULE__, :get_active_sessions)
  end

  @impl true
  def init(_opts) do
    :ok = Storage.init()

    :ok = Recovery.init()

    :ok = Cleanup.init()

    {:ok, _monitor_state} = Monitor.init(%{})

    state = %{
      sessions: %{},
      cleanup_interval: :timer.minutes(5),
      max_sessions: 1000,
      session_timeout: :timer.hours(1)
    }

    # Start cleanup timer
    schedule_cleanup(state)

    {:ok, state}
  end

  @impl true
  def handle_call({:create_session, user_id, metadata}, _from, state) do
    session_id = generate_session_id()

    session = %Session{
      id: session_id,
      user_id: user_id,
      created_at: DateTime.utc_now(),
      last_active: DateTime.utc_now(),
      metadata: metadata,
      status: :active
    }

    # Store session
    case Storage.store(session) do
      {:ok, _} ->
        new_state = %{
          state
          | sessions: Map.put(state.sessions, session_id, session)
        }

        {:reply, {:ok, session}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:get_session, session_id}, _from, state) do
    case Storage.get(session_id) do
      {:ok, session} ->
        # Update last active time
        updated_session = %{session | last_active: DateTime.utc_now()}

        case Storage.store(updated_session) do
          {:ok, _} ->
            {:reply, {:ok, updated_session}, state}

          {:error, reason} ->
            Raxol.Core.Runtime.Log.error(
              "Failed to update session last_active time: #{inspect(reason)}"
            )

            {:reply, {:ok, session}, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:update_session, session_id, metadata}, _from, state) do
    case Storage.get(session_id) do
      {:ok, session} ->
        # Update session metadata
        updated_session = %{
          session
          | # Ensure metadata is a map
            metadata: Map.merge(session.metadata || %{}, metadata),
            last_active: DateTime.utc_now()
        }

        case Storage.store(updated_session) do
          {:ok, _} ->
            {:reply, {:ok, updated_session}, state}

          {:error, reason} ->
            Raxol.Core.Runtime.Log.error(
              "Failed to update session metadata: #{inspect(reason)}"
            )

            {:reply, {:error, reason}, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:end_session, session_id}, _from, state) do
    case Storage.get(session_id) do
      {:ok, session} ->
        ended_session = %{
          session
          | status: :ended,
            ended_at: DateTime.utc_now()
        }

        case Storage.store(ended_session) do
          {:ok, _} ->
            # Remove from active sessions
            new_state = %{
              state
              | sessions: Map.delete(state.sessions, session_id)
            }

            {:reply, :ok, new_state}

          {:error, reason} ->
            Raxol.Core.Runtime.Log.error(
              "Failed to mark session as ended: #{inspect(reason)}"
            )

            {:reply, {:error, reason}, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:cleanup_sessions, _from, state) do
    # Get expired sessions directly - Storage.get_expired_sessions/1 returns a list
    expired_sessions = Storage.get_expired_sessions(state.session_timeout)

    # End expired sessions
    Enum.each(expired_sessions, fn session ->
      ended_session = %{
        session
        | status: :expired,
          ended_at: DateTime.utc_now()
      }

      # Ignore result for cleanup
      _ = Storage.store(ended_session)
    end)

    # Remove from active sessions
    expired_ids = Enum.map(expired_sessions, & &1.id)
    new_sessions = Map.drop(state.sessions, expired_ids)

    {:reply, :ok, %{state | sessions: new_sessions}}
  end

  @impl true
  def handle_call(:get_active_sessions, _from, state) do
    {:reply, {:ok, state.sessions}, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    # Schedule next cleanup
    _cleanup_timer =
      Process.send_after(self(), :cleanup, state.cleanup_interval)

    # Perform cleanup
    {:reply, _status, new_state} = handle_call(:cleanup_sessions, self(), state)

    {:noreply, new_state}
  end

  # Private functions

  defp generate_session_id do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16(case: :lower)
  end

  defp schedule_cleanup(state) do
    Process.send_after(self(), :cleanup, state.cleanup_interval)
  end
end
