defmodule Raxol.Core.Runtime.Plugins.Discovery do
  @moduledoc """
  Handles plugin discovery and initialization.
  This module is responsible for:
  - Discovering available plugins in configured directories
  - Initializing the plugin system
  - Managing plugin metadata and paths
  - Handling plugin dependencies
  """

  require Raxol.Core.Runtime.Log

  alias Raxol.Core.Runtime.Plugins.{FileWatcher, Loader, StateManager}

  @doc """
  Initializes the plugin discovery system.
  """
  def initialize(state) do
    with {:ok, state} <- StateManager.initialize(state),
         {:ok, state} <- FileWatcher.setup_file_watching(state) do
      # Merge plugin_dirs and plugins_dir into a list of dirs
      plugin_dirs =
        (state.plugin_dirs || []) ++
          if state.plugins_dir, do: [state.plugins_dir], else: []

      # Remove duplicates
      plugin_dirs = Enum.uniq(plugin_dirs)
      # Discover plugins in all directories
      case Loader.discover_plugins(plugin_dirs) do
        {:ok, _plugins} ->
          {:ok,
           %{
             state
             | initialized: true,
               file_watching_enabled?: state.file_watching_enabled? || false,
               command_registry_table:
                 state.command_registry_table || :undefined
           }}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Discovers plugins in the given state (all plugin_dirs and plugins_dir).
  """
  def discover_plugins(state) do
    plugin_dirs =
      (state.plugin_dirs || []) ++
        if state.plugins_dir, do: [state.plugins_dir], else: []

    plugin_dirs = Enum.uniq(plugin_dirs)

    Enum.reduce_while(plugin_dirs, {:ok, state}, fn dir, {:ok, acc_state} ->
      case discover_plugins_in_dir(dir, acc_state) do
        {:ok, new_state} -> {:cont, {:ok, new_state}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  @doc """
  Discovers plugins in a specific directory.
  """
  def discover_plugins_in_dir(dir, state) do
    # Use the private helper directly
    discover_plugins_in_dir_helper(dir, state)
  end

  @doc """
  Lists all discovered plugins in load order as {id, metadata}.
  """
  def list_plugins(state) do
    Enum.map(state.load_order || [], fn id ->
      {id, Map.get(state.metadata || %{}, id)}
    end)
  end

  @doc """
  Gets a specific plugin by ID.
  """
  def get_plugin(plugin_id, state) do
    case Map.get(state.plugins, plugin_id) do
      nil -> {:error, :not_found}
      plugin -> {:ok, plugin}
    end
  end

  # Private helper functions

  defp discover_plugins_in_dir_helper(dir, state) do
    case File.dir?(dir) do
      true -> load_plugins_in_dir(dir, state)
      false -> handle_missing_dir(dir, state)
    end
  end

  defp load_plugins_in_dir(dir, state) do
    plugins =
      dir
      |> File.ls!()
      |> Enum.filter(&String.ends_with?(&1, ".ex"))
      |> Enum.map(&Path.join(dir, &1))

    Enum.reduce_while(plugins, {:ok, state}, &load_plugin_with_reduce/2)
  end

  defp load_plugin_with_reduce(plugin_path, {:ok, acc_state}) do
    case load_discovered_plugin(plugin_path, acc_state) do
      {:ok, new_state} -> {:cont, {:ok, new_state}}
      {:error, reason} -> {:halt, {:error, reason}}
    end
  end

  defp handle_missing_dir(dir, state) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "[#{__MODULE__}] Plugin directory not found: #{dir}",
      %{}
    )

    {:ok, state}
  end

  defp load_discovered_plugin(plugin_path, state) do
    plugin_id = Path.basename(plugin_path, ".ex")
    load_and_initialize_plugin(plugin_id, plugin_path, state)
  end

  defp load_and_initialize_plugin(plugin_id, plugin_path, state) do
    case state.loader_module.load_plugin(plugin_id, %{}) do
      {:ok, plugin, metadata} ->
        initialize_plugin(plugin_id, plugin, metadata, plugin_path, state)

      {:error, reason} ->
        handle_load_error(reason, plugin_id)
    end
  end

  defp initialize_plugin(plugin_id, plugin, metadata, plugin_path, state) do
    case state.lifecycle_helper_module.initialize_plugin(plugin, %{}) do
      {:ok, initial_state} ->
        {:ok,
         update_state_with_plugin(
           state,
           plugin_id,
           plugin,
           metadata,
           initial_state,
           plugin_path
         )}

      {:error, reason} ->
        handle_init_error(reason, plugin_id)
    end
  end

  defp update_state_with_plugin(
         state,
         plugin_id,
         plugin,
         metadata,
         initial_state,
         plugin_path
       ) do
    %{
      state
      | plugins: Map.put(state.plugins, plugin_id, plugin),
        metadata: Map.put(state.metadata, plugin_id, metadata),
        plugin_states: Map.put(state.plugin_states, plugin_id, initial_state),
        plugin_paths: Map.put(state.plugin_paths, plugin_id, plugin_path),
        reverse_plugin_paths:
          Map.put(state.reverse_plugin_paths, plugin_path, plugin_id),
        load_order: [plugin_id | state.load_order]
    }
  end

  defp handle_load_error(reason, plugin_id) do
    Raxol.Core.Runtime.Log.error_with_stacktrace(
      "[#{__MODULE__}] Failed to load discovered plugin",
      reason,
      nil,
      %{module: __MODULE__, plugin_id: plugin_id, reason: reason}
    )

    {:error, reason}
  end

  defp handle_init_error(reason, plugin_id) do
    Raxol.Core.Runtime.Log.error_with_stacktrace(
      "[#{__MODULE__}] Failed to initialize discovered plugin",
      reason,
      nil,
      %{module: __MODULE__, plugin_id: plugin_id, reason: reason}
    )

    {:error, reason}
  end
end
