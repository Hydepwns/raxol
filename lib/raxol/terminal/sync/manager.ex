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
    GenServer.call(
      __MODULE__,
      {:register_component, component_id, component_type, initial_state}
    )
  end

  def unregister_component(component_id) do
    GenServer.call(__MODULE__, {:unregister_component, component_id})
  end

  @doc """
  Syncs a component's state.
  """
  @spec sync_state(String.t(), String.t(), term(), keyword()) :: :ok
  def sync_state(component_id, component_type, new_state, opts \\ []) do
    GenServer.call(
      __MODULE__,
      {:sync_state, component_id, component_type, new_state, opts}
    )
  end

  @doc """
  Syncs a component's state with default options.
  """
  @spec sync_state(String.t(), term()) :: :ok
  def sync_state(component_id, new_state) do
    GenServer.call(__MODULE__, {:sync_state_simple, component_id, new_state})
  end

  def get_state(component_id) do
    GenServer.call(__MODULE__, {:get_state, component_id})
  end

  def get_component_stats(component_id) do
    GenServer.call(__MODULE__, {:get_component_stats, component_id})
  end

  # Server Callbacks
  def init(opts) do
    state = %__MODULE__{
      components: %{},
      sync_id: generate_sync_id(opts)
    }

    {:ok, state}
  end

  def handle_call(
        {:register_component, component_id, component_type, initial_state},
        _from,
        state
      ) do
    case Map.get(state.components, component_id) do
      nil ->
        now = System.monotonic_time(:millisecond)
        component = %Component{
          id: component_id,
          type: component_type,
          state: initial_state,
          version: now,
          timestamp: System.system_time(:millisecond),
          metadata: %{}
        }

        new_state = %{
          state
          | components: Map.put(state.components, component_id, component)
        }

        {:reply, :ok, new_state}

      _existing ->
        {:reply, {:error, :already_registered}, state}
    end
  end

  def handle_call({:unregister_component, component_id}, _from, state) do
    case Map.get(state.components, component_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      _component ->
        new_state = %{
          state
          | components: Map.delete(state.components, component_id)
        }

        System.clear(component_id)
        {:reply, :ok, new_state}
    end
  end

  def handle_call(
        {:sync_state, component_id, component_type, new_state, opts},
        _from,
        state
      ) do
    case Map.get(state.components, component_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      existing_component ->
        case do_sync_state(state, component_id, component_type, new_state, opts, existing_component) do
          {:ok, new_component} ->
            new_components = Map.put(state.components, component_id, new_component)
            {:reply, :ok, %{state | components: new_components}}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  def handle_call({:sync_state_simple, component_id, new_state}, _from, state) do
    case Map.get(state.components, component_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      existing_component ->
        case do_sync_state(state, component_id, existing_component.type, new_state, [], existing_component) do
          {:ok, new_component} ->
            new_components = Map.put(state.components, component_id, new_component)
            {:reply, :ok, %{state | components: new_components}}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  def handle_call({:get_state, component_id}, _from, state) do
    case Map.get(state.components, component_id) do
      nil -> {:reply, {:error, :not_found}, state}
      component -> {:reply, {:ok, component.state}, state}
    end
  end

  def handle_call({:get_component_stats, component_id}, _from, state) do
    case Map.get(state.components, component_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      _component ->
        case System.stats(component_id) do
          {:ok, stats} -> {:reply, {:ok, stats}, state}
          {:error, :not_found} ->
            # Return empty stats if System doesn't have stats for this component
            empty_stats = %{
              sync_count: 0,
              conflict_count: 0,
              last_sync: 0,
              consistency_levels: %{strong: 0, eventual: 0, causal: 0}
            }
            {:reply, {:ok, empty_stats}, state}
          {:error, reason} -> {:reply, {:error, reason}, state}
        end
    end
  end

  # Private Functions
  def generate_sync_id(_state) do
    timestamp = System.monotonic_time(:millisecond)
    random = :rand.uniform(1_000_000)
    "#{timestamp}-#{random}"
  end

  def do_sync_state(_state, component_id, component_type, new_state, opts, existing_component) do
    require Logger
    # Use version from new_state if present, otherwise increment existing_version
    existing_version = existing_component.version
    new_version = Map.get(new_state, :version, existing_version + 1)

    Logger.debug("[Manager] do_sync_state: component_id=#{component_id}, type=#{component_type}, new_version=#{inspect(new_version)}, existing_version=#{inspect(existing_version)}")

    # Apply consistency rules based on component type
    case should_update_state(component_type, new_version, existing_version) do
      :update ->
        # Sync with the System first
        case System.sync(component_id, "state", new_state, consistency: get_consistency_level(component_type), version: new_version) do
          :ok ->
            Logger.debug("[Manager] System.sync successful for #{component_id}")
            component = %Component{
              id: component_id,
              type: component_type,
              state: new_state,
              version: new_version,
              timestamp: System.system_time(:millisecond),
              metadata: Keyword.get(opts, :metadata, %{})
            }
            {:ok, component}

          {:error, :conflict} ->
            Logger.debug("[Manager] System.sync conflict for #{component_id}")
            {:error, :version_conflict}

          {:error, reason} ->
            Logger.debug("[Manager] System.sync error for #{component_id}: #{inspect(reason)}")
            {:error, reason}
        end

      :keep_existing ->
        Logger.debug("[Manager] Keeping existing state for #{component_id}")
        {:ok, existing_component}

      :conflict ->
        Logger.debug("[Manager] Version conflict for #{component_id}")
        {:error, :version_conflict}
    end
  end

  defp should_update_state(component_type, new_version, existing_version) do
    case component_type do
      :split -> check_strong_consistency(new_version, existing_version)
      :window -> check_strong_consistency(new_version, existing_version)
      :tab -> check_eventual_consistency(new_version, existing_version)
      _ -> check_strong_consistency(new_version, existing_version)
    end
  end

  defp check_strong_consistency(new_version, existing_version) do
    if new_version > existing_version, do: :update, else: :keep_existing
  end

  defp check_eventual_consistency(new_version, existing_version) do
    cond do
      new_version > existing_version -> :update
      new_version == existing_version -> :conflict
      true -> :keep_existing
    end
  end

  defp get_consistency_level(component_type) do
    case component_type do
      :split -> :strong
      :window -> :strong
      :tab -> :eventual
      _ -> :strong
    end
  end
end
