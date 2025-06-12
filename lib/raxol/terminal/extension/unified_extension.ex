defmodule Raxol.Terminal.Extension.UnifiedExtension do
  @moduledoc """
  Unified extension system for the Raxol terminal emulator.
  Handles extension management, integration, and communication with the terminal.
  """

  use GenServer
  require Logger

  # Types
  @type extension_id :: String.t()
  @type extension_type :: :theme | :script | :plugin | :custom
  @type extension_state :: %{
    id: extension_id,
    name: String.t(),
    type: extension_type,
    version: String.t(),
    description: String.t(),
    author: String.t(),
    license: String.t(),
    config: map(),
    status: :idle | :active | :error,
    error: String.t() | nil,
    metadata: map(),
    dependencies: [String.t()],
    hooks: [String.t()],
    commands: [String.t()]
  }

  # Client API
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Loads an extension from a file or directory.
  """
  def load_extension(path, type, opts \\ []) do
    GenServer.call(__MODULE__, {:load_extension, path, type, opts})
  end

  @doc """
  Unloads an extension by its ID.
  """
  def unload_extension(extension_id) do
    GenServer.call(__MODULE__, {:unload_extension, extension_id})
  end

  @doc """
  Gets the state of an extension.
  """
  def get_extension_state(extension_id) do
    GenServer.call(__MODULE__, {:get_extension_state, extension_id})
  end

  @doc """
  Updates an extension's configuration.
  """
  def update_extension_config(extension_id, config) do
    GenServer.call(__MODULE__, {:update_extension_config, extension_id, config})
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
  Executes an extension command.
  """
  def execute_command(extension_id, command, args \\ []) do
    GenServer.call(__MODULE__, {:execute_command, extension_id, command, args})
  end

  @doc """
  Gets all loaded extensions.
  """
  def get_extensions(opts \\ []) do
    GenServer.call(__MODULE__, {:get_extensions, opts})
  end

  @doc """
  Exports an extension to a file or directory.
  """
  def export_extension(extension_id, path) do
    GenServer.call(__MODULE__, {:export_extension, extension_id, path})
  end

  @doc """
  Imports an extension from a file or directory.
  """
  def import_extension(path, opts \\ []) do
    GenServer.call(__MODULE__, {:import_extension, path, opts})
  end

  @doc """
  Registers a hook for an extension.
  """
  def register_hook(extension_id, hook_name, callback) do
    GenServer.call(__MODULE__, {:register_hook, extension_id, hook_name, callback})
  end

  @doc """
  Unregisters a hook for an extension.
  """
  def unregister_hook(extension_id, hook_name) do
    GenServer.call(__MODULE__, {:unregister_hook, extension_id, hook_name})
  end

  @doc """
  Triggers a hook for all registered extensions.
  """
  def trigger_hook(hook_name, args \\ []) do
    GenServer.call(__MODULE__, {:trigger_hook, hook_name, args})
  end

  # Server Callbacks
  @impl true
  def init(opts) do
    state = %{
      extensions: %{},
      extension_paths: Keyword.get(opts, :extension_paths, ["extensions"]),
      auto_load: Keyword.get(opts, :auto_load, false),
      max_extensions: Keyword.get(opts, :max_extensions, 100),
      hooks: %{},
      commands: %{}
    }

    if state.auto_load do
      load_extensions_from_paths(state.extension_paths)
    end

    {:ok, state}
  end

  @impl true
  def handle_call({:load_extension, path, type, opts}, _from, state) do
    extension_id = generate_extension_id()
    extension_state = load_extension_state(path, type, opts)

    case validate_extension(extension_state) do
      :ok ->
        new_state = put_in(state.extensions[extension_id], extension_state)
        {:reply, {:ok, extension_id}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:unload_extension, extension_id}, _from, state) do
    case Map.get(state.extensions, extension_id) do
      nil ->
        {:reply, {:error, :extension_not_found}, state}

      extension ->
        new_state = update_in(state.extensions, &Map.delete(&1, extension_id))
        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:get_extension_state, extension_id}, _from, state) do
    case Map.get(state.extensions, extension_id) do
      nil ->
        {:reply, {:error, :extension_not_found}, state}

      extension ->
        {:reply, {:ok, extension}, state}
    end
  end

  @impl true
  def handle_call({:update_extension_config, extension_id, config}, _from, state) do
    case Map.get(state.extensions, extension_id) do
      nil ->
        {:reply, {:error, :extension_not_found}, state}

      extension ->
        new_extension = update_in(extension.config, &Map.merge(&1, config))
        new_state = put_in(state.extensions[extension_id], new_extension)
        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:activate_extension, extension_id}, _from, state) do
    case Map.get(state.extensions, extension_id) do
      nil ->
        {:reply, {:error, :extension_not_found}, state}

      extension ->
        if extension.status == :idle do
          new_extension = %{extension | status: :active}
          new_state = put_in(state.extensions[extension_id], new_extension)
          {:reply, :ok, new_state}
        else
          {:reply, {:error, :invalid_extension_state}, state}
        end
    end
  end

  @impl true
  def handle_call({:deactivate_extension, extension_id}, _from, state) do
    case Map.get(state.extensions, extension_id) do
      nil ->
        {:reply, {:error, :extension_not_found}, state}

      extension ->
        if extension.status == :active do
          new_extension = %{extension | status: :idle}
          new_state = put_in(state.extensions[extension_id], new_extension)
          {:reply, :ok, new_state}
        else
          {:reply, {:error, :invalid_extension_state}, state}
        end
    end
  end

  @impl true
  def handle_call({:execute_command, extension_id, command, args}, _from, state) do
    case Map.get(state.extensions, extension_id) do
      nil ->
        {:reply, {:error, :extension_not_found}, state}

      extension ->
        if command in extension.commands do
          case do_execute_command(extension, command, args) do
            {:ok, result} ->
              {:reply, {:ok, result}, state}

            {:error, reason} ->
              new_extension = %{extension | status: :error, error: reason}
              new_state = put_in(state.extensions[extension_id], new_extension)
              {:reply, {:error, reason}, new_state}
          end
        else
          {:reply, {:error, :command_not_found}, state}
        end
    end
  end

  @impl true
  def handle_call({:get_extensions, opts}, _from, state) do
    extensions = filter_extensions(state.extensions, opts)
    {:reply, {:ok, extensions}, state}
  end

  @impl true
  def handle_call({:export_extension, extension_id, path}, _from, state) do
    case Map.get(state.extensions, extension_id) do
      nil ->
        {:reply, {:error, :extension_not_found}, state}

      extension ->
        case export_extension_to_path(extension, path) do
          :ok ->
            {:reply, :ok, state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  @impl true
  def handle_call({:import_extension, path, opts}, _from, state) do
    case import_extension_from_path(path, opts) do
      {:ok, extension} ->
        extension_id = generate_extension_id()
        new_state = put_in(state.extensions[extension_id], extension)
        {:reply, {:ok, extension_id}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:register_hook, extension_id, hook_name, callback}, _from, state) do
    case Map.get(state.extensions, extension_id) do
      nil ->
        {:reply, {:error, :extension_not_found}, state}

      extension ->
        if hook_name in extension.hooks do
          new_hooks = Map.update(state.hooks, hook_name, [callback], &[callback | &1])
          new_state = %{state | hooks: new_hooks}
          {:reply, :ok, new_state}
        else
          {:reply, {:error, :hook_not_found}, state}
        end
    end
  end

  @impl true
  def handle_call({:unregister_hook, extension_id, hook_name}, _from, state) do
    case Map.get(state.extensions, extension_id) do
      nil ->
        {:reply, {:error, :extension_not_found}, state}

      extension ->
        if hook_name in extension.hooks do
          new_hooks = Map.update(state.hooks, hook_name, [], &Enum.reject(&1, fn callback ->
            callback.extension_id == extension_id
          end))
          new_state = %{state | hooks: new_hooks}
          {:reply, :ok, new_state}
        else
          {:reply, {:error, :hook_not_found}, state}
        end
    end
  end

  @impl true
  def handle_call({:trigger_hook, hook_name, args}, _from, state) do
    case Map.get(state.hooks, hook_name) do
      nil ->
        {:reply, :ok, state}

      callbacks ->
        results = Enum.map(callbacks, fn callback ->
          Task.async(fn ->
            try do
              callback.fun.(args)
            rescue
              e ->
                Logger.error("Hook execution failed: #{inspect(e)}")
                {:error, :hook_execution_failed}
            end
          end)
        end)
        |> Enum.map(&Task.await(&1, 5000))

        {:reply, {:ok, results}, state}
    end
  end

  # Private Functions
  defp generate_extension_id do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16()
    |> binary_part(0, 8)
  end

  defp load_extension_state(path, type, opts) do
    %{
      id: nil,
      name: Keyword.get(opts, :name, "Unnamed Extension"),
      type: type,
      version: Keyword.get(opts, :version, "1.0.0"),
      description: Keyword.get(opts, :description, ""),
      author: Keyword.get(opts, :author, "Unknown"),
      license: Keyword.get(opts, :license, "MIT"),
      config: Keyword.get(opts, :config, %{}),
      status: :idle,
      error: nil,
      metadata: Keyword.get(opts, :metadata, %{}),
      dependencies: Keyword.get(opts, :dependencies, []),
      hooks: Keyword.get(opts, :hooks, []),
      commands: Keyword.get(opts, :commands, [])
    }
  end

  defp validate_extension(extension) do
    with :ok <- validate_extension_type(extension.type),
         :ok <- validate_extension_config(extension.config),
         :ok <- validate_extension_dependencies(extension.dependencies) do
      :ok
    end
  end

  defp validate_extension_type(type) when type in [:theme, :script, :plugin, :custom], do: :ok
  defp validate_extension_type(_), do: {:error, :invalid_extension_type}

  defp validate_extension_config(config) when is_map(config), do: :ok
  defp validate_extension_config(_), do: {:error, :invalid_extension_config}

  defp validate_extension_dependencies(dependencies) when is_list(dependencies), do: :ok
  defp validate_extension_dependencies(_), do: {:error, :invalid_extension_dependencies}

  defp do_execute_command(extension, command, args) do
    # TODO: Implement actual command execution based on extension type
    # This is a placeholder that simulates command execution
    Process.sleep(100)
    {:ok, "Command '#{command}' executed with args: #{inspect(args)}"}
  end

  defp filter_extensions(extensions, opts) do
    extensions
    |> Enum.filter(fn {_id, extension} ->
      Enum.all?(opts, fn
        {:type, type} -> extension.type == type
        {:status, status} -> extension.status == status
        _ -> true
      end)
    end)
    |> Map.new()
  end

  defp export_extension_to_path(extension, path) do
    # TODO: Implement actual extension export
    # This is a placeholder that simulates extension export
    {:ok, _} = File.write(path, Jason.encode!(extension))
    :ok
  end

  defp import_extension_from_path(path, opts) do
    # TODO: Implement actual extension import
    # This is a placeholder that simulates extension import
    case File.read(path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, extension} ->
            {:ok, load_extension_state(path, extension["type"], opts)}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp load_extensions_from_paths(paths) do
    # TODO: Implement actual extension loading from paths
    # This is a placeholder that simulates extension loading
    :ok
  end
end
