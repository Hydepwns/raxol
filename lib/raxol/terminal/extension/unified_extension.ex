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
      load_extensions_from_paths(state.extension_paths)
    end

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:load_extension, path, type, opts}, _from, state) do
    extension_id = generate_extension_id()
    extension_state = load_extension_state(path, type, opts)

    case extension_state.module do
      {:error, reason} ->
        {:reply, {:error, {:module_load_failed, reason}}, state}

      _ ->
        case validate_extension(extension_state) do
          :ok ->
            new_state = put_in(state.extensions[extension_id], extension_state)
            {:reply, {:ok, extension_id}, new_state}

          {:error, reason} ->
            {:reply, {:error, reason}, state}
        end
    end
  end

  @impl GenServer
  def handle_call({:unload_extension, extension_id}, _from, state) do
    case Map.get(state.extensions, extension_id) do
      nil ->
        {:reply, {:error, :extension_not_found}, state}

      extension ->
        # Clean up extension resources
        cleanup_extension(extension)
        new_state = update_in(state.extensions, &Map.delete(&1, extension_id))
        {:reply, :ok, new_state}
    end
  end

  @impl GenServer
  def handle_call({:get_extension_state, extension_id}, _from, state) do
    case Map.get(state.extensions, extension_id) do
      nil ->
        {:reply, {:error, :extension_not_found}, state}

      extension ->
        {:reply, {:ok, extension}, state}
    end
  end

  @impl GenServer
  def handle_call(
        {:update_extension_config, extension_id, config},
        _from,
        state
      ) do
    case Map.get(state.extensions, extension_id) do
      nil ->
        {:reply, {:error, :extension_not_found}, state}

      extension ->
        case config do
          config when is_map(config) ->
            new_extension = update_in(extension.config, &Map.merge(&1, config))
            new_state = put_in(state.extensions[extension_id], new_extension)
            {:reply, :ok, new_state}

          _ ->
            {:reply, {:error, :invalid_extension_config}, state}
        end
    end
  end

  @impl GenServer
  def handle_call({:activate_extension, extension_id}, _from, state) do
    case Map.get(state.extensions, extension_id) do
      nil ->
        {:reply, {:error, :extension_not_found}, state}

      extension ->
        handle_extension_activation(extension, extension_id, state)
    end
  end

  defp handle_extension_activation(extension, extension_id, state) do
    if extension.status == :idle do
      case initialize_extension(extension) do
        {:ok, initialized_extension} ->
          new_extension = %{initialized_extension | status: :active}
          new_state = put_in(state.extensions[extension_id], new_extension)
          {:reply, :ok, new_state}

        {:error, reason} ->
          new_extension = %{extension | status: :error, error: reason}
          new_state = put_in(state.extensions[extension_id], new_extension)
          {:reply, {:error, reason}, new_state}
      end
    else
      {:reply, {:error, :invalid_extension_state}, state}
    end
  end

  @impl GenServer
  def handle_call({:deactivate_extension, extension_id}, _from, state) do
    case Map.get(state.extensions, extension_id) do
      nil ->
        {:reply, {:error, :extension_not_found}, state}

      extension ->
        handle_extension_deactivation(extension, extension_id, state)
    end
  end

  defp handle_extension_deactivation(extension, extension_id, state) do
    if extension.status == :active do
      case deinitialize_extension(extension) do
        {:ok, deinitialized_extension} ->
          new_extension = %{deinitialized_extension | status: :idle}
          new_state = put_in(state.extensions[extension_id], new_extension)
          {:reply, :ok, new_state}

        {:error, reason} ->
          new_extension = %{extension | status: :error, error: reason}
          new_state = put_in(state.extensions[extension_id], new_extension)
          {:reply, {:error, reason}, new_state}
      end
    else
      {:reply, {:error, :invalid_extension_state}, state}
    end
  end

  @impl GenServer
  def handle_call({:execute_command, extension_id, command, args}, _from, state) do
    case Map.get(state.extensions, extension_id) do
      nil ->
        {:reply, {:error, :extension_not_found}, state}

      extension ->
        handle_command_execution(extension, extension_id, command, args, state)
    end
  end

  defp handle_command_execution(extension, extension_id, command, args, state) do
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

  @impl GenServer
  def handle_call({:get_extensions, opts}, _from, state) do
    extensions = filter_extensions(state.extensions, opts)
    {:reply, {:ok, extensions}, state}
  end

  @impl GenServer
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

  @impl GenServer
  def handle_call({:import_extension, path, opts}, _from, state) do
    case import_extension_from_path(path, opts) do
      {:ok, extension} -> handle_extension_import(extension, state)
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

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

  @impl GenServer
  def handle_call(
        {:register_hook, extension_id, hook_name, callback},
        _from,
        state
      ) do
    case Map.get(state.extensions, extension_id) do
      nil ->
        {:reply, {:error, :extension_not_found}, state}

      extension ->
        handle_hook_registration(
          extension,
          extension_id,
          hook_name,
          callback,
          state
        )
    end
  end

  defp handle_hook_registration(
         extension,
         extension_id,
         hook_name,
         callback,
         state
       ) do
    if hook_name in extension.hooks do
      callback_map = build_callback_map(callback, extension_id)

      new_hooks =
        Map.update(
          state.hooks,
          hook_name,
          [callback_map],
          &[callback_map | &1]
        )

      new_state = %{state | hooks: new_hooks}
      {:reply, :ok, new_state}
    else
      {:reply, {:error, :hook_not_found}, state}
    end
  end

  defp build_callback_map(callback, extension_id) do
    case callback do
      %{fun: _} -> callback
      fun when is_function(fun) -> %{fun: fun, extension_id: extension_id}
      _ -> %{fun: callback, extension_id: extension_id}
    end
  end

  @impl GenServer
  def handle_call({:unregister_hook, extension_id, hook_name}, _from, state) do
    case Map.get(state.extensions, extension_id) do
      nil ->
        {:reply, {:error, :extension_not_found}, state}

      extension ->
        handle_hook_unregistration(extension, extension_id, hook_name, state)
    end
  end

  defp handle_hook_unregistration(extension, extension_id, hook_name, state) do
    if hook_name in extension.hooks do
      new_hooks = remove_hook_callback(state.hooks, hook_name, extension_id)
      new_state = %{state | hooks: new_hooks}
      {:reply, :ok, new_state}
    else
      {:reply, {:error, :hook_not_found}, state}
    end
  end

  defp remove_hook_callback(hooks, hook_name, extension_id) do
    Map.update(
      hooks,
      hook_name,
      [],
      &Enum.reject(&1, fn callback ->
        callback.extension_id == extension_id
      end)
    )
  end

  @impl GenServer
  def handle_call({:trigger_hook, hook_name, args}, _from, state) do
    case Map.get(state.hooks, hook_name) do
      nil ->
        {:reply, :ok, state}

      callbacks ->
        results = execute_hook_callbacks(callbacks, args)
        {:reply, {:ok, results}, state}
    end
  end

  defp execute_hook_callbacks(callbacks, args) do
    Enum.map(callbacks, fn callback ->
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
  defp generate_extension_id do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16()
    |> binary_part(0, 8)
  end

  defp load_extension_state(path, type, opts) do
    # Try to load extension manifest first
    manifest = load_extension_manifest(path)

    # Load extension module if it exists
    module = load_extension_module(path, type)

    # Load configuration
    config = load_extension_config(path, Keyword.get(opts, :config, %{}))

    build_extension_state(path, type, opts, manifest, module, config)
  end

  defp build_extension_state(path, type, opts, manifest, module, config) do
    %{
      id: nil,
      name: get_extension_name(opts, manifest),
      type: type,
      version: get_extension_version(opts, manifest),
      description: get_extension_description(opts, manifest),
      author: get_extension_author(opts, manifest),
      license: get_extension_license(opts, manifest),
      config: config,
      status: :idle,
      error: nil,
      metadata: get_extension_metadata(opts, manifest),
      dependencies: get_extension_dependencies(opts, manifest),
      hooks: get_extension_hooks(opts, manifest),
      commands: get_extension_commands(opts, manifest),
      module: module,
      path: path,
      manifest: manifest
    }
  end

  defp get_extension_name(opts, manifest),
    do: Keyword.get(opts, :name, manifest["name"] || "Unnamed Extension")

  defp get_extension_version(opts, manifest),
    do: Keyword.get(opts, :version, manifest["version"] || "1.0.0")

  defp get_extension_description(opts, manifest),
    do: Keyword.get(opts, :description, manifest["description"] || "")

  defp get_extension_author(opts, manifest),
    do: Keyword.get(opts, :author, manifest["author"] || "Unknown")

  defp get_extension_license(opts, manifest),
    do: Keyword.get(opts, :license, manifest["license"] || "MIT")

  defp get_extension_metadata(opts, manifest),
    do: Keyword.get(opts, :metadata, manifest["metadata"] || %{})

  defp get_extension_dependencies(opts, manifest),
    do: Keyword.get(opts, :dependencies, manifest["dependencies"] || [])

  defp get_extension_hooks(opts, manifest),
    do: Keyword.get(opts, :hooks, manifest["hooks"] || [])

  defp get_extension_commands(opts, manifest),
    do: Keyword.get(opts, :commands, manifest["commands"] || [])

  defp load_extension_manifest(path) do
    manifest_path = Path.join(path, @manifest_file)

    case File.read(manifest_path) do
      {:ok, content} -> parse_json_manifest(content)
      {:error, _reason} -> %{}
    end
  end

  defp parse_json_manifest(content) do
    case Jason.decode(content) do
      {:ok, manifest} -> manifest
      {:error, _reason} -> %{}
    end
  end

  defp load_extension_module(path, type) do
    case type do
      :script -> load_script_module(path)
      :plugin -> load_plugin_module(path)
      :theme -> load_theme_module(path)
      :custom -> load_custom_module(path)
      _ -> {:error, :invalid_extension_type}
    end
  end

  defp load_script_module(path) do
    script_path = Path.join(path, @script_file)

    if File.exists?(script_path) do
      case Code.compile_file(script_path) do
        [{module, _}] -> {:ok, module}
        _ -> {:error, :compilation_failed}
      end
    else
      {:error, :script_not_found}
    end
  end

  defp load_plugin_module(path) do
    # Look for plugin files in the directory
    case File.ls(path) do
      {:ok, files} -> find_and_compile_plugin(files, path)
      {:error, _reason} -> {:error, :directory_not_found}
    end
  end

  defp find_and_compile_plugin(files, path) do
    plugin_files = Enum.filter(files, &String.ends_with?(&1, ".ex"))

    case plugin_files do
      [plugin_file | _] ->
        plugin_path = Path.join(path, plugin_file)
        compile_plugin_file(plugin_path)

      [] ->
        {:error, :no_plugin_files}
    end
  end

  defp compile_plugin_file(plugin_path) do
    case Code.compile_file(plugin_path) do
      [{module, _}] -> {:ok, module}
      _ -> {:error, :compilation_failed}
    end
  end

  defp load_theme_module(path) do
    # Themes typically have a theme.ex file
    theme_path = Path.join(path, "theme.ex")

    if File.exists?(theme_path) do
      case Code.compile_file(theme_path) do
        [{module, _}] -> {:ok, module}
        _ -> {:error, :compilation_failed}
      end
    else
      {:error, :theme_not_found}
    end
  end

  defp load_custom_module(path) do
    # Custom extensions can have any structure
    # Look for main.ex or custom.ex
    custom_paths = [
      Path.join(path, "main.ex"),
      Path.join(path, "custom.ex"),
      Path.join(path, "extension.ex")
    ]

    find_custom_module(custom_paths)
  end

  defp find_custom_module(custom_paths) do
    Enum.find_value(
      custom_paths,
      {:error, :no_custom_module},
      &try_compile_custom_path/1
    )
  end

  defp try_compile_custom_path(custom_path) do
    if File.exists?(custom_path) do
      case Code.compile_file(custom_path) do
        [{module, _}] -> {:ok, module}
        _ -> nil
      end
    end
  end

  defp load_extension_config(path, default_config) do
    config_path = Path.join(path, @config_file)

    if File.exists?(config_path) do
      try do
        {config, _} = Code.eval_file(config_path)
        Map.merge(default_config, config)
      rescue
        _ -> default_config
      end
    else
      default_config
    end
  end

  defp validate_extension(extension) do
    with :ok <- validate_extension_type(extension.type),
         :ok <- validate_extension_config(extension.config),
         :ok <- validate_extension_dependencies(extension.dependencies) do
      validate_extension_module(extension.module)
    end
  end

  defp validate_extension_type(type)
       when type in [:theme, :script, :plugin, :custom],
       do: :ok

  defp validate_extension_type(_), do: {:error, :invalid_extension_type}

  defp validate_extension_config(config) when is_map(config), do: :ok
  defp validate_extension_config(_), do: {:error, :invalid_extension_config}

  defp validate_extension_dependencies(dependencies) when is_list(dependencies),
    do: :ok

  defp validate_extension_dependencies(_),
    do: {:error, :invalid_extension_dependencies}

  defp validate_extension_module({:ok, _module}), do: :ok
  # Allow extensions without modules
  defp validate_extension_module({:error, _reason}), do: :ok
  defp validate_extension_module(nil), do: :ok
  defp validate_extension_module(_), do: {:error, :invalid_extension_module}

  defp do_execute_command(extension, command, args) do
    case extension.module do
      {:ok, module} ->
        execute_module_command(module, extension.type, command, args)

      nil ->
        execute_fallback_command(extension, command, args)

      _ ->
        execute_fallback_command(extension, command, args)
    end
  end

  defp execute_module_command(module, type, command, args) do
    try do
      execute_by_type(module, type, command, args)
    rescue
      e ->
        Logger.error("Command execution failed: #{inspect(e)}")
        {:error, :command_execution_failed}
    end
  end

  defp execute_by_type(module, :script, command, args) do
    if function_exported?(module, :execute_command, 2) do
      module.execute_command(command, args)
    else
      {:error, :command_not_implemented}
    end
  end

  defp execute_by_type(module, :plugin, command, args) do
    if function_exported?(module, :run_extension, 2) do
      module.run_extension(command, args)
    else
      {:error, :command_not_implemented}
    end
  end

  defp execute_by_type(module, :theme, _command, args) do
    if function_exported?(module, :apply_theme, 1) do
      module.apply_theme(args)
    else
      {:error, :command_not_implemented}
    end
  end

  defp execute_by_type(module, :custom, command, args) do
    if function_exported?(module, :execute_feature, 2) do
      module.execute_feature(command, args)
    else
      {:error, :command_not_implemented}
    end
  end

  defp execute_fallback_command(extension, command, args) do
    # Fallback implementation for extensions without modules
    case extension.type do
      :script ->
        {:ok, "Command \"#{command}\" executed with args: #{inspect(args)}"}

      :plugin ->
        {:ok, "Command \"#{command}\" executed with args: #{inspect(args)}"}

      :theme ->
        {:ok, "Command \"#{command}\" executed with args: #{inspect(args)}"}

      :custom ->
        {:ok, "Command \"#{command}\" executed with args: #{inspect(args)}"}
    end
  end

  defp initialize_extension(extension) do
    case extension.module do
      {:ok, module} ->
        try do
          if function_exported?(module, :init, 0) do
            module.init()
          end

          {:ok, extension}
        rescue
          e ->
            Logger.error("Extension initialization failed: #{inspect(e)}")
            {:error, :initialization_failed}
        end

      _ ->
        {:ok, extension}
    end
  end

  defp deinitialize_extension(extension) do
    case extension.module do
      {:ok, module} ->
        try do
          if function_exported?(module, :cleanup, 0) do
            module.cleanup()
          end

          {:ok, extension}
        rescue
          e ->
            Logger.error("Extension cleanup failed: #{inspect(e)}")
            {:error, :cleanup_failed}
        end

      _ ->
        {:ok, extension}
    end
  end

  defp cleanup_extension(extension) do
    case extension.module do
      {:ok, module} ->
        try do
          if function_exported?(module, :cleanup, 0) do
            module.cleanup()
          end
        rescue
          e ->
            Logger.error("Extension cleanup failed: #{inspect(e)}")
        end

      _ ->
        :ok
    end
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
    try do
      # Create export directory if it doesn't exist
      export_dir = Path.dirname(path)
      File.mkdir_p!(export_dir)

      # Export manifest
      manifest_path = path

      manifest = %{
        "name" => extension.name,
        "version" => extension.version,
        "description" => extension.description,
        "author" => extension.author,
        "license" => extension.license,
        "type" => Atom.to_string(extension.type),
        "dependencies" => extension.dependencies,
        "hooks" => extension.hooks,
        "commands" => extension.commands,
        "metadata" => extension.config
      }

      File.write!(manifest_path, Jason.encode!(manifest, pretty: true))

      # Only copy source files if export path is a directory
      unless String.ends_with?(path, ".json") do
        if extension.path && File.exists?(extension.path) do
          copy_extension_files(extension.path, path)
        end
      end

      :ok
    rescue
      e ->
        Logger.error("Extension export failed: #{inspect(e)}")
        {:error, :export_failed}
    end
  end

  defp copy_extension_files(source_path, dest_path) do
    case File.stat(source_path) do
      {:ok, %{type: :directory}} ->
        File.cp_r!(source_path, dest_path)

      {:ok, %{type: :regular}} ->
        File.cp!(source_path, dest_path)

      _ ->
        :ok
    end
  end

  defp import_extension_from_path(path, opts) do
    try do
      # Check if path is a directory or file
      case File.stat(path) do
        {:ok, %{type: :directory}} ->
          import_extension_from_directory(path, opts)

        {:ok, %{type: :regular}} ->
          import_extension_from_file(path, opts)

        _ ->
          {:error, :invalid_path}
      end
    rescue
      e ->
        Logger.error("Extension import failed: #{inspect(e)}")
        {:error, :import_failed}
    end
  end

  defp import_extension_from_directory(path, opts) do
    # Look for manifest file
    manifest_path = Path.join(path, @manifest_file)

    case File.read(manifest_path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, manifest} ->
            type = String.to_existing_atom(manifest["type"])

            {:ok,
             load_extension_state(
               path,
               type,
               Keyword.merge(opts, manifest_to_opts(manifest))
             )}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, _reason} ->
        # Try to infer type from directory structure
        inferred_type = infer_extension_type(path)
        {:ok, load_extension_state(path, inferred_type, opts)}
    end
  end

  defp import_extension_from_file(path, opts) do
    # Single file import - try to determine type from extension
    case Path.extname(path) do
      ".ex" ->
        case Code.compile_file(path) do
          [{module, _}] ->
            inferred_type = infer_type_from_module(module)
            {:ok, load_extension_state(Path.dirname(path), inferred_type, opts)}

          _ ->
            {:error, :compilation_failed}
        end

      ".json" ->
        case File.read(path) do
          {:ok, content} -> handle_json_import(content, path, opts)
          {:error, reason} -> {:error, reason}
        end

      _ ->
        {:error, :unsupported_file_type}
    end
  end

  defp handle_json_import(content, path, opts) do
    case Jason.decode(content) do
      {:ok, manifest} ->
        type = String.to_existing_atom(manifest["type"])

        # For JSON imports, use the directory containing the JSON file as the base path
        # and look for the actual extension files in a subdirectory with the same name as the type
        base_path = Path.dirname(path)
        extension_path = Path.join(base_path, Atom.to_string(type))

        # If the extension directory doesn't exist, use the base path
        final_path =
          if File.exists?(extension_path),
            do: extension_path,
            else: base_path

        {:ok,
         load_extension_state(
           final_path,
           type,
           Keyword.merge(opts, manifest_to_opts(manifest))
         )}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp manifest_to_opts(manifest) do
    [
      name: manifest["name"],
      version: manifest["version"],
      description: manifest["description"],
      author: manifest["author"],
      license: manifest["license"],
      dependencies: manifest["dependencies"],
      hooks: manifest["hooks"],
      commands: manifest["commands"],
      metadata: manifest["metadata"]
    ]
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp infer_extension_type(path) do
    case File.ls(path) do
      {:ok, files} ->
        cond do
          Enum.any?(files, &String.contains?(&1, "theme")) -> :theme
          Enum.any?(files, &String.contains?(&1, "script")) -> :script
          Enum.any?(files, &String.contains?(&1, "plugin")) -> :plugin
          true -> :custom
        end

      {:error, _reason} ->
        :custom
    end
  end

  defp infer_type_from_module(module) do
    cond do
      function_exported?(module, :theme_info, 0) -> :theme
      function_exported?(module, :script_info, 0) -> :script
      function_exported?(module, :plugin_info, 0) -> :plugin
      function_exported?(module, :extension_info, 0) -> :plugin
      true -> :custom
    end
  end

  defp load_extensions_from_paths(paths) do
    Enum.each(paths, fn path ->
      case File.stat(path) do
        {:ok, %{type: :directory}} ->
          load_extensions_from_directory(path)

        {:ok, %{type: :regular}} ->
          load_extension_from_file(path)

        _ ->
          Logger.warning("Invalid extension path: #{path}")
      end
    end)
  end

  defp load_extensions_from_directory(path) do
    case File.ls(path) do
      {:ok, entries} ->
        Enum.each(entries, &process_directory_entry(&1, path))

      {:error, reason} ->
        Logger.error("Failed to list directory #{path}: #{inspect(reason)}")
    end
  end

  defp process_directory_entry(entry, path) do
    entry_path = Path.join(path, entry)

    case File.stat(entry_path) do
      {:ok, %{type: :directory}} ->
        load_extension_from_directory(entry_path)

      {:ok, %{type: :regular}} ->
        load_extension_from_file(entry_path)

      _ ->
        :ok
    end
  end

  defp load_extension_from_directory(path) do
    # Check for manifest file to determine type
    manifest_path = Path.join(path, @manifest_file)

    case File.read(manifest_path) do
      {:ok, content} ->
        handle_manifest_parse(content, path)

      {:error, _reason} ->
        # Try to infer type
        inferred_type = infer_extension_type(path)
        load_extension(path, inferred_type, [])
    end
  end

  defp handle_manifest_parse(content, path) do
    case Jason.decode(content) do
      {:ok, manifest} ->
        type = String.to_existing_atom(manifest["type"])
        load_extension(path, type, manifest_to_opts(manifest))

      {:error, reason} ->
        Logger.error("Failed to parse manifest in #{path}: #{inspect(reason)}")
    end
  end

  defp load_extension_from_file(path) do
    case Path.extname(path) do
      ".ex" ->
        case Code.compile_file(path) do
          [{module, _}] ->
            inferred_type = infer_type_from_module(module)
            load_extension(Path.dirname(path), inferred_type, [])

          _ ->
            Logger.error("Failed to compile extension file: #{path}")
        end

      ".json" ->
        case File.read(path) do
          {:ok, content} ->
            handle_json_file_parse(content, path)

          {:error, reason} ->
            Logger.error(
              "Failed to read file: #{path}, reason: #{inspect(reason)}"
            )
        end

      _ ->
        :ok
    end
  end

  defp handle_json_file_parse(content, path) do
    case Jason.decode(content) do
      {:ok, manifest} ->
        type = String.to_existing_atom(manifest["type"])

        load_extension(
          Path.dirname(path),
          type,
          manifest_to_opts(manifest)
        )

      {:error, reason} ->
        Logger.error(
          "Failed to parse JSON file: #{path}, reason: #{inspect(reason)}"
        )
    end
  end
end
