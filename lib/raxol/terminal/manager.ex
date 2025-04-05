defmodule Raxol.Terminal.Manager do
  @moduledoc """
  Terminal manager module.
  
  This module manages terminal sessions, including:
  - Session creation
  - Session destruction
  - Session listing
  - Session monitoring
  """

  use GenServer

  alias Raxol.Terminal.{Session, Registry}

  @type t :: %__MODULE__{
    sessions: map()
  }

  defstruct [
    :sessions
  ]

  @doc """
  Starts the terminal manager.
  
  ## Examples
  
      iex> {:ok, pid} = Manager.start_link()
      iex> Process.alive?(pid)
      true
  """
  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Creates a new terminal session.
  
  ## Examples
  
      iex> {:ok, pid} = Manager.start_link()
      iex> {:ok, session_id} = Manager.create_session(pid, %{width: 80, height: 24})
      iex> is_binary(session_id)
      true
  """
  def create_session(pid \\ __MODULE__, opts \\ []) do
    GenServer.call(pid, {:create_session, opts})
  end

  @doc """
  Destroys a terminal session.
  
  ## Examples
  
      iex> {:ok, pid} = Manager.start_link()
      iex> {:ok, session_id} = Manager.create_session(pid)
      iex> :ok = Manager.destroy_session(pid, session_id)
      iex> Manager.get_session(pid, session_id)
      {:error, :not_found}
  """
  def destroy_session(pid \\ __MODULE__, session_id) do
    GenServer.call(pid, {:destroy_session, session_id})
  end

  @doc """
  Gets a terminal session by ID.
  
  ## Examples
  
      iex> {:ok, pid} = Manager.start_link()
      iex> {:ok, session_id} = Manager.create_session(pid)
      iex> {:ok, session} = Manager.get_session(pid, session_id)
      iex> session.id
      session_id
  """
  def get_session(pid \\ __MODULE__, session_id) do
    GenServer.call(pid, {:get_session, session_id})
  end

  @doc """
  Lists all terminal sessions.
  
  ## Examples
  
      iex> {:ok, pid} = Manager.start_link()
      iex> {:ok, session_id1} = Manager.create_session(pid)
      iex> {:ok, session_id2} = Manager.create_session(pid)
      iex> sessions = Manager.list_sessions(pid)
      iex> length(sessions)
      2
  """
  def list_sessions(pid \\ __MODULE__) do
    GenServer.call(pid, :list_sessions)
  end

  @doc """
  Gets the count of terminal sessions.
  
  ## Examples
  
      iex> {:ok, pid} = Manager.start_link()
      iex> {:ok, _} = Manager.create_session(pid)
      iex> {:ok, _} = Manager.create_session(pid)
      iex> Manager.count_sessions(pid)
      2
  """
  def count_sessions(pid \\ __MODULE__) do
    GenServer.call(pid, :count_sessions)
  end

  @doc """
  Monitors a terminal session.
  
  ## Examples
  
      iex> {:ok, pid} = Manager.start_link()
      iex> {:ok, session_id} = Manager.create_session(pid)
      iex> :ok = Manager.monitor_session(pid, session_id)
      iex> Process.whereis({:via, Registry, {Registry, session_id}})
      #PID<0.123.0>
  """
  def monitor_session(pid \\ __MODULE__, session_id) do
    GenServer.call(pid, {:monitor_session, session_id})
  end

  @doc """
  Unmonitors a terminal session.
  
  ## Examples
  
      iex> {:ok, pid} = Manager.start_link()
      iex> {:ok, session_id} = Manager.create_session(pid)
      iex> :ok = Manager.monitor_session(pid, session_id)
      iex> :ok = Manager.unmonitor_session(pid, session_id)
      iex> Process.whereis({:via, Registry, {Registry, session_id}})
      nil
  """
  def unmonitor_session(pid \\ __MODULE__, session_id) do
    GenServer.call(pid, {:unmonitor_session, session_id})
  end

  # Callbacks

  @impl true
  def init(_) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:create_session, opts}, _from, state) do
    case Session.start_link(opts) do
      {:ok, pid} ->
        session_id = UUID.uuid4()
        new_state = %{state | sessions: Map.put(state.sessions, session_id, pid)}
        {:reply, {:ok, session_id}, new_state}
      error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:destroy_session, session_id}, _from, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:reply, {:error, :not_found}, state}
      pid ->
        Session.stop(pid)
        new_state = %{state | sessions: Map.delete(state.sessions, session_id)}
        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:get_session, session_id}, _from, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:reply, {:error, :not_found}, state}
      pid ->
        session_state = Session.get_state(pid)
        {:reply, {:ok, session_state}, state}
    end
  end

  @impl true
  def handle_call(:list_sessions, _from, state) do
    sessions = state.sessions
    |> Enum.map(fn {id, pid} -> 
      {id, Session.get_state(pid)}
    end)
    |> Map.new()
    
    {:reply, sessions, state}
  end

  @impl true
  def handle_call(:count_sessions, _from, state) do
    {:reply, map_size(state.sessions), state}
  end

  @impl true
  def handle_call({:monitor_session, session_id}, _from, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:reply, {:error, :not_found}, state}
      pid ->
        Process.monitor(pid)
        {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call({:unmonitor_session, session_id}, _from, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        {:reply, {:error, :not_found}, state}
      pid ->
        Process.demonitor(pid)
        {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call({:get_state}, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:update_state, new_state}, _from, _state) do
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Remove the session from our state
    new_state = %{state | 
      sessions: state.sessions
      |> Enum.reject(fn {_id, p} -> p == pid end)
      |> Map.new()
    }
    
    {:noreply, new_state}
  end

  def get_state do
    GenServer.call(__MODULE__, {:get_state})
  end

  def update_state(new_state) do
    GenServer.call(__MODULE__, {:update_state, new_state})
  end
end 