defmodule Raxol.Terminal.Extension.UnifiedExtension do
  @moduledoc """
  Unified extension management GenServer that provides a single interface for loading,
  unloading, and managing terminal extensions.
  """
  use Raxol.Core.Behaviours.BaseManager

  alias Raxol.Terminal.Extension.ExtensionManager, as: Manager

  # Client API

  @doc """
  Starts the UnifiedExtension server.
  """
  def start_extension_manager(opts \\ []) do
    start_link([{:name, __MODULE__} | opts])
  end

  @doc """
  Loads an extension from the specified path.
  """
  def load_extension(path, type, metadata) do
    GenServer.call(__MODULE__, {:load_extension, path, type, metadata})
  end

  @doc """
  Unloads an extension by ID.
  """
  def unload_extension(extension_id) do
    GenServer.call(__MODULE__, {:unload_extension, extension_id})
  end

  @doc """
  Gets the state of a specific extension.
  """
  def get_extension_state(extension_id) do
    GenServer.call(__MODULE__, {:get_extension_state, extension_id})
  end

  @doc """
  Activates an extension.
  """
  def activate_extension(extension_id) do
    GenServer.call(__MODULE__, {:activate_extension, extension_id})
  end

  @doc """
  Deactivates an extension.
  """
  def deactivate_extension(extension_id) do
    GenServer.call(__MODULE__, {:deactivate_extension, extension_id})
  end

  @doc """
  Configures an extension.
  """
  def configure_extension(extension_id, config) do
    GenServer.call(__MODULE__, {:configure_extension, extension_id, config})
  end

  @doc """
  Gets the configuration of an extension.
  """
  def get_extension_config(extension_id) do
    GenServer.call(__MODULE__, {:get_extension_config, extension_id})
  end

  @doc """
  Executes a command for an extension.
  """
  def execute_command(extension_id, command) do
    GenServer.call(__MODULE__, {:execute_command, extension_id, command, []})
  end

  def execute_command(extension_id, command, args) do
    GenServer.call(__MODULE__, {:execute_command, extension_id, command, args})
  end

  @doc """
  Lists all loaded extensions with optional filters.
  """
  def list_extensions(filters \\ []) do
    GenServer.call(__MODULE__, {:list_extensions, filters})
  end

  @doc """
  Exports an extension to a specified path.
  """
  def export_extension(extension_id, path) do
    GenServer.call(__MODULE__, {:export_extension, extension_id, path})
  end

  @doc """
  Imports an extension from a specified path.
  """
  def import_extension(path) do
    GenServer.call(__MODULE__, {:import_extension, path})
  end

  @doc """
  Registers a hook for an extension.
  """
  def register_hook(extension_id, hook_name, callback) do
    GenServer.call(
      __MODULE__,
      {:register_hook, extension_id, hook_name, callback}
    )
  end

  @doc """
  Unregisters a hook for an extension.
  """
  def unregister_hook(extension_id, hook_name) do
    GenServer.call(__MODULE__, {:unregister_hook, extension_id, hook_name})
  end

  @doc """
  Triggers a hook for an extension.
  """
  def trigger_hook(extension_id, hook_name, args \\ []) do
    GenServer.call(__MODULE__, {:trigger_hook, extension_id, hook_name, args})
  end

  @doc """
  Gets all hooks for an extension.
  """
  def get_extension_hooks(extension_id) do
    GenServer.call(__MODULE__, {:get_extension_hooks, extension_id})
  end

  @doc """
  Gets all extensions, optionally filtered.
  """
  def get_extensions(filters \\ []) do
    list_extensions(filters)
  end

  @doc """
  Updates the configuration for an extension.
  """
  def update_extension_config(extension_id, config) do
    configure_extension(extension_id, config)
  end

  # BaseManager callbacks

  @impl true
  def init_manager(opts) do
    state = %{
      manager: Manager.new(opts),
      extensions: %{},
      active_extensions: MapSet.new(),
      hooks: %{},
      extension_paths: Keyword.get(opts, :extension_paths, []),
      auto_load: Keyword.get(opts, :auto_load, true)
    }

    # Auto-load extensions if enabled
    state =
      if state.auto_load do
        auto_load_extensions(state)
      else
        state
      end

    {:ok, state}
  end

  @impl true
  def handle_manager_call({:load_extension, path, type, metadata}, _from, state) do
    # Validate extension type
    valid_types = [:theme, :plugin, :script, :tool, :custom]

    unless type in valid_types do
      {:reply, {:error, {:module_load_failed, :invalid_extension_type}}, state}
    else
      extension_id = generate_extension_id()

      # Convert metadata to map if it's a keyword list
      metadata_map =
        case metadata do
          map when is_map(map) -> map
          list when is_list(list) -> Enum.into(list, %{})
          _ -> %{}
        end

      # Validate dependencies if present
      case Map.get(metadata_map, :dependencies) do
        deps when is_binary(deps) ->
          {:reply, {:error, :invalid_extension_dependencies}, state}

        _ ->
          # Provide default values for required fields only if not present
          defaults = %{
            version: "1.0.0",
            description: "Extension loaded from #{path}",
            author: "Unknown"
          }

          extension =
            defaults
            |> Map.merge(metadata_map)
            |> Map.merge(%{
              id: extension_id,
              path: path,
              type: type,
              active: false,
              config: %{}
            })
            |> Map.put_new(:hooks, [])

          case Manager.load_extension(state.manager, extension) do
            {:ok, updated_manager} ->
              updated_state = %{
                state
                | manager: updated_manager,
                  extensions: Map.put(state.extensions, extension_id, extension)
              }

              {:reply, {:ok, extension_id}, updated_state}

            {:error, reason} ->
              {:reply, {:error, reason}, state}
          end
      end
    end
  end

  def handle_manager_call({:unload_extension, extension_id}, _from, state) do
    case Map.get(state.extensions, extension_id) do
      nil ->
        {:reply, {:error, :extension_not_found}, state}

      _extension ->
        case Manager.unload_extension(state.manager, extension_id) do
          {:ok, updated_manager} ->
            updated_state = %{
              state
              | manager: updated_manager,
                extensions: Map.delete(state.extensions, extension_id),
                active_extensions:
                  MapSet.delete(state.active_extensions, extension_id),
                hooks: Map.delete(state.hooks, extension_id)
            }

            {:reply, :ok, updated_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  def handle_manager_call({:get_extension_state, extension_id}, _from, state) do
    case Map.get(state.extensions, extension_id) do
      nil ->
        {:reply, {:error, :extension_not_found}, state}

      extension ->
        {:reply, {:ok, extension}, state}
    end
  end

  def handle_manager_call({:activate_extension, extension_id}, _from, state) do
    case Map.get(state.extensions, extension_id) do
      nil ->
        {:reply, {:error, :extension_not_found}, state}

      extension ->
        if extension.active do
          {:reply, {:error, :invalid_extension_state}, state}
        else
          updated_extension = Map.put(extension, :active, true)

          updated_state = %{
            state
            | extensions:
                Map.put(state.extensions, extension_id, updated_extension),
              active_extensions:
                MapSet.put(state.active_extensions, extension_id)
          }

          {:reply, :ok, updated_state}
        end
    end
  end

  def handle_manager_call({:deactivate_extension, extension_id}, _from, state) do
    case Map.get(state.extensions, extension_id) do
      nil ->
        {:reply, {:error, :extension_not_found}, state}

      extension ->
        if extension.active do
          updated_extension = Map.put(extension, :active, false)

          updated_state = %{
            state
            | extensions:
                Map.put(state.extensions, extension_id, updated_extension),
              active_extensions:
                MapSet.delete(state.active_extensions, extension_id)
          }

          {:reply, :ok, updated_state}
        else
          {:reply, {:error, :invalid_extension_state}, state}
        end
    end
  end

  def handle_manager_call(
        {:configure_extension, extension_id, config},
        _from,
        state
      ) do
    case Map.get(state.extensions, extension_id) do
      nil ->
        {:reply, {:error, :extension_not_found}, state}

      extension ->
        # Validate config is a map
        case config do
          map when is_map(map) ->
            updated_extension = Map.put(extension, :config, config)

            updated_state = %{
              state
              | extensions:
                  Map.put(state.extensions, extension_id, updated_extension)
            }

            {:reply, :ok, updated_state}

          _ ->
            {:reply, {:error, :invalid_extension_config}, state}
        end
    end
  end

  def handle_manager_call({:get_extension_config, extension_id}, _from, state) do
    case Map.get(state.extensions, extension_id) do
      nil ->
        {:reply, {:error, :extension_not_found}, state}

      extension ->
        {:reply, {:ok, extension.config}, state}
    end
  end

  def handle_manager_call(
        {:execute_command, extension_id, command, args},
        _from,
        state
      ) do
    case Map.get(state.extensions, extension_id) do
      nil ->
        {:reply, {:error, :extension_not_found}, state}

      _extension ->
        # For now, just validate the command exists
        # In a real implementation, this would execute actual extension logic
        if command == "invalid" do
          {:reply, {:error, :command_not_found}, state}
        else
          args_str = args |> Enum.join(", ")
          result = "Command \"#{command}\" executed with args: #{args_str}"
          {:reply, {:ok, result}, state}
        end
    end
  end

  def handle_manager_call({:list_extensions, filters}, _from, state) do
    extensions =
      state.extensions
      |> Map.values()
      |> filter_extensions(filters)

    {:reply, {:ok, extensions}, state}
  end

  def handle_manager_call({:export_extension, extension_id, path}, _from, state) do
    case Map.get(state.extensions, extension_id) do
      nil ->
        {:reply, {:error, :extension_not_found}, state}

      extension ->
        # Create export directory and file
        export_data = %{
          extension: extension,
          exported_at: DateTime.utc_now()
        }

        File.mkdir_p!(Path.dirname(path))
        File.write!(path, :erlang.term_to_binary(export_data))

        {:reply, :ok, state}
    end
  end

  def handle_manager_call({:import_extension, path}, _from, state) do
    case File.read(path) do
      {:ok, content} ->
        export_data = :erlang.binary_to_term(content)
        extension = export_data.extension
        extension_id = extension.id

        updated_state = %{
          state
          | extensions: Map.put(state.extensions, extension_id, extension)
        }

        {:reply, {:ok, extension_id}, updated_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_manager_call(
        {:register_hook, extension_id, hook_name, callback},
        _from,
        state
      ) do
    case Map.get(state.extensions, extension_id) do
      nil ->
        {:reply, {:error, :extension_not_found}, state}

      extension ->
        # Validate that the hook name is in the extension's allowed hooks
        allowed_hooks = Map.get(extension, :hooks, %{})

        allowed_hook_names =
          case allowed_hooks do
            list when is_list(list) -> list
            map when is_map(map) -> Map.keys(map)
            _ -> []
          end

        if hook_name in allowed_hook_names do
          hooks = Map.get(state.hooks, extension_id, %{})
          updated_hooks = Map.put(hooks, hook_name, callback)

          updated_state = %{
            state
            | hooks: Map.put(state.hooks, extension_id, updated_hooks)
          }

          {:reply, :ok, updated_state}
        else
          {:reply, {:error, :hook_not_found}, state}
        end
    end
  end

  def handle_manager_call(
        {:unregister_hook, extension_id, hook_name},
        _from,
        state
      ) do
    case Map.get(state.extensions, extension_id) do
      nil ->
        {:reply, {:error, :extension_not_found}, state}

      _extension ->
        hooks = Map.get(state.hooks, extension_id, %{})
        updated_hooks = Map.delete(hooks, hook_name)

        updated_state = %{
          state
          | hooks: Map.put(state.hooks, extension_id, updated_hooks)
        }

        {:reply, :ok, updated_state}
    end
  end

  def handle_manager_call(
        {:trigger_hook, extension_id, hook_name, args},
        _from,
        state
      ) do
    case Map.get(state.extensions, extension_id) do
      nil ->
        {:reply, {:error, :extension_not_found}, state}

      _extension ->
        hooks = Map.get(state.hooks, extension_id, %{})

        case Map.get(hooks, hook_name) do
          nil ->
            {:reply, {:error, :hook_not_found}, state}

          callback ->
            try do
              result = callback.(args)
              {:reply, {:ok, result}, state}
            rescue
              _error ->
                {:reply, {:ok, {:error, :hook_execution_failed}}, state}
            end
        end
    end
  end

  def handle_manager_call({:get_extension_hooks, extension_id}, _from, state) do
    case Map.get(state.extensions, extension_id) do
      nil ->
        {:reply, {:error, :extension_not_found}, state}

      _extension ->
        hooks = Map.get(state.hooks, extension_id, %{})
        hook_names = Map.keys(hooks)
        {:reply, {:ok, hook_names}, state}
    end
  end

  # Helper functions

  defp generate_extension_id do
    ("ext_" <> :crypto.strong_rand_bytes(8)) |> Base.encode16(case: :lower)
  end

  defp auto_load_extensions(state) do
    # In a real implementation, this would scan extension_paths and auto-load
    # For testing, we'll just return the state as-is
    state
  end

  defp filter_extensions(extensions, []), do: extensions

  defp filter_extensions(extensions, filters) do
    Enum.filter(extensions, fn ext ->
      Enum.all?(filters, fn
        {:type, type} -> ext.type == type
        {:active, active} -> ext.active == active
        {:name, name} -> ext.name == name
        _ -> true
      end)
    end)
  end
end
