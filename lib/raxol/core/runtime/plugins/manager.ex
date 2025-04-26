defmodule Raxol.Core.Runtime.Plugins.Manager do
  @moduledoc """
  Manages the loading, initialization, and lifecycle of plugins in the Raxol runtime.

  This module is responsible for:
  - Discovering available plugins
  - Loading and initializing plugins
  - Managing plugin lifecycle events
  - Providing access to loaded plugins
  - Handling plugin dependencies and conflicts
  """

  alias Raxol.Core.Runtime.Events.Event
  alias Raxol.Core.Runtime.Plugins.LifecycleHelper
  alias Raxol.Core.Runtime.Plugins.CommandHelper

  @type plugin_id :: String.t()
  @type plugin_metadata :: map()
  @type plugin_state :: map()

  # State stored in the process
  defmodule State do
    @moduledoc false
    defstruct [
      # Map of plugin_id to plugin instance
      plugins: %{},
      # Map of plugin_id to plugin metadata
      metadata: %{},
      # Map of plugin_id to plugin state
      plugin_states: %{},
      # Map of plugin_id to source file path
      plugin_paths: %{},
      # List of plugin_ids in the order they were loaded
      load_order: [],
      # Whether the plugin system has been initialized
      initialized: false,
      # ETS table name for the command registry
      command_registry_table: nil,
      # Configuration for plugins, keyed by plugin_id
      plugin_config: %{},
      # Directory to discover plugins from
      plugins_dir: "priv/plugins" # Default value
    ]
  end

  use GenServer

  require Logger

  @doc """
  Starts the plugin manager process.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Initialize the plugin system and load all available plugins.
  """
  def initialize do
    GenServer.call(__MODULE__, :initialize)
  end

  @doc """
  Get a list of all loaded plugins with their metadata.
  """
  def list_plugins do
    GenServer.call(__MODULE__, :list_plugins)
  end

  @doc """
  Get a specific plugin by its ID.
  """
  def get_plugin(plugin_id) do
    GenServer.call(__MODULE__, {:get_plugin, plugin_id})
  end

  @doc """
  Enable a plugin that was previously disabled.
  """
  def enable_plugin(plugin_id) do
    GenServer.call(__MODULE__, {:enable_plugin, plugin_id})
  end

  @doc """
  Disable a plugin temporarily without unloading it.
  """
  def disable_plugin(plugin_id) do
    GenServer.call(__MODULE__, {:disable_plugin, plugin_id})
  end

  @doc """
  Reload a plugin by unloading and then loading it again.
  """
  def reload_plugin(plugin_id) do
    GenServer.call(__MODULE__, {:reload_plugin, plugin_id})
  end

  @doc """
  Load a plugin with a given configuration.
  """
  def load_plugin(plugin_id, config) do
    GenServer.call(__MODULE__, {:load_plugin, plugin_id, config})
  end

  # --- Event Filtering Hook ---

  @doc "Placeholder for allowing plugins to filter events."
  @spec filter_event(any(), Event.t()) :: {:ok, Event.t()} | :halt | any()
  def filter_event(_plugin_manager_state, event) do
    Logger.debug(
      "[#{__MODULE__}] filter_event called for: #{inspect(event.type)}"
    )

    # TODO: Implement logic to iterate through plugins and apply filters
    # Default: pass event through unchanged
    event
  end

  # --- GenServer Callbacks ---

  @impl true
  def handle_cast({:handle_command, command_name, data}, state) do
    Logger.info(
      "[#{__MODULE__}] Delegating command: #{inspect(command_name)} with data: #{inspect(data)}"
    )
    # Delegate command handling to CommandHelper
    case CommandHelper.handle_command(
           command_name,
           data,
           state.command_registry_table,
           state.plugins,
           state.plugin_states
         ) do
      {:ok, updated_plugin_states} ->
        # Update state if helper indicates success
        {:noreply, %{state | plugin_states: updated_plugin_states}}

      :not_found ->
        # Command wasn't found, state unchanged
        {:noreply, state}

      {:error, _reason} ->
        # Error occurred during handling, state unchanged (error already logged by helper)
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:send_clipboard_result, pid, content}, state) do
    send(pid, {:command_result, {:clipboard_content, content}})
    {:noreply, state}
  end

  @impl true
  def handle_info({:lifecycle_event, :shutdown}, state) do
    # Gracefully unload all plugins in reverse order using LifecycleHelper
    Enum.reduce(Enum.reverse(state.load_order), state, fn plugin_id, acc_state ->
      case LifecycleHelper.unload_plugin(
        plugin_id,
        acc_state.plugins,
        acc_state.metadata,
        acc_state.plugin_states,
        acc_state.load_order,
        acc_state.command_registry_table
      ) do
        {:ok, updated_maps} ->
          %{
            acc_state
            | plugins: updated_maps.plugins,
              metadata: updated_maps.metadata,
              plugin_states: updated_maps.plugin_states,
              load_order: updated_maps.load_order
          }
        {:error, _reason} ->
          # Log error? Keep state as is.
          Logger.error("[#{__MODULE__}] Failed to unload plugin #{plugin_id} during shutdown.")
          acc_state
      end
    end)

    {:noreply, %{state | initialized: false}} # Keep manager initialized state update
  end

  @impl true
  def init(opts) do
    # CommandRegistry.new() is likely just creating the ETS table name atom, keep it here
    cmd_reg_table = Raxol.Core.Runtime.Plugins.CommandRegistry.new()
    # Get config options
    initial_plugin_config = Keyword.get(opts, :plugin_config, %{})
    plugins_dir = Keyword.get(opts, :plugins_dir, "priv/plugins")

    # Subscribe to system shutdown event (TODO remains)
    # ...

    {:ok, %State{
      command_registry_table: cmd_reg_table,
      plugin_config: initial_plugin_config,
      plugins_dir: plugins_dir,
      plugin_paths: %{} # Initialize plugin_paths
    }}
  end

  @impl true
  def handle_call(:initialize, _from, %{initialized: true} = state) do
    {:reply, :already_initialized, state}
  end

  @impl true
  def handle_call(:initialize, _from, state) do
    Logger.info("[#{__MODULE__}] Initializing...")

    # Use new/0 instead of create_table/0
    command_table = Raxol.Core.Runtime.Plugins.CommandRegistry.new()

    # Delegate discovery, sorting, and loading loop to LifecycleHelper
    case LifecycleHelper.initialize_plugins(
           state.plugins, # Pass initial empty maps
           state.metadata,
           state.plugin_states,
           state.load_order,
           command_table, # Pass the newly created table
           state.plugin_config # Pass config loaded in init
         ) do
      {:ok, final_state_maps} ->
        # Update manager state with results from helper
        final_state = %{
          state
          | initialized: true,
            command_registry_table: command_table,
            plugins: final_state_maps.plugins,
            metadata: final_state_maps.metadata,
            plugin_states: final_state_maps.plugin_states,
            load_order: final_state_maps.load_order,
            plugin_config: final_state_maps.plugin_config,
            plugin_paths: final_state_maps.plugin_paths # Store the returned paths
        }
        {:reply, :ok, final_state}

      {:error, reason} ->
        # Error already logged by helper
        {:reply, {:error, reason}, state} # Return original state on error
    end
  end

  @impl true
  def handle_call(:list_plugins, _from, state) do
    # Return metadata for loaded plugins
    {:reply, Map.values(state.metadata), state}
  end

  @impl true
  def handle_call({:get_plugin, plugin_id}, _from, state) do
    plugin = Map.get(state.plugins, plugin_id)
    {:reply, plugin, state}
  end

  # --- Loading / Unloading / Reloading ---

  # Public API call: load_plugin/2 translates to load_plugin/3 via handle_call
  @impl true
  def handle_call({:load_plugin, plugin_id, config}, _from, state) do
    case LifecycleHelper.load_plugin(
           plugin_id,
           config,
           state.plugins,
           state.metadata,
           state.plugin_states,
           state.load_order,
           state.command_registry_table,
           state.plugin_config
         ) do
      {:ok, updated_maps} ->
        # Merge updated maps back into the state
        new_state = %{
          state
          | plugins: updated_maps.plugins,
            metadata: updated_maps.metadata,
            plugin_states: updated_maps.plugin_states,
            load_order: updated_maps.load_order,
            plugin_config: updated_maps.plugin_config
        }
        {:reply, :ok, new_state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  # Public API call: reload_plugin/1 via handle_call
  @impl true
  def handle_call({:reload_plugin, plugin_id}, _from, state) do
    if !state.initialized do
      {:reply, {:error, :not_initialized}, state}
    else
      Logger.info("[#{__MODULE__}] Reloading plugin: #{plugin_id}")
      case LifecycleHelper.reload_plugin_from_disk(
             plugin_id,
             state.plugins,
             state.metadata,
             state.plugin_states,
             state.load_order,
             state.command_registry_table,
             state.plugin_config,
             state.plugin_paths # Pass the paths map
           ) do
        {:ok, updated_maps} ->
          # Update the full state from the returned maps
          new_state = %{
            state
            | plugins: updated_maps.plugins,
              metadata: updated_maps.metadata,
              plugin_states: updated_maps.plugin_states,
              load_order: updated_maps.load_order,
              plugin_config: updated_maps.plugin_config,
              plugin_paths: updated_maps.plugin_paths
          }
          {:reply, :ok, new_state}

        {:error, reason} ->
          # Reload failed, log and return error, state remains unchanged from before the call
          Logger.error("Failed to reload plugin #{plugin_id}: #{inspect(reason)}")
          {:reply, {:error, reason}, state}
      end
    end
  end

  # --- Command Registration ---

  # REMOVED Unused helper function
  # defp find_plugin_for_command(command_table, command_name_str, namespace, _arity) do
  #   ...
  # end

  # --- Helper Functions ---

  # REMOVED Unused helper function
  # defp check_dependencies(_plugin_id, metadata, loaded_plugins) do
  #   ...
  # end
end
