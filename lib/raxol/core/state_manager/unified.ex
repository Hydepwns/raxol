defmodule Raxol.Core.StateManager.Unified do
  @moduledoc """
  Unified state management facade providing a single interface for all state management needs.

  This module consolidates the various state management patterns used throughout Raxol:
  - Agent-based process state (for supervised state)
  - Functional map-based state (for simple transformations)
  - Domain-specific state managers (terminal, plugins, etc.)

  ## Usage

  ### For Process-Based State (Supervised)
      {:ok, manager} = StateManager.Unified.start_managed_state(:my_app_state, %{count: 0})
      StateManager.Unified.update_managed(:my_app_state, fn state -> %{state | count: state.count + 1} end)
      
  ### For Functional State (Simple)
      state = %{count: 0}
      {:ok, new_state} = StateManager.Unified.update_functional(state, :count, &(&1 + 1))
      
  ### For Domain-Specific State
      StateManager.Unified.register_domain(:terminal, Raxol.Terminal.StateManager)
      StateManager.Unified.delegate_to_domain(:terminal, :save_state, [emulator])
  """

  use GenServer
  require Raxol.Core.Runtime.Log

  # Client API - Managed State (Process-based with supervision)

  @doc """
  Starts a new managed state with supervision.
  This is the recommended approach for long-lived application state.
  """
  def start_managed_state(state_id, initial_state, opts \\ []) do
    case GenServer.start_link(__MODULE__, {state_id, initial_state}, opts) do
      {:ok, pid} ->
        Process.register(pid, state_name(state_id))
        {:ok, state_id}

      error ->
        error
    end
  end

  @impl GenServer
  def init({state_id, initial_state}) do
    init_genserver({state_id, initial_state})
  end

  @doc """
  Updates managed state using a function.
  """
  def update_managed(state_id, update_fun) when is_function(update_fun, 1) do
    case Process.whereis(state_name(state_id)) do
      nil -> {:error, :state_not_found}
      pid -> GenServer.call(pid, {:update, update_fun})
    end
  end

  @doc """
  Gets the current managed state.
  """
  def get_managed(state_id) do
    case Process.whereis(state_name(state_id)) do
      nil -> {:error, :state_not_found}
      pid -> GenServer.call(pid, :get)
    end
  end

  # Client API - Functional State (Map-based transformations)

  @doc """
  Updates functional state without process overhead.
  Use this for simple state transformations.
  """
  defdelegate update_functional(state, key, update_fun),
    to: Raxol.Core.StateManager.Default,
    as: :update

  @doc """
  Merges two functional states.
  """
  defdelegate merge_functional(state1, state2),
    to: Raxol.Core.StateManager.Default,
    as: :merge

  # Domain-Specific State Management

  @state_domains %{
    terminal: Raxol.Terminal.StateManager,
    plugins: Raxol.Core.Runtime.Plugins.StateManager,
    animation: Raxol.Animation.StateManager,
    core: Raxol.Core.StateManager
  }

  @doc """
  Delegates to domain-specific state manager.
  """
  def delegate_to_domain(domain, function, args) do
    case Map.get(@state_domains, domain) do
      nil -> {:error, {:unknown_domain, domain}}
      module -> apply(module, function, args)
    end
  end

  @doc """
  Lists all registered state domains.
  """
  def list_domains do
    Map.keys(@state_domains)
  end

  # Behaviour Implementation

  # Removed duplicate behaviour implementations - using GenServer callbacks only
  def put_state(old_state, new_state),
    do: Raxol.Core.StateManager.Default.put_state(old_state, new_state)

  def get(state, key), do: Raxol.Core.StateManager.Default.get(state, key)

  def get(state, key, default),
    do: Raxol.Core.StateManager.Default.get(state, key, default)

  def put(state, key, value),
    do: Raxol.Core.StateManager.Default.put(state, key, value)

  def update(state, key, func),
    do: Raxol.Core.StateManager.Default.update(state, key, func)

  def delete(state, key), do: Raxol.Core.StateManager.Default.delete(state, key)

  def clear(state), do: Raxol.Core.StateManager.Default.clear(state)

  def validate(state), do: Raxol.Core.StateManager.Default.validate(state)

  def merge(state1, state2),
    do: Raxol.Core.StateManager.Default.merge(state1, state2)

  # GenServer Implementation (for managed state)

  def init_genserver({state_id, initial_state}) do
    Raxol.Core.Runtime.Log.info("Starting managed state: #{state_id}")
    {:ok, %{id: state_id, state: initial_state}}
  end

  @impl GenServer
  def handle_call({:update, update_fun}, _from, %{state: state} = manager_state) do
    try do
      new_state = update_fun.(state)
      {:reply, {:ok, new_state}, %{manager_state | state: new_state}}
    catch
      kind, reason ->
        {:reply, {:error, {kind, reason}}, manager_state}
    end
  end

  @impl GenServer
  def handle_call(:get, _from, %{state: state} = manager_state) do
    {:reply, {:ok, state}, manager_state}
  end

  # Private Helpers

  defp state_name(state_id), do: :"raxol_managed_state_#{state_id}"
end
