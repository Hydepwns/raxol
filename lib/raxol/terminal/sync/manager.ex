defmodule Raxol.Terminal.Sync.Manager do
  @moduledoc """
  Manages synchronization between different terminal components (splits, windows, tabs).
  Provides a high-level interface for component synchronization and state management.
  """

  use GenServer
  require Logger

  alias Raxol.Terminal.Sync.{System, Component}

  defstruct [
    :components,
    :sync_id
  ]

  @type t :: %__MODULE__{
    components: %{String.t() => Component.t()},
    sync_id: String.t()
  }

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
  @doc """
  Starts the sync manager.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def register_component(component_id, component_type, initial_state \\ %{}) do
    GenServer.call(__MODULE__, {:register_component, component_id, component_type, initial_state})
  end

  def unregister_component(component_id) do
    GenServer.call(__MODULE__, {:unregister_component, component_id})
  end

  @doc """
  Syncs a component's state.
  """
  @spec sync_state(String.t(), String.t(), term(), keyword()) :: :ok
  def sync_state(component_id, component_type, new_state, opts \\ []) do
    GenServer.call(__MODULE__, {:sync_state, component_id, component_type, new_state, opts})
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
    state = %__MODULE__{
      components: %{},
      sync_id: generate_sync_id(opts)
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
  def handle_call({:sync_state, component_id, component_type, new_state, opts}, _from, state) do
    case do_sync_state(state, component_id, component_type, new_state, opts) do
      {:ok, new_component} ->
        new_components = Map.put(state.components, component_id, new_component)
        {:reply, :ok, %{state | components: new_components}}
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
  def generate_sync_id(_state) do
    timestamp = System.monotonic_time(:millisecond)
    random = :rand.uniform(1_000_000)
    "#{timestamp}-#{random}"
  end

  def do_sync_state(_state, component_id, component_type, new_state, opts) do
    component = %Component{
      id: component_id,
      type: component_type,
      state: new_state,
      version: System.monotonic_time(:millisecond),
      timestamp: System.system_time(:millisecond),
      metadata: Keyword.get(opts, :metadata, %{})
    }

    {:ok, component}
  end
end
