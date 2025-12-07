defmodule Raxol.Terminal.Sync.Manager do
  @moduledoc """
  Manages synchronization between different terminal components (splits, windows, tabs).
  Provides a high-level interface for component synchronization and state management.
  """

  use Raxol.Core.Behaviours.BaseManager
  alias Raxol.Terminal.Sync.{System, Component}
  alias Raxol.Core.Runtime.Log

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

  # BaseManager provides start_link/1 which calls init_manager/1

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

  # BaseManager Callbacks
  @impl Raxol.Core.Behaviours.BaseManager
  def init_manager(opts) do
    state = %__MODULE__{
      components: %{},
      sync_id: generate_sync_id(opts)
    }

    {:ok, state}
  end

  @impl Raxol.Core.Behaviours.BaseManager
  def handle_manager_call(
        {:register_component, component_id, component_type, initial_state},
        _from,
        state
      ) do
    case Map.get(state.components, component_id) do
      nil ->
        now = Elixir.System.monotonic_time(:millisecond)

        component = %Component{
          id: component_id,
          type: component_type,
          state: initial_state,
          version: now,
          timestamp: System.system_time(:millisecond),
          metadata: %{},
          sync_count: 0,
          conflict_count: 0
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

  def handle_manager_call({:unregister_component, component_id}, _from, state) do
    case Map.get(state.components, component_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      _component ->
        new_state = %{
          state
          | components: Map.delete(state.components, component_id)
        }

        {:reply, :ok, new_state}
    end
  end

  def handle_manager_call(
        {:sync_state, component_id, component_type, new_state, opts},
        _from,
        state
      ) do
    case Map.get(state.components, component_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      existing_component ->
        case do_sync_state(
               state,
               component_id,
               component_type,
               new_state,
               opts,
               existing_component
             ) do
          {:ok, new_component} ->
            new_components =
              Map.put(state.components, component_id, new_component)

            {:reply, :ok, %{state | components: new_components}}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  def handle_manager_call(
        {:sync_state_simple, component_id, new_state},
        _from,
        state
      ) do
    case Map.get(state.components, component_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      existing_component ->
        case do_sync_state(
               state,
               component_id,
               existing_component.type,
               new_state,
               [],
               existing_component
             ) do
          {:ok, new_component} ->
            new_components =
              Map.put(state.components, component_id, new_component)

            {:reply, :ok, %{state | components: new_components}}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  def handle_manager_call({:get_state, component_id}, _from, state) do
    case Map.get(state.components, component_id) do
      nil -> {:reply, {:error, :not_found}, state}
      component -> {:reply, {:ok, component.state}, state}
    end
  end

  def handle_manager_call({:get_component_stats, component_id}, _from, state) do
    case Map.get(state.components, component_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      component ->
        # Return stats based on the component's internal state
        stats = %{
          sync_count: component.sync_count,
          conflict_count: component.conflict_count,
          last_sync: component.timestamp,
          consistency_levels: %{strong: 0, eventual: 0, causal: 0}
        }

        {:reply, {:ok, stats}, state}
    end
  end

  # Private Functions
  def generate_sync_id(_state) do
    timestamp = Elixir.System.monotonic_time(:millisecond)
    random = :rand.uniform(1_000_000)
    "#{timestamp}-#{random}"
  end

  def do_sync_state(
        _state,
        component_id,
        component_type,
        new_state,
        opts,
        existing_component
      ) do
    # Use version from new_state if present, otherwise increment existing_version
    existing_version = existing_component.version
    new_version = Map.get(new_state, :version, existing_version + 1)

    Log.debug(
      "[Manager] do_sync_state: component_id=#{component_id}, type=#{component_type}, new_version=#{inspect(new_version)}, existing_version=#{inspect(existing_version)}"
    )

    # Apply consistency rules based on component type
    case should_update_state(component_type, new_version, existing_version) do
      :update ->
        Log.debug("Updating state for #{component_id}")

        component = %Component{
          id: component_id,
          type: component_type,
          state: new_state,
          version: new_version,
          timestamp: System.system_time(:millisecond),
          metadata: Keyword.get(opts, :metadata, %{}),
          sync_count: existing_component.sync_count + 1,
          conflict_count: existing_component.conflict_count
        }

        {:ok, component}

      :keep_existing ->
        Log.debug("Keeping existing state for #{component_id}")
        {:ok, existing_component}

      :conflict ->
        Log.debug("Version conflict for #{component_id}")
        # Increment conflict count and keep existing state
        %Component{} = existing_component

        _component_with_conflict = %{
          existing_component
          | conflict_count: existing_component.conflict_count + 1
        }

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

  defp check_strong_consistency(new_version, existing_version)
       when new_version > existing_version,
       do: :update

  defp check_strong_consistency(_new_version, _existing_version),
    do: :keep_existing

  defp check_eventual_consistency(new_version, existing_version)
       when new_version > existing_version,
       do: :update

  defp check_eventual_consistency(new_version, existing_version)
       when new_version == existing_version,
       do: :conflict

  defp check_eventual_consistency(_new_version, _existing_version),
    do: :keep_existing
end
