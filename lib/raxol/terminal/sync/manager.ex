defmodule Raxol.Terminal.Sync.Manager do
  @moduledoc """
  Manages synchronization between different terminal components (splits, windows, tabs).
  Provides a high-level interface for component synchronization and state management.
  """

  use GenServer
  require Logger

  alias Raxol.Terminal.Sync.System

  # Types
  @type component_id :: String.t()
  @type component_type :: :split | :window | :tab
  @type sync_state :: %{
    component_id: component_id(),
    component_type: component_type(),
    state: term(),
    metadata: %{
      version: non_neg_integer(),
      timestamp: non_neg_integer(),
      source: String.t()
    }
  }

  # Client API
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def register_component(component_id, component_type, initial_state \\ %{}) do
    GenServer.call(__MODULE__, {:register_component, component_id, component_type, initial_state})
  end

  def unregister_component(component_id) do
    GenServer.call(__MODULE__, {:unregister_component, component_id})
  end

  def sync_state(component_id, state, opts \\ []) do
    GenServer.call(__MODULE__, {:sync_state, component_id, state, opts})
  end

  def get_state(component_id) do
    GenServer.call(__MODULE__, {:get_state, component_id})
  end

  def get_component_stats(component_id) do
    GenServer.call(__MODULE__, {:get_component_stats, component_id})
  end

  # Server Callbacks
  @impl true
  def init(opts) do
    state = %{
      components: %{},  # component_id => %{type: component_type, state: state}
      sync_system: System
    }
    {:ok, state}
  end

  @impl true
  def handle_call({:register_component, component_id, component_type, initial_state}, _from, state) do
    case Map.get(state.components, component_id) do
      nil ->
        new_state = %{state | components: Map.put(state.components, component_id, %{
          type: component_type,
          state: initial_state
        })}
        {:reply, :ok, new_state}
      _existing ->
        {:reply, {:error, :already_registered}, state}
    end
  end

  @impl true
  def handle_call({:unregister_component, component_id}, _from, state) do
    case Map.get(state.components, component_id) do
      nil ->
        {:reply, {:error, :not_found}, state}
      _component ->
        new_state = %{state | components: Map.delete(state.components, component_id)}
        System.clear(component_id)
        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:sync_state, component_id, new_state, opts}, _from, state) do
    case Map.get(state.components, component_id) do
      nil ->
        {:reply, {:error, :not_found}, state}
      component ->
        case do_sync_state(state, component_id, component.type, new_state, opts) do
          {:ok, updated_state} ->
            new_state = %{state | components: Map.put(state.components, component_id, %{
              component | state: updated_state
            })}
            {:reply, :ok, new_state}
          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  @impl true
  def handle_call({:get_state, component_id}, _from, state) do
    case Map.get(state.components, component_id) do
      nil -> {:reply, {:error, :not_found}, state}
      component -> {:reply, {:ok, component.state}, state}
    end
  end

  @impl true
  def handle_call({:get_component_stats, component_id}, _from, state) do
    case Map.get(state.components, component_id) do
      nil -> {:reply, {:error, :not_found}, state}
      _component -> {:reply, System.stats(component_id), state}
    end
  end

  # Private Functions
  defp do_sync_state(state, component_id, component_type, new_state, opts) do
    metadata = %{
      version: Kernel.System.monotonic_time(),
      timestamp: Kernel.System.system_time(),
      source: Map.get(opts, :source, "unknown")
    }

    case System.sync(component_id, "state", new_state, [
      consistency: get_consistency_level(component_type),
      metadata: metadata
    ]) do
      :ok -> {:ok, new_state}
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_consistency_level(:split), do: :strong
  defp get_consistency_level(:window), do: :strong
  defp get_consistency_level(:tab), do: :eventual
end
