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

  alias Raxol.Core.Runtime.Events.Dispatcher
  alias Raxol.Core.Runtime.Events.Event
  # alias Raxol.Core.Runtime.Lifecycle # Unused
  # alias Raxol.Core.Runtime.Plugins.{API, Registry, Loader, CommandRegistry} # Unused CommandRegistry
  alias Raxol.Core.Runtime.Plugins.Loader
  # alias Raxol.Core.Runtime.Plugins.Registry, as: PluginRegistry # Unused
  # alias Raxol.Core.Runtime.Plugins.Loader, as: PluginLoader # Unused
  # alias Raxol.Core.Runtime.Plugins.CommandRegistry # Remove unused alias
  alias Raxol.Core.Runtime.Plugins.Plugin

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
      # List of plugin_ids in the order they were loaded
      load_order: [],
      # Whether the plugin system has been initialized
      initialized: false,
      # ETS table name for the command registry
      command_registry_table: nil,
      # Configuration for plugins, keyed by plugin_id
      plugin_config: %{}
    ]
  end

  use GenServer

  require Logger

  @default_plugins_dir "priv/plugins"

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
    Logger.debug("[#{__MODULE__}] filter_event called for: #{inspect(event.type)}")
    # TODO: Implement logic to iterate through plugins and apply filters
    event # Default: pass event through unchanged
  end

  # --- GenServer Callbacks ---

  @impl true
  def handle_cast({:handle_command, type, data}, state) do
    Logger.info(
      "[#{__MODULE__}] Received command: #{inspect(type)} with data: #{inspect(data)}"
    )

    # Example: Delegate clipboard command
    case type do
      :clipboard_read ->
        # Find plugin responsible for clipboard
        case find_plugin_for_command(:clipboard, :read, 1) do # Assuming arity 1 (pid)
          {:ok, plugin_id, _plugin_module} ->
            requesting_pid = data
            # Delegate to the plugin's handle_command
            # This needs refinement - how does the plugin know which function handles it?
            # And how does it send the result back?
            # For now, keeping the simulation
            Logger.debug("Delegating :clipboard_read to #{plugin_id}")
            # Simulate async operation
            Process.send_after(self(), {:send_clipboard_result, requesting_pid, "Plugin Content"}, 50)

          :not_found ->
            Logger.warning("No plugin found to handle command: :clipboard_read")
            # Potentially send an error back? TBD
        end

      :clipboard_write ->
        # Similar logic for write
        Logger.warning("Clipboard write delegation not fully implemented.")
        :ok

      _ ->
        Logger.warning("Unhandled command type: #{inspect(type)}")
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:send_clipboard_result, pid, content}, state) do
    send(pid, {:command_result, {:clipboard_content, content}})
    {:noreply, state}
  end

  @impl true
  def handle_info({:lifecycle_event, :shutdown}, state) do
    # Gracefully unload all plugins in reverse order
    Enum.reduce(Enum.reverse(state.load_order), state, fn plugin_id,
                                                          acc_state ->
      case unload_plugin(plugin_id, acc_state) do
        {:ok, new_state} -> new_state
        {:error, _} -> acc_state
      end
    end)

    {:noreply, %{state | initialized: false}}
  end

  @impl true
  def init(opts) do
    cmd_reg_table = CommandRegistry.new()
    plugin_config = Keyword.get(opts, :plugin_config, %{})
    # Subscribe to system shutdown event
    # TODO: Revisit Dispatcher subscription - might need adjustment
    # Raxol.Core.Runtime.Events.Dispatcher.subscribe(:shutdown, {__MODULE__, :handle_shutdown})

    {:ok, %State{command_registry_table: cmd_reg_table, plugin_config: plugin_config}}
  end

  @impl true
  def handle_call(:initialize, _from, %State{initialized: true} = state) do
    {:reply, {:error, :already_initialized}, state}
  end

  @impl true
  def handle_call(:initialize, _from, state) do
    # 1. Discover plugins
    case discover_plugins() do
      {:ok, plugins_with_metadata} ->
        # 2. Sort plugins by dependencies (simplified - no sorting for now)
        sorted_plugins = sort_plugins_by_dependencies(plugins_with_metadata)

        # 3. Load plugins in order
        {load_results, loaded_plugins_map, loaded_states_map} =
          load_plugins(sorted_plugins, state.command_registry_table, state.plugin_config)

        # 4. Store plugin information
        successful_plugin_ids = Map.keys(loaded_plugins_map)
        loaded_metadata_map =
          Map.new(plugins_with_metadata, fn {id, meta, _mod} -> {id, meta} end)
          |> Map.take(successful_plugin_ids)

        new_state = %State{
          state
          | plugins: loaded_plugins_map,
            metadata: loaded_metadata_map,
            plugin_states: loaded_states_map,
            # Ensure load_order only contains successfully loaded plugins
            load_order: Enum.map(sorted_plugins, fn {id, _, _} -> id end) |> Enum.filter(&(&1 in successful_plugin_ids)),
            initialized: true
        }

        # 5. Log results and broadcast event
        log_load_results(load_results)
        Dispatcher.broadcast(:plugin_system_initialized, %{
          plugins: Map.keys(loaded_plugins_map)
        })

        {:reply, {:ok, load_results}, new_state}

      {:error, reason} ->
        Logger.error("[#{__MODULE__}] Failed to discover plugins: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:list_plugins, _from, state) do
    result =
      Enum.map(state.load_order, fn plugin_id ->
        %{
          id: plugin_id,
          metadata: Map.get(state.metadata, plugin_id, %{}),
          enabled: plugin_enabled?(plugin_id, state)
        }
      end)

    {:reply, result, state}
  end

  @impl true
  def handle_call({:get_plugin, plugin_id}, _from, state) do
    case Map.fetch(state.plugins, plugin_id) do
      {:ok, plugin} ->
        plugin_data = %{
          plugin: plugin,
          metadata: Map.get(state.metadata, plugin_id, %{}),
          state: Map.get(state.plugin_states, plugin_id, %{}),
          enabled: plugin_enabled?(plugin_id, state)
        }

        {:reply, {:ok, plugin_data}, state}

      :error ->
        {:reply, {:error, :plugin_not_found}, state}
    end
  end

  @impl true
  def handle_call({:enable_plugin, plugin_id}, _from, state) do
    with {:ok, plugin} <- Map.fetch(state.plugins, plugin_id),
         plugin_state <- Map.get(state.plugin_states, plugin_id, %{}),
         # Check if plugin behaviour exists and function exported before calling
         true <- function_exported?(plugin, :enable, 1),
         {:ok, new_plugin_state} <- apply(plugin, :enable, [plugin_state]) do
      # Update plugin state and broadcast event
      new_states = Map.put(state.plugin_states, plugin_id, new_plugin_state)
      Dispatcher.broadcast(:plugin_enabled, %{plugin_id: plugin_id})

      {:reply, :ok, %{state | plugin_states: new_states}}
    else
      :error -> {:reply, {:error, :plugin_not_found}, state}
      false -> {:reply, {:error, :callback_not_implemented}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:disable_plugin, plugin_id}, _from, state) do
    with {:ok, plugin} <- Map.fetch(state.plugins, plugin_id),
         plugin_state <- Map.get(state.plugin_states, plugin_id, %{}),
         # Check if plugin behaviour exists and function exported before calling
         true <- function_exported?(plugin, :disable, 1),
         {:ok, new_plugin_state} <- apply(plugin, :disable, [plugin_state]) do
      # Update plugin state and broadcast event
      new_states = Map.put(state.plugin_states, plugin_id, new_plugin_state)
      Dispatcher.broadcast(:plugin_disabled, %{plugin_id: plugin_id})

      {:reply, :ok, %{state | plugin_states: new_states}}
    else
      :error -> {:reply, {:error, :plugin_not_found}, state}
      false -> {:reply, {:error, :callback_not_implemented}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:reload_plugin, plugin_id}, _from, state) do
    Logger.info("Reloading plugin: #{plugin_id}")

    case reload_plugin_from_disk(plugin_id, state) do
      {:error, :not_implemented} ->
        # Reloading from disk might not be implemented yet
        Logger.warning("Plugin reloading from disk not implemented for #{plugin_id}.")
        {:reply, {:error, :not_implemented}, state}

      {:error, reason} ->
        Logger.error("Failed to reload plugin #{plugin_id}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:load_plugin, plugin_id, config}, _from, state) do
    if Map.has_key?(state.plugins, plugin_id) do
      {:reply, {:error, :already_loaded}, state}
    else
      case Loader.load_plugin(plugin_id, config) do
        {:ok, loaded_module, metadata, loaded_config} ->
          init_opts = %{config: loaded_config, command_registry: state.command_registry_table}

          case apply(loaded_module, :init, [init_opts]) do
            {:ok, plugin_state} ->
              register_and_finalize_plugin(state, plugin_id, loaded_module, metadata, plugin_state, [])

            {:ok, plugin_state, commands_to_register} when is_list(commands_to_register) ->
              register_and_finalize_plugin(
                state,
                plugin_id,
                loaded_module,
                metadata,
                plugin_state,
                commands_to_register
              )

            {:error, reason} ->
              Logger.error("Plugin #{plugin_id} init failed: #{inspect(reason)}")
              {:reply, {:error, {:init_failed, reason}}, state}
          end

        {:error, reason} ->
          Logger.error("Plugin #{plugin_id} load failed: #{inspect(reason)}")
          {:reply, {:error, {:load_failed, reason}}, state}
      end
    end
  end

  @impl true
  def handle_call({:filter_event, event}, _from, state) do
    # Iterate through loaded plugins in reverse load order, allowing them to filter/modify the event.
    # Plugins loaded later can thus override earlier ones.
    # TODO: Consider defining a formal Plugin.Filterable behaviour for filter_event/2 contract.
    filtered_event = Enum.reduce(Enum.reverse(state.load_order), event, fn plugin_id, current_event ->
      # Stop processing if event is halted (nil)
      if is_nil(current_event) do
        nil # Event is halted, pass nil along
      else
        case Map.fetch(state.plugins, plugin_id) do
          {:ok, module} ->
            if function_exported?(module, :filter_event, 2) do
              plugin_state = Map.get(state.plugin_states, plugin_id, %{})
              # Call Plugin.filter_event(event, plugin_state)
              case apply(module, :filter_event, [current_event, plugin_state]) do
                {:ok, next_event} -> next_event
                :halt -> nil # Halt further processing
                other ->
                  Logger.warning(
                    "Plugin #{inspect(module)} filter_event returned invalid value: #{inspect(other)}. Ignoring filter."
                  )
                  current_event # Ignore invalid return
              end
            else
              current_event # Plugin doesn't implement filter_event/2
            end
          :error ->
            # Should not happen if state is consistent
            Logger.error("Plugin #{plugin_id} not found in state during event filtering.")
            current_event
        end
      end
    end)

    # Reply with the final event state (:halt becomes nil)
    reply_value = if is_nil(filtered_event), do: :halt, else: {:ok, filtered_event}
    {:reply, reply_value, state}
  end

  # Private functions

  @plugins_dir @default_plugins_dir

  @doc false
  defp discover_plugins do
    plugin_dir = Path.expand(@plugins_dir)
    Logger.info("[#{__MODULE__}] Discovering plugins in: #{plugin_dir}")

    unless File.exists?(plugin_dir) and File.dir?(plugin_dir) do
      Logger.warning("[#{__MODULE__}] Plugin directory not found: #{plugin_dir}. No plugins loaded.")
      {:ok, []}
    else
      plugin_files = Path.wildcard(Path.join(plugin_dir, "*.ex"))

      plugins_with_metadata =
        Enum.reduce(plugin_files, [], fn file, acc ->
          case Code.compile_file(file) do
            [{module, _binary} | _] ->
              # Ensure module is loaded for attribute reading
              Code.ensure_loaded(module)
              # Check for essential attributes and behaviour
              if Module.defines?(module, {:__info__, 1}) do
                behaviour = Module.get_attribute(module, :behaviour)
                plugin_id = Module.get_attribute(module, :plugin_id)
                metadata = Module.get_attribute(module, :plugin_metadata)

                if (behaviour == Plugin or (is_list(behaviour) and Plugin in behaviour)) and
                   plugin_id and metadata do
                   Logger.debug("Discovered plugin: #{plugin_id} (#{module}) from #{file}")
                   [{plugin_id, metadata || %{}, module} | acc]
                else
                  Logger.warning("Skipping invalid plugin file #{file}: Missing @plugin_id, @plugin_metadata, or @behaviour Plugin declaration.")
                  acc
                end
              else
                Logger.warning("Skipping invalid file #{file}: Not a valid module or cannot read attributes.")
                acc
              end
            err ->
              Logger.error("Error compiling plugin file #{file}: #{inspect(err)}")
              acc
          end
        end)

      {:ok, plugins_with_metadata}
    end
  rescue
    e -> {:error, {"Error during plugin discovery", e, __STACKTRACE__}}
  end

  @doc false
  defp sort_plugins_by_dependencies(plugins_with_metadata) do
    # TODO: Implement actual topological sort based on metadata[:dependencies]
    Logger.debug("Plugin dependency sorting not yet implemented. Loading in discovered order.")
    plugins_with_metadata # Return unsorted for now
  end

  @doc false
  defp load_plugins(sorted_plugins, command_registry_table, all_plugin_config) do
    Enum.reduce(sorted_plugins, {[], %{}, %{}}, fn {plugin_id, metadata, module}, {results, loaded_acc, states_acc} ->
      Logger.info("Loading plugin: #{plugin_id} (#{module})")
      plugin_config = Map.get(all_plugin_config, String.to_atom(plugin_id), %{}) # Use atom key for config lookup

      try do
        case module.init(plugin_config) do
          {:ok, initial_state} ->
            Logger.info("Plugin '#{plugin_id}' initialized successfully.")

            # Register commands
            register_plugin_commands(plugin_id, module, command_registry_table)

            new_results = [{:ok, plugin_id, metadata} | results]
            new_loaded = Map.put(loaded_acc, plugin_id, module)
            new_states = Map.put(states_acc, plugin_id, initial_state)
            {new_results, new_loaded, new_states}

          {:error, reason} ->
            Logger.error("Failed to initialize plugin '#{plugin_id}': #{inspect(reason)}")
            new_results = [{:error, plugin_id, :init_failed, reason} | results]
            {new_results, loaded_acc, states_acc}
        end
      rescue
        e ->
          Logger.error("Exception during plugin '#{plugin_id}' initialization: #{inspect(e)}")
          Logger.debug(Exception.format(:error, e, __STACKTRACE__))
          new_results = [{:error, plugin_id, :init_exception, e} | results]
          {new_results, loaded_acc, states_acc}
      end
    end)
  end

  defp register_plugin_commands(plugin_id, module, command_registry_table) do
    if function_exported?(module, :get_commands, 0) do
      try do
        commands = module.get_commands()
        Enum.each(commands, fn {namespace, command_name, function_name, arity} ->
          Logger.debug("Registering command [#{namespace}] #{command_name} -> #{module}.#{function_name}/#{arity}")
          CommandRegistry.register_command(
            command_registry_table,
            namespace,
            command_name,
            {module, function_name, arity}
          )
        end)
      rescue
        e -> Logger.error("Error getting commands from plugin '#{plugin_id}': #{inspect(e)}")
      end
    end
  end

  # Helper to log loading results
  defp log_load_results(results) do
    successful = Enum.filter(results, fn {status, _, _, _} -> status == :ok end)
    failed = Enum.filter(results, fn {status, _, _, _} -> status != :ok end)

    Logger.info("Plugin loading complete. #{length(successful)} succeeded, #{length(failed)} failed.")
    if Enum.any?(failed) do
      Enum.each(failed, fn {_, plugin_id, reason_code, details} ->
        Logger.error(" - Failed plugin: #{plugin_id}, Reason: #{reason_code}, Details: #{inspect(details)}")
      end)
    end
  end

  defp plugin_enabled?(plugin_id, state) do
    case Map.fetch(state.plugin_states, plugin_id) do
      {:ok, %{enabled: enabled}} -> enabled
      _ -> false
    end
  end

  # TODO: Implement command lookup based on registered commands
  defp find_plugin_for_command(_namespace, _command, _arity) do
    # Need to query CommandRegistry ETS table here
    Logger.warning("find_plugin_for_command not implemented")
    :not_found
  end

  defp unload_plugin(plugin_id, state) do
    with {:ok, plugin_module} <- Map.fetch(state.plugins, plugin_id),
         plugin_state <- Map.get(state.plugin_states, plugin_id, %{}) do
      # Unregister commands first
      Logger.debug("[#{__MODULE__}] Unregistering commands for #{inspect(plugin_module)}...")
      CommandRegistry.unregister_commands_by_module(state.command_registry_table, plugin_module)

      # Call plugin's unload callback
      Logger.debug("[#{__MODULE__}] Calling unload/1 for #{inspect(plugin_module)}...")
      _ = apply(plugin_module, :unload, [plugin_state])

      # Remove plugin from state
      new_state = %{
        state
        | plugins: Map.delete(state.plugins, plugin_id),
          metadata: Map.delete(state.metadata, plugin_id),
          plugin_states: Map.delete(state.plugin_states, plugin_id)
      }

      Dispatcher.broadcast(:plugin_unloaded, %{plugin_id: plugin_id})
      {:ok, new_state}
    else
      :error -> {:error, :plugin_not_found}
    end
  end

  # Helper to reload a plugin from disk (Placeholder)
  # TODO: Implement plugin reloading logic
  defp reload_plugin_from_disk(_plugin_id, _state) do
    Logger.warning("Plugin reloading from disk is not yet implemented.")
    {:error, :not_implemented}
  end

  defp register_and_finalize_plugin(state, plugin_id, loaded_module, metadata, plugin_state, commands_to_register) do
    register_commands(state.command_registry_table, loaded_module, commands_to_register)

    new_plugins = Map.put(state.plugins, plugin_id, loaded_module)
    new_states = Map.put(state.plugin_states, plugin_id, plugin_state)
    new_metadata = Map.put(state.metadata, plugin_id, metadata)
    new_load_order = state.load_order ++ [plugin_id]

    Dispatcher.broadcast(:plugin_loaded, %{plugin_id: plugin_id})

    {:reply, :ok,
     %{state | plugins: new_plugins, plugin_states: new_states, metadata: new_metadata, load_order: new_load_order}}
  end

  defp register_commands(table, module, commands) when is_list(commands) do
    Enum.each(commands, fn
      {name, function} when is_binary(name) and is_atom(function) ->
        CommandRegistry.register_command(table, name, module, function)
        # TODO: Define expected arity or pass it?
        # CommandRegistry.register_command(table, name, module, {function, arity})

      invalid_command ->
        Logger.warning(
          "[#{__MODULE__}] Invalid command format from #{inspect(module)}: #{inspect(invalid_command)}. Expected {name_binary, function_atom}. Skipping."
        )
    end)
  end
end
