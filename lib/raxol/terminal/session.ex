defmodule Raxol.Terminal.Session do
  @moduledoc """
  Manages persistent terminal sessions.
  
  This module provides:
  - Session creation and retrieval
  - Session state persistence
  - Session cleanup
  - Session authentication
  - Session metadata management
  """

  use GenServer
  require Logger
  alias Raxol.Terminal.{Emulator, Input, Renderer}

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def create_session(user_id, opts \\ []) do
    GenServer.call(__MODULE__, {:create_session, user_id, opts})
  end

  def get_session(session_id) do
    GenServer.call(__MODULE__, {:get_session, session_id})
  end

  def update_session(session_id, state) do
    GenServer.call(__MODULE__, {:update_session, session_id, state})
  end

  def delete_session(session_id) do
    GenServer.call(__MODULE__, {:delete_session, session_id})
  end

  def list_sessions(user_id) do
    GenServer.call(__MODULE__, {:list_sessions, user_id})
  end

  def cleanup_old_sessions(max_age \\ 24 * 60 * 60) do
    GenServer.call(__MODULE__, {:cleanup_old_sessions, max_age})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    # Initialize ETS table for session storage
    :ets.new(:terminal_sessions, [:named_table, :set, :public])
    
    # Schedule periodic cleanup
    schedule_cleanup()
    
    {:ok, %{}}
  end

  @impl true
  def handle_call({:create_session, user_id, opts}, _from, state) do
    session_id = generate_session_id()
    emulator = Emulator.new(
      Keyword.get(opts, :width, 80),
      Keyword.get(opts, :height, 24)
    )
    input = Input.new()
    renderer = Renderer.new(emulator: emulator)
    
    session = %{
      id: session_id,
      user_id: user_id,
      emulator: emulator,
      input: input,
      renderer: renderer,
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now(),
      metadata: Keyword.get(opts, :metadata, %{})
    }
    
    :ets.insert(:terminal_sessions, {session_id, session})
    
    {:reply, {:ok, session}, state}
  end

  @impl true
  def handle_call({:get_session, session_id}, _from, state) do
    case :ets.lookup(:terminal_sessions, session_id) do
      [{^session_id, session}] ->
        # Update last accessed time
        updated_session = %{session | updated_at: DateTime.utc_now()}
        :ets.insert(:terminal_sessions, {session_id, updated_session})
        {:reply, {:ok, updated_session}, state}
      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:update_session, session_id, new_state}, _from, state) do
    case :ets.lookup(:terminal_sessions, session_id) do
      [{^session_id, session}] ->
        updated_session = %{session | 
          emulator: new_state.emulator,
          input: new_state.input,
          renderer: new_state.renderer,
          updated_at: DateTime.utc_now()
        }
        :ets.insert(:terminal_sessions, {session_id, updated_session})
        {:reply, {:ok, updated_session}, state}
      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:delete_session, session_id}, _from, state) do
    :ets.delete(:terminal_sessions, session_id)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:list_sessions, user_id}, _from, state) do
    sessions = :ets.match_object(:terminal_sessions, {:_, %{user_id: user_id}})
    {:reply, sessions, state}
  end

  @impl true
  def handle_call({:cleanup_old_sessions, max_age}, _from, state) do
    now = DateTime.utc_now()
    count = cleanup_sessions_before(now, max_age)
    {:reply, count, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    # Run cleanup every hour
    schedule_cleanup()
    cleanup_sessions_before(DateTime.utc_now(), 24 * 60 * 60)
    {:noreply, state}
  end

  # Private functions

  defp generate_session_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp schedule_cleanup do
    # Schedule cleanup every hour
    Process.send_after(self(), :cleanup, 60 * 60 * 1000)
  end

  defp cleanup_sessions_before(now, max_age) do
    cutoff = DateTime.add(now, -max_age, :second)
    
    :ets.select_delete(:terminal_sessions, [
      {{:_, %{updated_at: :"$1"}}, 
       [{:<, :"$1", cutoff}], 
       [true]}
    ])
  end
end 