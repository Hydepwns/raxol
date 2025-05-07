defmodule Raxol.Core.Runtime.Plugins.LifecycleHelper do
  @moduledoc """
  Handles plugin lifecycle operations (loading, unloading, reloading) for the Plugin Manager.
  """

  require Logger
  use Supervisor
  @behaviour Raxol.Core.Runtime.Plugins.LifecycleHelperBehaviour

  alias Raxol.Core.Runtime.Plugins.Loader
  # alias Raxol.Core.Runtime.Plugins.CommandRegistry # Unused
  alias Raxol.Core.Runtime.Plugins.Plugin
  alias Raxol.Core.Runtime.Plugins.CommandHelper

  # TODO: Move relevant functions from Manager here (e.g., load_plugin, unload_plugin, reload_plugin_from_disk, check_dependencies)
  # Functions will need to accept the relevant parts of the Manager's state as arguments
  # and return updated state fragments or status tuples.

  @default_plugins_dir "priv/plugins" # Need this here now

  # --- Loading / Unloading / Reloading ---

  @doc """
  Loads a plugin by its ID (string) or module (atom).

  Accepts the current plugin state maps and config, returns updated maps or an error.
  Returns `{:ok, %{plugins: map(), metadata: map(), plugin_states: map(), load_order: list(), plugin_config: map()}} | {:error, reason}`.
  """
  def load_plugin(plugin_id_or_module, config, plugins, metadata, plugin_states, load_order, command_table, plugin_config) do
    case plugin_id_or_module do
      plugin_id when is_binary(plugin_id) ->
        load_plugin_by_id(plugin_id, config, plugins, metadata, plugin_states, load_order, command_table, plugin_config)
      plugin_module when is_atom(plugin_module) ->
        load_plugin_by_module(plugin_module, config, plugins, metadata, plugin_states, load_order, command_table, plugin_config)
      _ ->
         {:error, :invalid_plugin_identifier}
    end
  end

  # Handles loading by ID (string) - typically during initial discovery
  defp load_plugin_by_id(plugin_id, config, plugins, metadata, plugin_states, load_order, command_table, plugin_config) do
    # 1. Load code (ensure module is available)
    case Loader.load_code(String.to_existing_atom("Elixir." <> plugin_id)) do # Assuming ID maps to Module name part
      :ok -> # Code loaded successfully
        # TODO: Derive module atom more reliably if needed, or pass it from discovery
        plugin_module = String.to_existing_atom("Elixir." <> plugin_id)

        # Proceed with the rest of the loading logic (metadata, dependencies, init, etc.)
        # (Copied from load_plugin_by_module, assuming module is now known)
        if Map.has_key?(plugins, plugin_id) do
            # Already loaded, skip
            {:error, :already_loaded}
        else
            # 2. Extract metadata
            plugin_metadata = Loader.extract_metadata(plugin_module)
            # Use extracted ID or fallback
            effective_plugin_id = Map.get(plugin_metadata, :id, plugin_id)

            # 3. Check dependencies
            case check_dependencies(effective_plugin_id, plugin_metadata, plugins) do
              :ok ->
                # 4. Check if it implements the Plugin behaviour
                if behaviour_implemented?(plugin_module, Plugin) do
                  # 5. Call plugin's init/1 callback
                  try do
                    case plugin_module.init(config) do
                    {:ok, plugin_init_state} ->
                      # 6. Register Commands using CommandHelper
                      CommandHelper.register_plugin_commands(
                      plugin_module,
                      plugin_init_state,
                      command_table
                      )

                      # 7. Update State Maps
                      new_plugins = Map.put(plugins, effective_plugin_id, plugin_module)
                      new_metadata = Map.put(metadata, effective_plugin_id, plugin_metadata)
                      new_plugin_states = Map.put(plugin_states, effective_plugin_id, plugin_init_state)
                      new_load_order = load_order ++ [effective_plugin_id]
                      new_plugin_config = Map.put(plugin_config, effective_plugin_id, config)

                      Logger.info("Successfully loaded plugin: #{effective_plugin_id} (#{inspect(plugin_module)})")
                      {:ok, %{
                      plugins: new_plugins,
                      metadata: new_metadata,
                      plugin_states: new_plugin_states,
                      load_order: new_load_order,
                      plugin_config: new_plugin_config
                      }}

                    {:error, reason} ->
                      Logger.error("Plugin #{effective_plugin_id} init/1 failed: #{inspect(reason)}")
                      {:error, {:init_failed, reason}}
                    end
                  rescue
                    error ->
                    Logger.error("Error during plugin init for #{effective_plugin_id}: #{inspect(error)}
                    Stacktrace: #{inspect(__STACKTRACE__)}")
                    {:error, {:init_exception, error}}
                  end
                else
                  Logger.error("Plugin #{plugin_module} does not implement the Plugin behaviour.")
                  {:error, :behaviour_not_implemented}
                end
              # Match specific dependency error tuple
              {:error, :missing_dependencies, missing} ->
                Logger.error("Plugin #{effective_plugin_id} missing dependencies: #{inspect missing}")
                {:error, :missing_dependencies, missing}
            end
        end

      {:error, :module_not_found} ->
        Logger.error("Failed to load plugin code for ID: #{plugin_id}")
        {:error, :module_not_found}
    end
  end

  # Handles loading when the module is already known (e.g., reloading)
  defp load_plugin_by_module(plugin_module, config, plugins, metadata, plugin_states, load_order, command_table, plugin_config) do
    Logger.debug("Attempting to load plugin module: #{inspect(plugin_module)}")
    # 1. Check if it's already loaded
    existing_id = find_plugin_id_by_module(plugins, plugin_module)
    if existing_id do
       Logger.warning("Plugin module #{inspect(plugin_module)} (ID: #{existing_id}) already loaded.")
       {:error, :already_loaded}
    else
      # 2. Extract metadata
      plugin_metadata = Loader.extract_metadata(plugin_module)
      plugin_id = Map.get(plugin_metadata, :id, Atom.to_string(plugin_module)) # Fallback ID

      # 3. Check dependencies
      case check_dependencies(plugin_id, plugin_metadata, plugins) do
        :ok ->
          # 4. Check if it implements the Plugin behaviour
          if behaviour_implemented?(plugin_module, Plugin) do
            # 5. Call plugin's init/1 callback
            try do
              case plugin_module.init(config) do
                {:ok, plugin_init_state} ->
                  # 6. Register Commands using CommandHelper
                  CommandHelper.register_plugin_commands(
                    plugin_module,
                    plugin_init_state,
                    command_table
                  )

                  # 7. Update State Maps
                  new_plugins = Map.put(plugins, plugin_id, plugin_module)
                  new_metadata = Map.put(metadata, plugin_id, plugin_metadata)
                  new_plugin_states = Map.put(plugin_states, plugin_id, plugin_init_state)
                  new_load_order = load_order ++ [plugin_id]
                  # Store config used for potential reload
                  new_plugin_config = Map.put(plugin_config, plugin_id, config)

                  Logger.info("Successfully loaded plugin: #{plugin_id} (#{inspect(plugin_module)})")
                  {:ok, %{
                    plugins: new_plugins,
                    metadata: new_metadata,
                    plugin_states: new_plugin_states,
                    load_order: new_load_order,
                    plugin_config: new_plugin_config
                   }}

                {:error, reason} ->
                  Logger.error("Plugin #{plugin_id} init/1 failed: #{inspect(reason)}")
                  {:error, {:init_failed, reason}}

                _ ->
                  Logger.error("Plugin #{plugin_id} init/1 returned invalid value.")
                  {:error, :invalid_init_return}
              end
            rescue
              error ->
                Logger.error("Exception during plugin #{plugin_id} init/1: #{inspect(error)}
                Stacktrace: #{inspect(__STACKTRACE__)}")
                {:error, {:init_exception, error}}
            end
          else
            Logger.error("Plugin #{plugin_id} (#{inspect(plugin_module)}) does not implement the Raxol.Core.Runtime.Plugins.Plugin behaviour.")
            {:error, :behaviour_not_implemented}
          end

        {:error, :missing_dependencies, missing} ->
           Logger.error("Plugin #{plugin_id} has unmet dependencies: #{inspect(missing)}")
           {:error, {:missing_dependencies, missing}} # Propagate the missing deps info
      end
    end
  end

  @doc """
  Unloads a plugin identified by its ID.

  Accepts the current plugin state maps, returns updated maps or an error.
  Returns `{:ok, %{plugins: map(), metadata: map(), plugin_states: map(), load_order: list()}} | {:error, reason}`.
  """
  def unload_plugin(plugin_id, plugins, metadata, plugin_states, load_order, command_table) do
    Logger.info("[LifecycleHelper] Unloading plugin: #{plugin_id}...")

    case Map.get(plugins, plugin_id) do
      nil ->
        {:error, :not_loaded}

      plugin_module ->
        # 1. Call terminate callback if implemented
        if function_exported?(plugin_module, :terminate, 2) do
          plugin_state = Map.get(plugin_states, plugin_id, %{})
          reason = :unload
          try do
            _ = plugin_module.terminate(reason, plugin_state)
          rescue
            error ->
              Logger.error("Error calling terminate/2 on #{plugin_module}: #{inspect(error)}
              Stacktrace: #{inspect(__STACKTRACE__)}")
          end
        end

        # 2. Unregister commands using CommandHelper
        CommandHelper.unregister_plugin_commands(command_table, plugin_module)

        # 3. Remove from state maps
        new_plugins = Map.delete(plugins, plugin_id)
        new_metadata = Map.delete(metadata, plugin_id)
        new_plugin_states = Map.delete(plugin_states, plugin_id)
        new_load_order = List.delete(load_order, plugin_id)

        {:ok, %{
           plugins: new_plugins,
           metadata: new_metadata,
           plugin_states: new_plugin_states,
           load_order: new_load_order
        }}
    end
  end

  @doc """
  Reloads a plugin identified by its ID.

  Handles unloading and then loading again, potentially with code reloading.
  Accepts the current plugin state maps and config, returns updated maps or an error.
  Requires the `plugin_paths` map to find the source file.
  Returns `{:ok, %{...updated_maps...}} | {:error, reason}`.
  """
  def reload_plugin_from_disk(plugin_id, plugins, metadata, plugin_states, load_order, command_table, plugin_config, plugin_paths) do
    Logger.info("[LifecycleHelper] Reloading plugin: #{plugin_id}...")

    original_config = Map.get(plugin_config, plugin_id, %{})
    original_module = Map.get(plugins, plugin_id) # Get module *before* unload

    # Check if source path exists before proceeding
    case Map.get(plugin_paths, plugin_id) do
      nil ->
        Logger.error("[LifecycleHelper] Cannot reload plugin #{plugin_id}: Source path not found.")
        {:error, :source_path_not_found}
      source_path -> # Path found, proceed with unload and reload
        case unload_plugin(plugin_id, plugins, metadata, plugin_states, load_order, command_table) do
          {:ok, unloaded_state_maps} ->
            # Pass the individual maps from the result tuple
            plugins_after_unload = unloaded_state_maps.plugins
            metadata_after_unload = unloaded_state_maps.metadata
            plugin_states_after_unload = unloaded_state_maps.plugin_states
            load_order_after_unload = unloaded_state_maps.load_order

            # Reloading Steps:
            if original_module do
              try do
                # 1. Purge old code
                Logger.debug("Purging old code for module: #{inspect original_module}")
                :ok = :code.purge(original_module)

                # 2. Recompile source file (Path is now known)
                Logger.debug("Attempting to recompile source: #{source_path}")
                case Code.compile_file(source_path) do
                  {:ok, ^original_module, _binary} ->
                    Logger.debug("Successfully recompiled: #{source_path}")

                    # 3. Ensure new code is loaded (optional, compile_file might load it)
                    :ok = Code.ensure_loaded(original_module)

                    # 4. Load the plugin again using the now-updated module definition
                    #    We need to pass the *original* full plugin_config and plugin_paths
                    #    because load_plugin_by_module updates them.
                    Logger.debug("Loading recompiled module: #{inspect original_module}")
                    case load_plugin_by_module(
                           original_module,
                           original_config,
                           plugins_after_unload,
                           metadata_after_unload,
                           plugin_states_after_unload,
                           load_order_after_unload,
                           command_table,
                           plugin_config # Pass original config map
                         ) do
                      {:ok, loaded_maps} ->
                        # 5. Add the source path back to the plugin_paths map
                        updated_paths = Map.put(plugin_paths, plugin_id, source_path)
                        {:ok, Map.put(loaded_maps, :plugin_paths, updated_paths)}
                      {:error, reason} ->
                        # Loading failed after successful compile
                        {:error, reason}
                      end

                  {:error, errors} ->
                     Logger.error("Failed to recompile plugin #{plugin_id} from #{source_path}: #{inspect errors}")
                     {:error, {:compilation_failed, errors}}
                end
              rescue
                error ->
                  Logger.error("Exception during plugin reload (purge/compile/load) for #{plugin_id}: #{inspect error}
                  Stacktrace: #{inspect(__STACKTRACE__)}")
                  {:error, {:reload_exception, error}}
              after
                # Ensure soft purge happens even if compilation/load fails
                :code.soft_purge(original_module)
              end
            else
              Logger.error("Cannot reload plugin #{plugin_id}: Original module not found (should have been caught by unload).")
              {:error, :original_module_not_found}
            end

          {:error, reason} ->
            Logger.error("Failed to unload plugin #{plugin_id} during reload: #{inspect(reason)}")
            {:error, {:unload_failed, reason}}
        end
    end
  end

  @doc """
  Discovers, sorts, and loads all plugins from the default directory.

  Accepts the initial Manager state maps and returns the updated maps (including `plugin_paths`) after loading,
  or an error tuple if discovery, sorting, or loading fails.

  Returns `{:ok, %{...updated_maps..., plugin_paths: map()}} | {:error, reason}`
  """
  def initialize_plugins(plugins, metadata, plugin_states, load_order, command_table, plugin_config) do
    discovered_plugins = Loader.discover_plugins(@default_plugins_dir)
    Logger.info("Discovered #{length(discovered_plugins)} potential plugin files.")

    # Extract metadata for all discovered plugins
    plugins_with_metadata_and_path = Enum.map(discovered_plugins, fn {module, path} ->
        meta = Loader.extract_metadata(module)
        {module, meta, path}
    end)

    # Prepare list for sorting: {module, metadata}
    plugins_for_sorting = Enum.map(plugins_with_metadata_and_path, fn {module, meta, _path} -> {module, meta} end)

    case sort_plugins(plugins_for_sorting) do
      {:ok, sorted_plugin_modules} ->
        Logger.info("Plugin dependency order determined.")

        # Create a map of module -> path for easy lookup during loading
        module_to_path_map = Enum.into(plugins_with_metadata_and_path, %{}, fn {mod, _meta, path} -> {mod, path} end)

        # Load plugins sequentially, updating state maps along the way
        initial_state = {:ok, %{
            plugins: plugins,
            metadata: metadata,
            plugin_states: plugin_states,
            load_order: load_order,
            plugin_config: plugin_config,
            plugin_paths: %{} # Initialize empty plugin_paths map
          }}

        Enum.reduce_while(sorted_plugin_modules, initial_state, fn plugin_module, {:ok, current_state_maps} ->

            # Extract the necessary maps for load_plugin_by_module
            current_plugins = current_state_maps.plugins
            current_metadata = current_state_maps.metadata
            current_plugin_states = current_state_maps.plugin_states
            current_load_order = current_state_maps.load_order
            current_plugin_config = current_state_maps.plugin_config
            # current_plugin_paths = current_state_maps.plugin_paths # Keep track of paths

            # Get the config for this plugin (defaults to empty map)
            # Need to extract metadata again briefly to get the ID for config lookup
            # Alternatively, pass the full {module, meta, path} list through sort?
            temp_meta = Loader.extract_metadata(plugin_module)
            plugin_id_for_config = Map.get(temp_meta, :id, Loader.module_to_default_id(plugin_module))
            config = Map.get(current_plugin_config, plugin_id_for_config, %{})

            case load_plugin_by_module(
                    plugin_module,
                    config,
                    current_plugins,
                    current_metadata,
                    current_plugin_states,
                    current_load_order,
                    command_table,
                    current_plugin_config
                  ) do
              {:ok, loaded_maps} ->
                 # Successfully loaded, find the effective plugin ID and store the path
                 effective_plugin_id = find_plugin_id_by_module(loaded_maps.plugins, plugin_module)
                 source_path = Map.get(module_to_path_map, plugin_module)

                 if effective_plugin_id && source_path do
                   updated_paths = Map.put(current_state_maps.plugin_paths, effective_plugin_id, source_path)
                   updated_full_maps = Map.merge(loaded_maps, %{plugin_paths: updated_paths})
                   {:cont, {:ok, updated_full_maps}} # Continue with updated maps including paths
                 else
                    Logger.error("Failed to associate source path for loaded plugin #{inspect plugin_module}. Skipping path storage.")
                    # Continue with loaded maps, but path won't be stored for reload
                    updated_full_maps_no_path = Map.merge(loaded_maps, %{plugin_paths: current_state_maps.plugin_paths})
                    {:cont, {:ok, updated_full_maps_no_path}}
                 end

              {:error, reason} ->
                Logger.error("Failed to load plugin #{inspect plugin_module}: #{inspect(reason)}. Skipping.")
                {:cont, {:ok, current_state_maps}} # Continue with previous maps
            end
        end)
        # Reduce/while returns the final accumulator state

      {:error, :circular_dependency} ->
        Logger.error("Failed to initialize plugins due to circular dependency.")
        {:error, :circular_dependency}

      # This clause might still be useful if sort_plugins could return other errors
      # {:error, reason} -> # Catch other potential sort errors if tsort is enhanced
      #   Logger.error("Failed to sort plugins for initialization: #{inspect(reason)}")
      #   {:error, :dependency_resolution_failed}
    end
  end

  # --- Helper Functions ---

  @doc """
  Loads plugin configuration (placeholder).
  """
  def load_plugin_config() do
    # Placeholder: Load from Mix config or other source
    Logger.debug("Loading plugin configuration (placeholder)...")
    Application.get_env(:raxol, :plugins, %{})
  end

  @doc """
  Checks if all dependencies for a plugin are met by the currently loaded plugins.
  Returns `:ok` or `{:error, :missing_dependencies, missing_list}`.
  """
  def check_dependencies(plugin_id, metadata, loaded_plugins_map) do
     required = Map.get(metadata, :dependencies, [])
     # Use Map.keys as loaded_plugins_map contains id => module
     available = Map.keys(loaded_plugins_map)
     missing = Enum.reject(required, fn dep_id -> Enum.member?(available, dep_id) end)

     if Enum.empty?(missing) do
       :ok
     else
       Logger.debug("Plugin #{plugin_id} missing dependencies: #{inspect missing}")
       {:error, :missing_dependencies, missing}
     end
  end

  # --- Dependency Management ---

  @doc """
  Sorts a list of plugin modules based on their declared dependencies.

  Accepts a list of `{plugin_module, plugin_metadata}` tuples.
  Returns `{:ok, sorted_plugin_modules}` or `{:error, :circular_dependency, cycle}`.
  Uses a topological sort algorithm.
  """
  def sort_plugins(plugins_with_metadata) do
    Logger.debug("[LifecycleHelper] Sorting plugins by dependency...")

    # Build the dependency graph {plugin_id => [dep_id, ...]}
    graph = Enum.reduce(plugins_with_metadata, %{}, fn {_, meta}, acc ->
      plugin_id = Map.get(meta, :id)
      dependencies = Map.get(meta, :dependencies, [])
      Map.put(acc, plugin_id, dependencies)
    end)

    # Perform topological sort - Handles {:ok, list} | {:error, :circular_dependency}
    case tsort(graph) do
      {:ok, sorted_ids} ->
         # Map sorted IDs back to modules
        id_to_module_map = Enum.into(plugins_with_metadata, %{}, fn {mod, meta} -> {Map.get(meta, :id), mod} end)
        sorted_modules = Enum.map(sorted_ids, &Map.get(id_to_module_map, &1))
        Logger.debug("[LifecycleHelper] Plugin sort order: #{inspect(sorted_ids)}")
        {:ok, sorted_modules}

      {:error, :circular_dependency} ->
         Logger.error("[LifecycleHelper] Circular dependency detected during plugin sort.")
        # Pass the error up
        {:error, :circular_dependency}
      # Note: No need for a generic error case here unless tsort can return other errors
    end
  end

  # --- Helpers ---

  # Helper to check if a module implements a behaviour
  defp behaviour_implemented?(module, behaviour) do
    # TODO: Add more specific logic to handle various cases
    # This is a simplified check for Plugin behaviour only.
    function_exported?(module, :behaviour_info, 1) and
      # Also check required callbacks are present
      Enum.all?(behaviour.behaviour_info(:callbacks), fn {name, arity} ->
        function_exported?(module, name, arity)
      end)
  end

  # Helper to find a plugin ID given its module - Make public for CommandHelper
  def find_plugin_id_by_module(plugins, module) do
     Enum.find_value(plugins, nil, fn {id, mod} ->
      if mod == module, do: id, else: nil
    end)
  end

  # Topological Sort Implementation (using a hypothetical Tsort module or algorithm)
  # Replace this with an actual implementation or library.
  # Example structure based on common topological sort algorithms.
  defp tsort(graph) do
    # Placeholder: In a real scenario, use a library like :tsort or implement Kahn's algorithm or DFS-based sort.
    # This example assumes `Tsort.tsort/1` exists and raises `Tsort.Error` on cycles.
    # Example using a hypothetical library:
    # Tsort.tsort(graph)

    # Manual Implementation Example (Kahn's Algorithm):
    nodes = Map.keys(graph)
    node_count = length(nodes)
    in_degree = Enum.reduce(graph, Map.new(nodes, fn node -> {node, 0} end), fn {_node, deps}, acc ->
      Enum.reduce(deps, acc, fn dep, inner_acc ->
        Map.update(inner_acc, dep, 1, &(&1 + 1))
      end)
    end)

    queue = Enum.filter(in_degree, fn {_node, degree} -> degree == 0 end) |> Enum.map(&elem(&1, 0))
    sorted = []

    tsort_kahn(graph, in_degree, queue, sorted, node_count)
  end

  # Updated tsort_kahn to detect cycles and return {:error, :circular_dependency}
  defp tsort_kahn(_graph, _in_degree, [], sorted, node_count) do
    if length(sorted) == node_count do
      {:ok, Enum.reverse(sorted)} # Kahn builds reverse topological order
    else
      # Cycle detected: Not all nodes could be added to the sorted list.
      {:error, :circular_dependency}
    end
  end

  defp tsort_kahn(graph, in_degree, [node | queue_tail], sorted, node_count) do
    new_sorted = [node | sorted]
    # Find nodes that depend on the current node
    dependents = Map.keys(graph) |> Enum.filter(&Enum.member?(Map.get(graph, &1, []), node))

    {new_in_degree, new_queue_tail} = Enum.reduce(dependents, {in_degree, queue_tail}, fn dep, {acc_in_degree, acc_queue} ->
      new_degree_map = Map.update!(acc_in_degree, dep, &(&1 - 1))
      if Map.get(new_degree_map, dep) == 0 do
        {new_degree_map, [dep | acc_queue]}
      else
        {new_degree_map, acc_queue}
      end
    end)

    tsort_kahn(graph, new_in_degree, new_queue_tail, new_sorted, node_count)
  end

end
