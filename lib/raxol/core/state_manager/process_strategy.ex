defmodule Raxol.Core.StateManager.ProcessStrategy do
  @moduledoc """
  Process-based state management strategy for StateManager.
  Each managed state ID corresponds to a named GenServer process.
  """

  use GenServer
  alias Raxol.Core.Runtime.Log

  # --- public API ---

  @doc "Starts a managed state GenServer for the given state_id."
  def start(state_id, initial_state, opts) do
    case GenServer.start_link(__MODULE__, {state_id, initial_state}, opts) do
      {:ok, pid} ->
        Process.register(pid, process_name(state_id))
        {:ok, state_id}

      error ->
        error
    end
  end

  @doc "Updates the managed state for state_id using an update function."
  def update(state_id, update_fun) do
    case Process.whereis(process_name(state_id)) do
      nil -> {:error, :state_not_found}
      pid -> GenServer.call(pid, {:update, update_fun})
    end
  end

  @doc "Gets the current state for state_id."
  def get(state_id) do
    case Process.whereis(process_name(state_id)) do
      nil -> {:error, :state_not_found}
      pid -> GenServer.call(pid, :get)
    end
  end

  @doc "Returns the registered process name for a state_id."
  def process_name(state_id), do: :"raxol_managed_state_#{state_id}"

  # --- GenServer callbacks ---

  @impl GenServer
  def init({state_id, initial_state}) do
    Log.info("Starting managed state: #{state_id}")
    {:ok, %{id: state_id, state: initial_state}}
  end

  @impl GenServer
  def handle_call({:update, update_fun}, _from, %{state: state} = manager_state) do
    new_state = update_fun.(state)
    {:reply, {:ok, new_state}, %{manager_state | state: new_state}}
  catch
    kind, reason ->
      {:reply, {:error, {kind, reason}}, manager_state}
  end

  @impl GenServer
  def handle_call(:get, _from, %{state: state} = manager_state) do
    {:reply, {:ok, state}, manager_state}
  end
end
