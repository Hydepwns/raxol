defmodule Raxol.Core.Runtime.Plugins.Discovery do
  @moduledoc """
  Handles plugin discovery and initialization.
  This module is responsible for:
  - Discovering available plugins in configured directories
  - Initializing the plugin system
  - Managing plugin metadata and paths
  - Handling plugin dependencies
  """

  require Logger

  alias Raxol.Core.Runtime.Plugins.{FileWatcher, Loader, StateManager}

  @doc """
  Initializes the plugin discovery system.
  """
  def initialize(state) do
    with {:ok, state} <- StateManager.initialize(state),
         {:ok, state} <- FileWatcher.setup_file_watching(state) do
      {:ok, state}
    end
  end

  @doc """
  Discovers plugins in the given directories.
  """
  def discover_plugins(dirs) do
    Loader.discover_plugins(dirs)
  end

  @doc """
  Discovers plugins in a specific directory.
  """
  def discover_plugins_in_dir(dir, state) do
    # Use the private helper directly
    discover_plugins_in_dir_helper(dir, state)
  end

  @doc """
  Lists all discovered plugins in load order.
  """
  def list_plugins(state) do
    {:ok, state.load_order}
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
      true ->
        # Get all .ex files in the directory
        plugins =
          dir
          |> File.ls!()
          |> Enum.filter(&String.ends_with?(&1, ".ex"))
          |> Enum.map(&Path.join(dir, &1))

        # Load each plugin
        Enum.reduce_while(plugins, {:ok, state}, fn plugin_path, {:ok, acc_state} ->
          case load_discovered_plugin(plugin_path, acc_state) do
            {:ok, new_state} -> {:cont, {:ok, new_state}}
            {:error, reason} -> {:halt, {:error, reason}}
          end
        end)

      false ->
        Logger.warning("[#{__MODULE__}] Plugin directory not found: #{dir}")
        {:ok, state}
    end
  end

  defp load_discovered_plugin(plugin_path, state) do
    # Extract plugin ID from path
    plugin_id = Path.basename(plugin_path, ".ex")

    # Load the plugin
    case state.loader_module.load_plugin(plugin_id, %{}) do
      {:ok, plugin, metadata} ->
        # Initialize the plugin
        case state.lifecycle_helper_module.initialize_plugin(plugin, %{}) do
          {:ok, initial_state} ->
            # Update state with new plugin
            updated_state = %{
              state
              | plugins: Map.put(state.plugins, plugin_id, plugin),
                metadata: Map.put(state.metadata, plugin_id, metadata),
                plugin_states: Map.put(state.plugin_states, plugin_id, initial_state),
                plugin_paths: Map.put(state.plugin_paths, plugin_id, plugin_path),
                reverse_plugin_paths: Map.put(state.reverse_plugin_paths, plugin_path, plugin_id),
                load_order: [plugin_id | state.load_order]
            }

            {:ok, updated_state}

          {:error, reason} ->
            Logger.error(
              "[#{__MODULE__}] Failed to initialize discovered plugin #{plugin_id}: #{inspect(reason)}"
            )

            {:error, reason}
        end

      {:error, reason} ->
        Logger.error(
          "[#{__MODULE__}] Failed to load discovered plugin #{plugin_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end
end
