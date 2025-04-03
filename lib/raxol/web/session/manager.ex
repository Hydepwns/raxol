defmodule Raxol.Web.Session.Manager do
  @moduledoc """
  Manages web sessions for Raxol applications.
  
  This module provides comprehensive session management capabilities:
  * Session storage and retrieval
  * Session recovery and cleanup
  * Session limits and monitoring
  * Session metadata management
  """

  use GenServer

  alias Raxol.Web.Session.{Storage, Recovery, Cleanup, Monitor}

  # Client API

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

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Initialize session storage
    :ok = Storage.init()
    
    # Initialize session recovery
    :ok = Recovery.init()
    
    # Initialize session cleanup
    :ok = Cleanup.init()
    
    # Initialize session monitoring
    :ok = Monitor.init()
    
    # Start cleanup timer
    schedule_cleanup()
    
    {:ok, %{
      sessions: %{},
      cleanup_interval: :timer.minutes(5),
      max_sessions: 1000,
      session_timeout: :timer.hours(1)
    }}
  end

  @impl true
  def handle_call({:create_session, user_id, metadata}, _from, state) do
    # Generate session ID
    session_id = generate_session_id()
    
    # Create session data
    session = %{
      id: session_id,
      user_id: user_id,
      created_at: DateTime.utc_now(),
      last_active: DateTime.utc_now(),
      metadata: metadata,
      status: :active
    }
    
    # Store session
    :ok = Storage.store(session)
    
    # Update state
    new_state = %{state | sessions: Map.put(state.sessions, session_id, session)}
    
    {:reply, {:ok, session}, new_state}
  end

  @impl true
  def handle_call({:get_session, session_id}, _from, state) do
    case Storage.get(session_id) do
      {:ok, session} ->
        # Update last active time
        session = %{session | last_active: DateTime.utc_now()}
        :ok = Storage.store(session)
        
        {:reply, {:ok, session}, state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:update_session, session_id, metadata}, _from, state) do
    case Storage.get(session_id) do
      {:ok, session} ->
        # Update session metadata
        session = %{session | 
          metadata: Map.merge(session.metadata, metadata),
          last_active: DateTime.utc_now()
        }
        
        :ok = Storage.store(session)
        
        {:reply, {:ok, session}, state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:end_session, session_id}, _from, state) do
    case Storage.get(session_id) do
      {:ok, session} ->
        # Mark session as ended
        session = %{session | status: :ended, ended_at: DateTime.utc_now()}
        :ok = Storage.store(session)
        
        # Remove from active sessions
        new_state = %{state | sessions: Map.delete(state.sessions, session_id)}
        
        {:reply, :ok, new_state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:cleanup_sessions, _from, state) do
    # Get expired sessions
    expired_sessions = Storage.get_expired_sessions(state.session_timeout)
    
    # End expired sessions
    for session <- expired_sessions do
      :ok = Storage.store(%{session | status: :expired, ended_at: DateTime.utc_now()})
    end
    
    # Remove from active sessions
    new_sessions = Map.drop(state.sessions, Enum.map(expired_sessions, & &1.id))
    
    {:reply, :ok, %{state | sessions: new_sessions}}
  end

  @impl true
  def handle_call(:get_active_sessions, _from, state) do
    {:reply, {:ok, state.sessions}, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    # Schedule next cleanup
    schedule_cleanup()
    
    # Perform cleanup
    {:ok, new_state} = handle_call(:cleanup_sessions, nil, state)
    
    {:noreply, new_state}
  end

  # Private functions

  defp generate_session_id do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16(case: :lower)
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, state.cleanup_interval)
  end
end 