defmodule Raxol.Terminal.Extension.UnifiedExtension do
  @moduledoc """
  Unified extension system for the Raxol terminal emulator.
  Handles extension management, integration, and communication with the terminal.
  """

  use GenServer
  require Logger

  # Add aliases for the new modules
  alias Raxol.Terminal.Extension.LifecycleManager
  alias Raxol.Terminal.Extension.StateManager
  alias Raxol.Terminal.Extension.CommandHandler
  alias Raxol.Terminal.Extension.HookManager
  alias Raxol.Terminal.Extension.FileOperations

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
          commands: [String.t()],
          module: module() | nil,
          path: String.t() | nil,
          manifest: map() | nil
        }

  # Extension manifest file name
  @manifest_file "extension.json"
  @config_file "config.exs"
  @script_file "script.ex"

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
  Triggers a hook for all registered extensions.
  """
  def trigger_hook(hook_name, args \\ []) do
    GenServer.call(__MODULE__, {:trigger_hook, hook_name, args})
  end

  # Server Callbacks
  @impl GenServer
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
      FileOperations.load_extensions_from_paths(state.extension_paths)
    end

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:load_extension, path, type, opts}, _from, state) do
    case LifecycleManager.load_extension(path, type, opts, state) do
      {:ok, extension_id, new_state} ->
        {:reply, {:ok, extension_id}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:unload_extension, extension_id}, _from, state) do
    case LifecycleManager.unload_extension(extension_id, state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:get_extension_state, extension_id}, _from, state) do
    case StateManager.get_extension_state(extension_id, state) do
      {:ok, extension} -> {:reply, {:ok, extension}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call(
        {:update_extension_config, extension_id, config},
        _from,
        state
      ) do
    case StateManager.update_extension_config(extension_id, config, state) do
      {:ok, new_state} -> {:reply, :ok, new_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:activate_extension, extension_id}, _from, state) do
    case LifecycleManager.activate_extension(extension_id, state) do
      {:ok, new_state} -> {:reply, :ok, new_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:deactivate_extension, extension_id}, _from, state) do
    case LifecycleManager.deactivate_extension(extension_id, state) do
      {:ok, new_state} -> {:reply, :ok, new_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:execute_command, extension_id, command, args}, _from, state) do
    case CommandHandler.execute_command(extension_id, command, args, state) do
      {:ok, result} -> {:reply, {:ok, result}, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:get_extensions, opts}, _from, state) do
    extensions = StateManager.filter_extensions(state.extensions, opts)
    {:reply, {:ok, extensions}, state}
  end

  @impl GenServer
  def handle_call({:export_extension, extension_id, path}, _from, state) do
    case Map.get(state.extensions, extension_id) do
      nil ->
        {:reply, {:error, :extension_not_found}, state}

      extension ->
        case FileOperations.export_extension(extension, path) do
          :ok -> {:reply, :ok, state}
          {:error, reason} -> {:reply, {:error, reason}, state}
        end
    end
  end

  @impl GenServer
  def handle_call({:import_extension, path, opts}, _from, state) do
    case FileOperations.import_extension_from_path(path, opts) do
      {:ok, extension} -> handle_extension_import(extension, state)
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call(
        {:register_hook, extension_id, hook_name, callback},
        _from,
        state
      ) do
    case HookManager.register_hook(extension_id, hook_name, callback, state) do
      {:ok, new_state} -> {:reply, :ok, new_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:unregister_hook, extension_id, hook_name}, _from, state) do
    case HookManager.unregister_hook(extension_id, hook_name, state) do
      {:ok, new_state} -> {:reply, :ok, new_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:trigger_hook, hook_name, args}, _from, state) do
    case HookManager.trigger_hook(hook_name, args, state) do
      {:ok, results} -> {:reply, {:ok, results}, state}
    end
  end

  # Catch-all clause for unexpected messages
  @impl GenServer
  def handle_call(message, _from, state) do
    Logger.warning(
      "UnifiedExtension received unexpected call: #{inspect(message)}"
    )

    {:reply, {:error, :unexpected_message}, state}
  end

  # Private Functions
  defp handle_extension_import(extension, state) do
    case extension.module do
      {:error, reason} ->
        {:reply, {:error, {:module_load_failed, reason}}, state}

      {:ok, _module} ->
        extension_id = generate_extension_id()
        new_state = put_in(state.extensions[extension_id], extension)
        {:reply, {:ok, extension_id}, new_state}

      _ ->
        extension_id = generate_extension_id()
        new_state = put_in(state.extensions[extension_id], extension)
        {:reply, {:ok, extension_id}, new_state}
    end
  end

  defp generate_extension_id do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16()
    |> binary_part(0, 8)
  end








end
