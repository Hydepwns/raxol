defmodule Raxol.Core.Runtime.Plugins.Loader do
  @moduledoc """
  Manages plugin loading operations.
  """

  use GenServer
  require Logger
  @behaviour Raxol.Core.Runtime.Plugins.LoaderBehaviour

  alias Raxol.Core.ErrorHandling

  defstruct [
    :loaded_plugins,
    :plugin_configs,
    :plugin_metadata
  ]

  @type t :: %__MODULE__{
          loaded_plugins: map(),
          plugin_configs: map(),
          plugin_metadata: map()
        }

  # Client API

  @doc """
  Starts the plugin loader.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Loads a plugin from the given path.
  """
  @impl Raxol.Core.Runtime.Plugins.LoaderBehaviour
  def load_plugin(plugin_path) when is_binary(plugin_path) do
    GenServer.call(__MODULE__, {:load_plugin, plugin_path})
  end

  @doc """
  Unloads a plugin.
  """
  @impl Raxol.Core.Runtime.Plugins.LoaderBehaviour
  def unload_plugin(plugin) do
    GenServer.call(__MODULE__, {:unload_plugin, plugin})
  end

  @doc """
  Reloads a plugin.
  """
  @impl Raxol.Core.Runtime.Plugins.LoaderBehaviour
  def reload_plugin(plugin) do
    GenServer.call(__MODULE__, {:reload_plugin, plugin})
  end

  @doc """
  Gets the list of loaded plugins.
  """
  @impl Raxol.Core.Runtime.Plugins.LoaderBehaviour
  def get_loaded_plugins do
    GenServer.call(__MODULE__, :get_loaded_plugins)
  end

  @doc """
  Checks if a plugin is loaded.
  """
  @impl Raxol.Core.Runtime.Plugins.LoaderBehaviour
  def plugin_loaded?(plugin) do
    GenServer.call(__MODULE__, {:plugin_loaded?, plugin})
  end

  @doc """
  Discovers plugins in the given directories.
  Returns a list of discovered plugin paths.
  """
  def discover_plugins(plugin_dirs) when is_list(plugin_dirs) do
    discovered_plugins =
      plugin_dirs
      |> Enum.flat_map(fn dir ->
        case File.dir?(dir) do
          true ->
            dir
            |> File.ls!()
            |> Enum.filter(&String.ends_with?(&1, ".ex"))
            |> Enum.map(&Path.join(dir, &1))

          false ->
            []
        end
      end)
      |> Enum.uniq()

    {:ok, discovered_plugins}
  end

  def discover_plugins(_) do
    {:error, :invalid_directories}
  end

  # Server Callbacks

  @impl GenServer
  def init(_opts) do
    state = %__MODULE__{
      loaded_plugins: %{},
      plugin_configs: %{},
      plugin_metadata: %{}
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:load_plugin, plugin_path}, _from, state) do
    case do_load_plugin(plugin_path, state) do
      {:ok, new_state} ->
        {:reply, {:ok, Map.get(new_state.loaded_plugins, plugin_path)},
         new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:unload_plugin, plugin}, _from, state) do
    case do_unload_plugin(plugin, state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:reload_plugin, plugin}, _from, state) do
    case do_reload_plugin(plugin, state) do
      {:ok, new_state} ->
        {:reply, {:ok, Map.get(new_state.loaded_plugins, plugin)}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call(:get_loaded_plugins, _from, state) do
    {:reply, Map.values(state.loaded_plugins), state}
  end

  @impl GenServer
  def handle_call({:plugin_loaded?, plugin}, _from, state) do
    {:reply, Map.has_key?(state.loaded_plugins, plugin), state}
  end

  # Private Functions

  defp do_load_plugin(plugin_path, state) do
    with {:ok, plugin_module} <- Code.compile_file(plugin_path),
         {:ok, plugin_metadata} <- extract_metadata(plugin_module),
         {:ok, _initial_state} <- initialize_plugin(plugin_module, %{}) do
      new_state = %{
        state
        | loaded_plugins:
            Map.put(state.loaded_plugins, plugin_path, plugin_module),
          plugin_configs: Map.put(state.plugin_configs, plugin_path, %{}),
          plugin_metadata:
            Map.put(state.plugin_metadata, plugin_path, plugin_metadata)
      }

      {:ok, new_state}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp do_unload_plugin(plugin, state) do
    case Map.get(state.loaded_plugins, plugin) do
      nil ->
        {:error, :plugin_not_found}

      plugin_module ->
        :code.purge(plugin_module)

        new_state = %{
          state
          | loaded_plugins: Map.delete(state.loaded_plugins, plugin),
            plugin_configs: Map.delete(state.plugin_configs, plugin),
            plugin_metadata: Map.delete(state.plugin_metadata, plugin)
        }

        {:ok, new_state}
    end
  end

  defp do_reload_plugin(plugin, state) do
    with {:ok, new_state} <- do_unload_plugin(plugin, state),
         {:ok, final_state} <- do_load_plugin(plugin, new_state) do
      {:ok, final_state}
    else
      error -> error
    end
  end

  def extract_metadata(module) do
    if function_exported?(module, :plugin_info, 0) do
      {:ok, module.plugin_info()}
    else
      {:ok, %{name: module, version: "1.0.0"}}
    end
  end

  def initialize_plugin(module, config) do
    if function_exported?(module, :init, 1) do
      case module.init(config) do
        {:ok, state} -> {:ok, state}
        state when is_map(state) -> {:ok, state}
        _ -> {:error, :invalid_init_return}
      end
    else
      {:ok, %{}}
    end
  end

  @doc """
  Checks if a module implements the given behaviour.
  """
  def behaviour_implemented?(module, behaviour) do
    case ErrorHandling.safe_call(fn ->
           # Check if the module has the behaviour attribute
           module_info = module.module_info(:attributes)
           behaviours = Keyword.get_values(module_info, :behaviour)

           if behaviour in behaviours do
             true
           else
             # Fallback: check if the module has the required callbacks
             # This is a simplified check - in a real implementation you'd check all callbacks
             function_exported?(module, :plugin_info, 0)
           end
         end) do
      {:ok, result} -> result
      {:error, _} -> false
    end
  end

  @doc """
  Loads code for a plugin by its ID.
  """
  def load_code(id) when is_binary(id) do
    # This is a simplified implementation
    # In a real implementation, this would load the actual plugin code
    case String.ends_with?(id, ".ex") or String.ends_with?(id, ".exs") do
      true ->
        # Assume it's a file path
        case Code.compile_file(id) do
          [{module, _}] -> {:ok, module}
          _ -> {:error, :compilation_failed}
        end

      false ->
        # Assume it's a module name
        case ErrorHandling.safe_call(fn ->
               module = String.to_existing_atom(id)

               if Code.ensure_loaded(module) == {:module, module} do
                 {:ok, module}
               else
                 {:error, :module_not_found}
               end
             end) do
          {:ok, result} -> result
          {:error, _} -> {:error, :module_not_found}
        end
    end
  end

  def load_code(_id) do
    {:error, :invalid_id}
  end
end
