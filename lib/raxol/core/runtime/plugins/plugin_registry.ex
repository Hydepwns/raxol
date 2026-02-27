defmodule Raxol.Core.Runtime.Plugins.PluginRegistry do
  @moduledoc """
  Pure functional plugin registry backed by ETS for fast concurrent lookups.

  Separates plugin registration/discovery from lifecycle management.
  All read operations are direct ETS lookups - no process serialization.

  ## Design

  Following Rich Hickey's principle of separating data from coordination:
  - Registry is data (what plugins exist, their metadata)
  - Lifecycle is coordination (loading, enabling, state management)

  ## Usage

      # Initialize registry (usually in application start)
      PluginRegistry.init()

      # Register a plugin
      PluginRegistry.register(:my_plugin, MyPlugin, %{version: "1.0"})

      # Fast lookups (direct ETS, no GenServer)
      PluginRegistry.get(:my_plugin)
      PluginRegistry.list()
      PluginRegistry.find_by_command(:help)

      # Check if registered
      PluginRegistry.registered?(:my_plugin)
  """

  require Logger

  @table_name :raxol_plugin_registry
  @commands_table :raxol_plugin_commands

  @type plugin_id :: atom() | String.t()
  @type plugin_module :: module()
  @type metadata :: map()

  @type plugin_entry :: %{
          id: plugin_id(),
          module: plugin_module(),
          metadata: metadata(),
          registered_at: DateTime.t()
        }

  # ============================================================================
  # Initialization
  # ============================================================================

  @doc """
  Initializes the plugin registry ETS tables.

  Call this once during application startup.
  """
  @spec init() :: :ok
  def init do
    # Main registry table
    _ =
      if :ets.whereis(@table_name) == :undefined do
        :ets.new(@table_name, [
          :named_table,
          :public,
          :set,
          read_concurrency: true
        ])
      end

    # Commands lookup table (command -> plugin_id)
    _ =
      if :ets.whereis(@commands_table) == :undefined do
        :ets.new(@commands_table, [
          :named_table,
          :public,
          :bag,
          read_concurrency: true
        ])
      end

    :ok
  end

  @doc """
  Checks if the registry has been initialized.
  """
  @spec initialized?() :: boolean()
  def initialized? do
    :ets.whereis(@table_name) != :undefined
  end

  # ============================================================================
  # Registration
  # ============================================================================

  @doc """
  Registers a plugin in the registry.

  ## Examples

      PluginRegistry.register(:clipboard, Raxol.Plugins.Clipboard, %{
        version: "1.0.0",
        description: "Clipboard integration"
      })
  """
  @spec register(plugin_id(), plugin_module(), metadata()) ::
          :ok | {:error, :already_registered}
  def register(plugin_id, module, metadata \\ %{}) do
    ensure_initialized!()

    entry = %{
      id: normalize_id(plugin_id),
      module: module,
      metadata: metadata,
      registered_at: DateTime.utc_now()
    }

    case :ets.insert_new(@table_name, {normalize_id(plugin_id), entry}) do
      true ->
        register_commands(plugin_id, module)
        :ok

      false ->
        {:error, :already_registered}
    end
  end

  @doc """
  Unregisters a plugin from the registry.
  """
  @spec unregister(plugin_id()) :: :ok
  def unregister(plugin_id) do
    ensure_initialized!()
    id = normalize_id(plugin_id)

    # Remove command mappings
    :ets.match_delete(@commands_table, {:_, id})

    # Remove from registry
    :ets.delete(@table_name, id)
    :ok
  end

  @doc """
  Updates a plugin's metadata.
  """
  @spec update_metadata(plugin_id(), metadata()) :: :ok | {:error, :not_found}
  def update_metadata(plugin_id, new_metadata) do
    ensure_initialized!()
    id = normalize_id(plugin_id)

    case :ets.lookup(@table_name, id) do
      [{^id, entry}] ->
        updated = %{entry | metadata: Map.merge(entry.metadata, new_metadata)}
        :ets.insert(@table_name, {id, updated})
        :ok

      [] ->
        {:error, :not_found}
    end
  end

  # ============================================================================
  # Lookups (Fast ETS reads)
  # ============================================================================

  @doc """
  Gets a plugin entry by ID. Direct ETS lookup.

  ## Examples

      case PluginRegistry.get(:clipboard) do
        {:ok, entry} -> entry.module
        :error -> nil
      end
  """
  @spec get(plugin_id()) :: {:ok, plugin_entry()} | :error
  def get(plugin_id) do
    ensure_initialized!()

    case :ets.lookup(@table_name, normalize_id(plugin_id)) do
      [{_id, entry}] -> {:ok, entry}
      [] -> :error
    end
  end

  @doc """
  Gets a plugin module by ID.
  """
  @spec get_module(plugin_id()) :: module() | nil
  def get_module(plugin_id) do
    case get(plugin_id) do
      {:ok, entry} -> entry.module
      :error -> nil
    end
  end

  @doc """
  Checks if a plugin is registered.
  """
  @spec registered?(plugin_id()) :: boolean()
  def registered?(plugin_id) do
    ensure_initialized!()
    :ets.member(@table_name, normalize_id(plugin_id))
  end

  @doc """
  Lists all registered plugins.

  ## Options

    * `:ids_only` - Return only plugin IDs (default: false)
  """
  @spec list(keyword()) :: [plugin_entry()] | [plugin_id()]
  def list(opts \\ []) do
    ensure_initialized!()

    entries =
      :ets.tab2list(@table_name)
      |> Enum.map(fn {_id, entry} -> entry end)
      |> Enum.sort_by(& &1.registered_at, DateTime)

    if Keyword.get(opts, :ids_only, false) do
      Enum.map(entries, & &1.id)
    else
      entries
    end
  end

  @doc """
  Returns the count of registered plugins.
  """
  @spec count() :: non_neg_integer()
  def count do
    ensure_initialized!()
    :ets.info(@table_name, :size)
  end

  # ============================================================================
  # Command Lookups
  # ============================================================================

  @doc """
  Finds plugins that provide a specific command.

  ## Examples

      PluginRegistry.find_by_command(:help)
      # => [:help_plugin, :docs_plugin]
  """
  @spec find_by_command(atom()) :: [plugin_id()]
  def find_by_command(command) when is_atom(command) do
    ensure_initialized!()

    :ets.lookup(@commands_table, command)
    |> Enum.map(fn {_cmd, plugin_id} -> plugin_id end)
  end

  @doc """
  Gets all commands provided by a plugin.
  """
  @spec get_commands(plugin_id()) :: [atom()]
  def get_commands(plugin_id) do
    ensure_initialized!()
    id = normalize_id(plugin_id)

    :ets.match(@commands_table, {:"$1", id})
    |> Enum.map(fn [cmd] -> cmd end)
  end

  @doc """
  Lists all registered commands with their provider plugins.
  """
  @spec list_commands() :: [{atom(), plugin_id()}]
  def list_commands do
    ensure_initialized!()

    :ets.tab2list(@commands_table)
    |> Enum.sort_by(fn {cmd, _} -> cmd end)
  end

  # ============================================================================
  # Filtering
  # ============================================================================

  @doc """
  Filters plugins by metadata criteria.

  ## Examples

      # Find all plugins with version "1.0"
      PluginRegistry.filter(fn entry ->
        entry.metadata[:version] == "1.0"
      end)
  """
  @spec filter((plugin_entry() -> boolean())) :: [plugin_entry()]
  def filter(predicate) when is_function(predicate, 1) do
    list()
    |> Enum.filter(predicate)
  end

  @doc """
  Finds plugins by metadata key-value match.

  ## Examples

      PluginRegistry.find_by_metadata(:category, :ui)
  """
  @spec find_by_metadata(atom(), term()) :: [plugin_entry()]
  def find_by_metadata(key, value) do
    filter(fn entry ->
      Map.get(entry.metadata, key) == value
    end)
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp ensure_initialized! do
    unless initialized?() do
      init()
    end
  end

  defp normalize_id(id) when is_atom(id), do: id
  defp normalize_id(id) when is_binary(id), do: String.to_atom(id)

  defp register_commands(plugin_id, module) do
    id = normalize_id(plugin_id)

    # Try to get commands from the plugin module
    commands =
      if function_exported?(module, :commands, 0) do
        try do
          module.commands()
        rescue
          e ->
            Logger.warning(
              "Failed to get commands from plugin #{module}: #{Exception.message(e)}"
            )

            []
        end
      else
        []
      end

    # Register each command
    Enum.each(commands, fn cmd ->
      :ets.insert(@commands_table, {cmd, id})
    end)
  end
end
