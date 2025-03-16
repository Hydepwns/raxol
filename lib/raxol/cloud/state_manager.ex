defmodule Raxol.Cloud.StateManager do
  @moduledoc """
  Centralized state management for Raxol cloud components.
  
  This module provides a centralized way to store and retrieve state
  for all cloud components, eliminating the need for Process.put/2
  and Process.get/1 in multiple modules.
  """
  
  use GenServer
  
  # ===== Client API =====
  
  @doc """
  Starts the state manager.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, %{}, name: name)
  end
  
  @doc """
  Gets a value from the state.
  """
  def get(server \\ __MODULE__, key) do
    GenServer.call(server, {:get, key})
  end
  
  @doc """
  Puts a value in the state.
  """
  def put(server \\ __MODULE__, key, value) do
    GenServer.call(server, {:put, key, value})
  end
  
  @doc """
  Updates a value in the state.
  """
  def update(server \\ __MODULE__, key, fun) when is_function(fun, 1) do
    GenServer.call(server, {:update, key, fun})
  end
  
  @doc """
  Gets the entire state.
  """
  def get_all(server \\ __MODULE__) do
    GenServer.call(server, :get_all)
  end
  
  @doc """
  Clears the state.
  """
  def clear(server \\ __MODULE__) do
    GenServer.call(server, :clear)
  end
  
  # ===== Server Callbacks =====
  
  @impl GenServer
  def init(_) do
    {:ok, %{}}
  end
  
  @impl GenServer
  def handle_call({:get, key}, _from, state) do
    {:reply, Map.get(state, key), state}
  end
  
  @impl GenServer
  def handle_call({:put, key, value}, _from, state) do
    new_state = Map.put(state, key, value)
    {:reply, :ok, new_state}
  end
  
  @impl GenServer
  def handle_call({:update, key, fun}, _from, state) do
    current = Map.get(state, key)
    new_value = fun.(current)
    new_state = Map.put(state, key, new_value)
    {:reply, new_value, new_state}
  end
  
  @impl GenServer
  def handle_call(:get_all, _from, state) do
    {:reply, state, state}
  end
  
  @impl GenServer
  def handle_call(:clear, _from, _state) do
    {:reply, :ok, %{}}
  end
end 