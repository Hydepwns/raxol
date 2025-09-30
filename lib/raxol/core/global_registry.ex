defmodule Raxol.Core.GlobalRegistry do
  @moduledoc """
  Unified registry interface consolidating different registry patterns across Raxol.

  This module provides a single interface for:
  - Terminal session registry
  - Plugin registry
  - Component registry  
  - Theme/palette registry
  - Command registry

  ## Usage

  ### Terminal Sessions
      UnifiedRegistry.register(:sessions, session_id, session_data)
      sessions = UnifiedRegistry.list(:sessions)
      
  ### Plugins
      UnifiedRegistry.register(:plugins, plugin_id, plugin_metadata)
      plugins = UnifiedRegistry.list(:plugins)
      
  ### Commands
      UnifiedRegistry.register(:commands, command_name, command_handler)
      commands = UnifiedRegistry.search(:commands, pattern)
  """

  use Raxol.Core.Behaviours.BaseManager
  alias Raxol.Core.Runtime.Log
  @type registry_type ::
          :sessions | :plugins | :commands | :themes | :components
  @type entry_id :: String.t() | atom()
  @type entry_data :: any()

  defmodule RegistryBehaviour do
    @moduledoc """
    Behaviour for unified registry operations.
    """

    @type registry_type ::
            :sessions | :plugins | :commands | :themes | :components
    @type entry_id :: String.t() | atom()
    @type entry_data :: any()

    @callback register(registry_type(), entry_id(), entry_data()) ::
                :ok | {:error, term()}
    @callback unregister(registry_type(), entry_id()) :: :ok | {:error, term()}
    @callback lookup(registry_type(), entry_id()) ::
                {:ok, entry_data()} | {:error, :not_found}
    @callback list(registry_type()) :: [entry_data()]
    @callback count(registry_type()) :: non_neg_integer()
    @callback search(registry_type(), String.t()) :: [entry_data()]
  end

  @behaviour RegistryBehaviour

  defstruct [
    :sessions,
    :plugins,
    :commands,
    :themes,
    :components,
    :config
  ]

  # Client API

  @doc """
  Registers an entry in the specified registry.
  """
  @impl RegistryBehaviour
  def register(type, id, data) do
    GenServer.call(__MODULE__, {:register, type, id, data})
  end

  @doc """
  Unregisters an entry from the specified registry.
  """
  @impl RegistryBehaviour
  def unregister(type, id) do
    GenServer.call(__MODULE__, {:unregister, type, id})
  end

  @doc """
  Looks up an entry in the specified registry.
  """
  @impl RegistryBehaviour
  def lookup(type, id) do
    GenServer.call(__MODULE__, {:lookup, type, id})
  end

  @doc """
  Lists all entries in the specified registry.
  """
  @impl RegistryBehaviour
  def list(type) do
    GenServer.call(__MODULE__, {:list, type})
  end

  @doc """
  Counts entries in the specified registry.
  """
  @impl RegistryBehaviour
  def count(type) do
    GenServer.call(__MODULE__, {:count, type})
  end

  @doc """
  Searches for entries matching a pattern in the specified registry.
  """
  @impl RegistryBehaviour
  def search(type, pattern) do
    GenServer.call(__MODULE__, {:search, type, pattern})
  end

  @doc """
  Filters entries by a custom function.
  """
  def filter(type, filter_fn) when is_function(filter_fn, 1) do
    GenServer.call(__MODULE__, {:filter, type, filter_fn})
  end

  @doc """
  Gets registry statistics.
  """
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  @doc """
  Bulk operations for efficiency.
  """
  def bulk_register(type, entries) when is_list(entries) do
    GenServer.call(__MODULE__, {:bulk_register, type, entries})
  end

  def bulk_unregister(type, ids) when is_list(ids) do
    GenServer.call(__MODULE__, {:bulk_unregister, type, ids})
  end

  # Registry-specific convenience functions

  @doc """
  Session registry operations.
  """
  def register_session(session_id, session_data) do
    register(:sessions, session_id, session_data)
  end

  def unregister_session(session_id) do
    unregister(:sessions, session_id)
  end

  def lookup_session(session_id) do
    lookup(:sessions, session_id)
  end

  def list_sessions do
    list(:sessions)
  end

  @doc """
  Plugin registry operations.
  """
  def register_plugin(plugin_id, plugin_metadata) do
    register(:plugins, plugin_id, plugin_metadata)
  end

  def unregister_plugin(plugin_id) do
    unregister(:plugins, plugin_id)
  end

  def lookup_plugin(plugin_id) do
    lookup(:plugins, plugin_id)
  end

  def list_plugins do
    list(:plugins)
  end

  @doc """
  Command registry operations.
  """
  def register_command(command_name, command_handler) do
    register(:commands, command_name, command_handler)
  end

  def unregister_command(command_name) do
    unregister(:commands, command_name)
  end

  def lookup_command(command_name) do
    lookup(:commands, command_name)
  end

  def list_commands do
    list(:commands)
  end

  def search_commands(pattern) do
    search(:commands, pattern)
  end

  # GenServer Implementation

  @impl true
  def init_manager(opts) do
    config = Keyword.get(opts, :config, %{})

    state = %__MODULE__{
      sessions: %{},
      plugins: %{},
      commands: %{},
      themes: %{},
      components: %{},
      config: config
    }

    Log.module_info("Unified Registry started")
    {:ok, state}
  end

  @impl true
  def handle_manager_call({:register, type, id, data}, _from, state) do
    case get_registry(state, type) do
      {:ok, registry} ->
        updated_registry =
          Map.put(registry, id, %{
            id: id,
            data: data,
            registered_at: System.monotonic_time(:millisecond),
            metadata: %{}
          })

        new_state = put_registry(state, type, updated_registry)
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_manager_call({:unregister, type, id}, _from, state) do
    case get_registry(state, type) do
      {:ok, registry} ->
        updated_registry = Map.delete(registry, id)
        new_state = put_registry(state, type, updated_registry)
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_manager_call({:lookup, type, id}, _from, state) do
    case get_registry(state, type) do
      {:ok, registry} ->
        case Map.get(registry, id) do
          nil -> {:reply, {:error, :not_found}, state}
          entry -> {:reply, {:ok, entry.data}, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_manager_call({:list, type}, _from, state) do
    case get_registry(state, type) do
      {:ok, registry} ->
        entries = registry |> Map.values() |> Enum.map(& &1.data)
        {:reply, entries, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_manager_call({:count, type}, _from, state) do
    case get_registry(state, type) do
      {:ok, registry} ->
        {:reply, map_size(registry), state}

      {:error, _reason} ->
        {:reply, 0, state}
    end
  end

  @impl true
  def handle_manager_call({:search, type, pattern}, _from, state) do
    case get_registry(state, type) do
      {:ok, registry} ->
        regex = Regex.compile!(pattern, [:caseless])

        matching_entries =
          registry
          |> Map.values()
          |> Enum.filter(fn entry ->
            id_str = to_string(entry.id)
            Regex.match?(regex, id_str)
          end)
          |> Enum.map(& &1.data)

        {:reply, matching_entries, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_manager_call({:filter, type, filter_fn}, _from, state) do
    case get_registry(state, type) do
      {:ok, registry} ->
        matching_entries =
          registry
          |> Map.values()
          |> Enum.filter(fn entry -> filter_fn.(entry.data) end)
          |> Enum.map(& &1.data)

        {:reply, matching_entries, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_manager_call(:stats, _from, state) do
    stats = %{
      sessions: map_size(state.sessions),
      plugins: map_size(state.plugins),
      commands: map_size(state.commands),
      themes: map_size(state.themes),
      components: map_size(state.components),
      total_entries:
        map_size(state.sessions) + map_size(state.plugins) +
          map_size(state.commands) + map_size(state.themes) +
          map_size(state.components)
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_manager_call({:bulk_register, type, entries}, _from, state) do
    case get_registry(state, type) do
      {:ok, registry} ->
        now = System.monotonic_time(:millisecond)

        updated_registry =
          Enum.reduce(entries, registry, fn {id, data}, acc ->
            Map.put(acc, id, %{
              id: id,
              data: data,
              registered_at: now,
              metadata: %{}
            })
          end)

        new_state = put_registry(state, type, updated_registry)
        {:reply, {:ok, length(entries)}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_manager_call({:bulk_unregister, type, ids}, _from, state) do
    case get_registry(state, type) do
      {:ok, registry} ->
        updated_registry =
          Enum.reduce(ids, registry, fn id, acc ->
            Map.delete(acc, id)
          end)

        new_state = put_registry(state, type, updated_registry)
        {:reply, {:ok, length(ids)}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  # Private Helper Functions

  @spec get_registry(map(), any()) :: any() | nil
  defp get_registry(state, type) do
    case type do
      :sessions -> {:ok, state.sessions}
      :plugins -> {:ok, state.plugins}
      :commands -> {:ok, state.commands}
      :themes -> {:ok, state.themes}
      :components -> {:ok, state.components}
      _ -> {:error, :unknown_registry_type}
    end
  end

  @spec put_registry(map(), any(), any()) :: any()
  defp put_registry(state, type, registry) do
    case type do
      :sessions -> %{state | sessions: registry}
      :plugins -> %{state | plugins: registry}
      :commands -> %{state | commands: registry}
      :themes -> %{state | themes: registry}
      :components -> %{state | components: registry}
    end
  end
end
