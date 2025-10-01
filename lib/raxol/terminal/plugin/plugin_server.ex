defmodule Raxol.Terminal.Plugin.PluginServer do
  @moduledoc """
  Unified plugin system for the Raxol terminal emulator.
  Handles themes, scripting, and extensions.

  Refactored version with pure functional error handling patterns.
  All try/catch blocks have been replaced with with statements and proper error tuples.
  """

  use Raxol.Core.Behaviours.BaseManager
  alias Raxol.Core.Runtime.Log
  # Types
  @type plugin_id :: String.t()
  @type plugin_type :: :theme | :script | :extension
  @type plugin_state :: %{
          id: plugin_id(),
          type: plugin_type(),
          name: String.t(),
          version: String.t(),
          description: String.t(),
          author: String.t(),
          dependencies: [String.t()],
          config: map(),
          status: :active | :inactive | :error,
          error: String.t() | nil
        }

  # Client API
  # BaseManager provides start_link/1 automatically with name: __MODULE__ as default

  @doc """
  Loads a plugin from a file or directory.
  """
  def load_plugin(path, type, opts \\ []) do
    GenServer.call(__MODULE__, {:load_plugin, path, type, opts})
  end

  @doc """
  Unloads a plugin by ID.
  """
  def unload_plugin(plugin_id) do
    GenServer.call(__MODULE__, {:unload_plugin, plugin_id})
  end

  @doc """
  Gets the state of a plugin.
  """
  def get_plugin_state(plugin_id) do
    GenServer.call(__MODULE__, {:get_plugin_state, plugin_id})
  end

  @doc """
  Gets all loaded plugins.
  """
  def get_plugins(opts \\ []) do
    GenServer.call(__MODULE__, {:get_plugins, opts})
  end

  @doc """
  Updates a plugin's configuration.
  """
  def update_plugin_config(plugin_id, config) do
    GenServer.call(__MODULE__, {:update_plugin_config, plugin_id, config})
  end

  @doc """
  Executes a plugin function.
  """
  def execute_plugin_function(plugin_id, function, args \\ []) do
    GenServer.call(
      __MODULE__,
      {:execute_plugin_function, plugin_id, function, args}
    )
  end

  @doc """
  Reloads a plugin.
  """
  def reload_plugin(plugin_id) do
    GenServer.call(__MODULE__, {:reload_plugin, plugin_id})
  end

  # Server Callbacks
  @impl true
  def init_manager(opts) do
    opts_map = Map.new(opts)

    state = %{
      plugins: %{},
      plugin_paths: Map.get(opts_map, :plugin_paths, []),
      auto_load: Map.get(opts_map, :auto_load, true),
      plugin_config: Map.get(opts_map, :plugin_config, %{})
    }

    auto_load_plugins_if_enabled(state.auto_load, state.plugin_paths)

    {:ok, state}
  end

  @impl true
  def handle_manager_call({:load_plugin, path, type, opts}, _from, state) do
    case do_load_plugin(path, type, opts, state) do
      {:ok, plugin_id, plugin_state} ->
        new_state = put_in(state.plugins[plugin_id], plugin_state)
        {:reply, {:ok, plugin_id}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_manager_call({:unload_plugin, plugin_id}, _from, state) do
    case do_unload_plugin(plugin_id, state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_manager_call({:get_plugin_state, plugin_id}, _from, state) do
    case Map.get(state.plugins, plugin_id) do
      nil -> {:reply, {:error, :plugin_not_found}, state}
      plugin_state -> {:reply, {:ok, plugin_state}, state}
    end
  end

  @impl true
  def handle_manager_call({:get_plugins, opts}, _from, state) do
    plugins = filter_plugins(state.plugins, opts)
    {:reply, {:ok, plugins}, state}
  end

  @impl true
  def handle_manager_call(
        {:update_plugin_config, plugin_id, config},
        _from,
        state
      ) do
    case do_update_plugin_config(plugin_id, config, state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_manager_call(
        {:execute_plugin_function, plugin_id, function, args},
        _from,
        state
      ) do
    case Map.get(state.plugins, plugin_id) do
      nil ->
        {:reply, {:error, :plugin_not_found}, state}

      plugin_state ->
        result = execute_function(plugin_state, function, args)
        {:reply, result, state}
    end
  end

  @impl true
  def handle_manager_call({:reload_plugin, plugin_id}, _from, state) do
    case do_reload_plugin(plugin_id, state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}

      {:error, reason, new_state} ->
        {:reply, {:error, reason, new_state}, new_state}
    end
  end

  # Private Functions
  defp do_load_plugin(path, type, opts, state) do
    with {:ok, plugin_state} <- load_plugin_state(path, type, opts),
         :ok <- validate_plugin(plugin_state),
         :ok <- check_dependencies(plugin_state, state.plugins) do
      {:ok, plugin_state.id, plugin_state}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp do_unload_plugin(plugin_id, state) do
    case Map.get(state.plugins, plugin_id) do
      nil ->
        {:error, :plugin_not_found}

      plugin_state ->
        with :ok <- cleanup_plugin(plugin_state) do
          new_plugins = Map.delete(state.plugins, plugin_id)
          {:ok, %{state | plugins: new_plugins}}
        else
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp do_update_plugin_config(plugin_id, config, state) do
    case Map.get(state.plugins, plugin_id) do
      nil ->
        {:error, :plugin_not_found}

      plugin_state ->
        with :ok <- validate_plugin_config(config) do
          updated_plugin = %{plugin_state | config: config}
          new_plugins = Map.put(state.plugins, plugin_id, updated_plugin)
          {:ok, %{state | plugins: new_plugins}}
        else
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp do_reload_plugin(plugin_id, state) do
    case Map.get(state.plugins, plugin_id) do
      nil ->
        {:error, :plugin_not_found}

      plugin_state ->
        case reload_plugin_attempt(plugin_state, state.plugins) do
          {:ok, new_plugin_state} ->
            new_plugins = Map.put(state.plugins, plugin_id, new_plugin_state)
            {:ok, %{state | plugins: new_plugins}}

          {:error, reason} ->
            error_plugin_state = %{
              plugin_state
              | status: :error,
                error: inspect(reason)
            }

            new_plugins = Map.put(state.plugins, plugin_id, error_plugin_state)
            new_state = %{state | plugins: new_plugins}
            {:error, :reload_failed, new_state}
        end
    end
  end

  defp reload_plugin_attempt(plugin_state, loaded_plugins) do
    with :ok <- cleanup_plugin(plugin_state),
         {:ok, new_plugin_state} <-
           load_plugin_state(
             plugin_state.path,
             plugin_state.type,
             plugin_state.config
           ),
         :ok <- validate_plugin(new_plugin_state),
         :ok <- check_dependencies(new_plugin_state, loaded_plugins) do
      {:ok, new_plugin_state}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp generate_plugin_id(path) do
    {:ok, :crypto.hash(:sha256, path) |> Base.encode16()}
  end

  defp load_plugin_state(path, type, opts) do
    case type do
      :theme -> load_theme_plugin(path, opts)
      :script -> load_script_plugin(path, opts)
      :extension -> load_extension_plugin(path, opts)
      _ -> {:error, :invalid_plugin_type}
    end
  end

  defp validate_plugin(plugin_state) do
    required_fields = [:id, :type, :name, :version, :description, :author]

    case Enum.all?(required_fields, &Map.has_key?(plugin_state, &1)) do
      true -> :ok
      false -> {:error, :invalid_plugin_format}
    end
  end

  defp check_dependencies(plugin_state, loaded_plugins) do
    # Check if all dependencies exist by looking up plugin names
    dependency_satisfied? = fn dep_name ->
      Enum.any?(loaded_plugins, fn {_id, plugin} ->
        plugin.name == dep_name and plugin.status == :active
      end)
    end

    case Enum.all?(plugin_state.dependencies, dependency_satisfied?) do
      true -> :ok
      false -> {:error, :module_not_found}
    end
  end

  defp cleanup_plugin(plugin_state) do
    case plugin_state.type do
      :theme -> cleanup_theme_plugin(plugin_state)
      :script -> cleanup_script_plugin(plugin_state)
      :extension -> cleanup_extension_plugin(plugin_state)
    end
  end

  defp validate_plugin_config(config) do
    case is_map(config) do
      true -> :ok
      false -> {:error, :invalid_config_format}
    end
  end

  defp execute_function(plugin_state, function, args) do
    case plugin_state.type do
      :theme -> execute_theme_function(plugin_state, function, args)
      :script -> execute_script_function(plugin_state, function, args)
      :extension -> execute_extension_function(plugin_state, function, args)
    end
  end

  defp filter_plugins(plugins, opts) do
    plugins
    |> Enum.filter(fn {_id, plugin} ->
      Enum.all?(opts, fn
        {:type, type} -> plugin.type == type
        {:status, status} -> plugin.status == status
        _ -> true
      end)
    end)
    |> Map.new()
  end

  defp load_plugins_from_paths(paths) do
    Enum.each(paths, &process_plugin_path/1)
  end

  defp process_plugin_path(path) do
    case File.ls(path) do
      {:ok, files} -> Enum.each(files, &process_plugin_file(path, &1))
      {:error, reason} -> log_plugin_directory_error(path, reason)
    end
  end

  defp process_plugin_file(directory, file) do
    file_path = Path.join(directory, file)

    with {:ok, type} <- determine_plugin_type(file),
         {:ok, _plugin_id} <- load_plugin(file_path, type) do
      :ok
    else
      {:error, reason} ->
        Log.module_debug("Skipping #{file}: #{inspect(reason)}")
    end
  end

  defp determine_plugin_type(file) do
    Enum.find_value(
      [
        {".theme.json", :theme},
        {".script.ex", :script},
        {".extension", :extension}
      ],
      {:error, :unknown_type},
      fn {extension, type} ->
        check_file_extension(file, extension, type)
      end
    )
  end

  defp log_plugin_directory_error(path, reason) do
    Log.module_error(
      "Failed to read plugin directory #{path}: #{inspect(reason)}"
    )
  end

  # Theme Plugin Functions
  defp load_theme_plugin(path, opts) do
    opts = normalize_opts_to_list(opts)

    with {:ok, theme_config} <- load_theme_config(path),
         {:ok, theme_module} <- load_theme_module(path),
         {:ok, plugin_id} <- generate_plugin_id(path) do
      theme_state = %{
        id: plugin_id,
        type: :theme,
        name: Keyword.get(opts, :name, theme_config[:name] || "Unnamed Theme"),
        version: Keyword.get(opts, :version, theme_config[:version] || "1.0.0"),
        description:
          Keyword.get(opts, :description, theme_config[:description] || ""),
        author: Keyword.get(opts, :author, theme_config[:author] || "Unknown"),
        dependencies:
          Keyword.get(opts, :dependencies, theme_config[:dependencies] || []),
        config: theme_config,
        status: :active,
        error: nil,
        module: theme_module,
        path: path
      }

      {:ok, theme_state}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp load_theme_config(path) do
    config_path = get_theme_config_path(path)

    with {:ok, content} <- File.read(config_path),
         {:ok, config} <- safe_json_decode(content) do
      {:ok, config}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp safe_json_decode(content) do
    Raxol.Core.ErrorHandling.safe_call(fn ->
      case Jason.decode(content, keys: :atoms) do
        {:ok, decoded} -> {:ok, decoded}
        {:error, _} -> {:error, :invalid_json}
      end
    end)
    |> case do
      {:ok, result} -> result
      {:error, _} -> {:error, :json_decode_failed}
    end
  end

  defp load_theme_module(path) do
    module_path = get_theme_module_path(path)
    load_module_if_exists(module_path)
  end

  defp safe_load_module(path) do
    with {:ok, content} <- File.read(path),
         {:ok, module} <- safe_compile_module(content) do
      {:ok, module}
    else
      error -> error
    end
  end

  defp safe_compile_module(content) do
    case Code.string_to_quoted(content) do
      {:ok, ast} ->
        case safe_compile_quoted(ast) do
          {:ok, module} -> {:ok, module}
          error -> error
        end

      {:error, _} ->
        {:error, :invalid_code}
    end
  end

  defp safe_compile_quoted(ast) do
    compiled = Code.compile_quoted(ast)

    Raxol.Core.ErrorHandling.safe_call(fn ->
      case compiled do
        [{module, _bin} | _] -> {:ok, module}
        _ -> {:error, :compilation_failed}
      end
    end)
    |> case do
      {:ok, result} ->
        result

      {:error, error} ->
        Log.module_error("Compilation failed: #{inspect(error)}")
        {:error, :compilation_failed}
    end
  end

  defp cleanup_theme_plugin(plugin_state) do
    case plugin_state.module do
      nil ->
        :ok

      module ->
        safe_call_cleanup(module, plugin_state.config, "theme")
    end
  end

  defp safe_call_cleanup(module, config, plugin_type) do
    call_cleanup_if_exported(module, config, plugin_type)
  end

  defp execute_theme_function(plugin_state, function, args) do
    case plugin_state.module do
      nil ->
        {:error, :module_not_loaded}

      module ->
        safe_execute_function(module, function, args, "theme")
    end
  end

  defp safe_execute_function(module, function, args, plugin_type) do
    execute_function_if_exported(module, function, args, plugin_type)
  end

  # Script Plugin Functions
  defp load_script_plugin(path, opts) do
    opts = normalize_opts(opts)

    case handle_script_path(path) do
      {:ok, script_path} -> load_script_from_file(script_path, opts)
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_opts(opts) do
    normalize_opts_format(opts)
  end

  defp handle_script_path(path) do
    case {File.dir?(path), File.exists?(path)} do
      {true, _} -> find_script_in_directory(path)
      {false, false} -> {:error, :file_not_found}
      {false, true} -> {:ok, path}
    end
  end

  defp find_script_in_directory(path) do
    script_file = find_script_file(path)

    validate_script_file(script_file)
  end

  defp find_script_file(path) do
    Enum.find_value(
      ["script.ex", "script.exs"],
      nil,
      fn filename ->
        full_path = Path.join(path, filename)
        check_script_file_exists(full_path)
      end
    )
  end

  defp load_script_from_file(path, opts) do
    with {:ok, script_content} <- File.read(path),
         {:ok, script_module} <- compile_script(script_content),
         {:ok, plugin_id} <- generate_plugin_id(path) do
      script_state = build_script_state(plugin_id, script_module, path, opts)
      {:ok, script_state}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_script_state(plugin_id, script_module, path, opts) do
    %{
      id: plugin_id,
      type: :script,
      name: Keyword.get(opts, :name, "Unnamed Script"),
      version: Keyword.get(opts, :version, "1.0.1"),
      description: Keyword.get(opts, :description, ""),
      author: Keyword.get(opts, :author, "Unknown"),
      dependencies: Keyword.get(opts, :dependencies, []),
      config: Keyword.get(opts, :config, %{}),
      status: :active,
      error: nil,
      module: script_module,
      path: path
    }
  end

  defp compile_script(content) do
    safe_compile_module(content)
  end

  defp cleanup_script_plugin(plugin_state) do
    case plugin_state.module do
      nil ->
        :ok

      module ->
        safe_call_cleanup(module, plugin_state.config, "script")
    end
  end

  defp execute_script_function(plugin_state, function, args) do
    case plugin_state.module do
      nil ->
        {:error, :module_not_loaded}

      module ->
        safe_execute_function(module, function, args, "script")
    end
  end

  # Extension Plugin Functions
  defp load_extension_plugin(path, opts) do
    opts = normalize_opts_to_list(opts)

    with {:ok, extension_config} <- load_extension_config(path),
         {:ok, extension_module} <- load_extension_module(path),
         {:ok, plugin_id} <- generate_plugin_id(path) do
      extension_state = %{
        id: plugin_id,
        type: :extension,
        name: Keyword.get(opts, :name, "Unnamed Extension"),
        version: Keyword.get(opts, :version, "1.0.1"),
        description: Keyword.get(opts, :description, ""),
        author: Keyword.get(opts, :author, "Unknown"),
        dependencies: Keyword.get(opts, :dependencies, []),
        config: extension_config,
        status: :active,
        error: nil,
        module: extension_module,
        path: path
      }

      {:ok, extension_state}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp load_extension_config(path) do
    config_path = get_extension_config_path(path)

    with {:ok, content} <- File.read(config_path),
         {:ok, config} <- safe_json_decode(content) do
      {:ok, config}
    else
      {:error, _reason} ->
        # Default config if file doesn't exist
        {:ok, %{}}
    end
  end

  defp load_extension_module(path) do
    module_path = get_extension_module_path(path)
    load_module_if_exists(module_path)
  end

  defp cleanup_extension_plugin(plugin_state) do
    case plugin_state.module do
      nil ->
        :ok

      module ->
        safe_call_cleanup(module, plugin_state.config, "extension")
    end
  end

  defp execute_extension_function(plugin_state, function, args) do
    case plugin_state.module do
      nil ->
        {:error, :module_not_loaded}

      module ->
        safe_execute_function(module, function, args, "extension")
    end
  end

  # Safe function application helper using functional error handling
  defp safe_apply(module, function, args) do
    Raxol.Core.ErrorHandling.safe_call(fn ->
      apply(module, function, args)
    end)
    |> case do
      {:ok, result} -> {:ok, result}
      {:error, {:exit, reason}} -> {:error, {:exit, reason}}
      {:error, {:throw, thrown}} -> {:error, {:throw, thrown}}
      {:error, error} -> {:error, error}
    end
  end

  ## Helper functions for refactored if statements

  defp auto_load_plugins_if_enabled(true, plugin_paths) do
    load_plugins_from_paths(plugin_paths)
  end

  defp auto_load_plugins_if_enabled(false, _plugin_paths), do: :ok

  defp check_file_extension(file, extension, type) do
    case String.ends_with?(file, extension) do
      true -> type
      false -> nil
    end
  end

  defp get_theme_config_path(path) do
    case File.dir?(path) do
      true -> Path.join(path, "theme.json")
      false -> Path.dirname(path) |> Path.join("theme.json")
    end
  end

  defp get_theme_module_path(path) do
    case File.dir?(path) do
      true -> Path.join(path, "theme.ex")
      false -> Path.dirname(path) |> Path.join("theme.ex")
    end
  end

  defp load_module_if_exists(module_path) do
    case File.exists?(module_path) do
      true -> safe_load_module(module_path)
      false -> {:ok, nil}
    end
  end

  defp call_cleanup_if_exported(module, config, plugin_type) do
    case function_exported?(module, :cleanup, 1) do
      true ->
        Raxol.Core.ErrorHandling.safe_call(fn -> module.cleanup(config) end)
        |> case do
          {:ok, result} ->
            result

          {:error, error} ->
            Log.module_error("#{plugin_type} cleanup failed: #{inspect(error)}")
            {:error, :cleanup_failed}
        end

      false ->
        :ok
    end
  end

  defp execute_function_if_exported(module, function, args, plugin_type) do
    case function_exported?(module, function, length(args)) do
      true ->
        safe_apply(module, function, args)

      false ->
        Log.module_warning(
          "Function #{function}/#{length(args)} not exported from #{plugin_type} module"
        )

        {:error, :function_not_exported}
    end
  end

  defp normalize_opts_format(opts) when is_map(opts) do
    Enum.into(opts, [])
  end

  defp normalize_opts_format(opts), do: opts

  defp normalize_opts_to_list(opts) when is_map(opts) do
    Enum.into(opts, [])
  end

  defp normalize_opts_to_list(opts), do: opts

  defp validate_script_file(nil), do: {:error, :script_not_found}
  defp validate_script_file(script_file), do: {:ok, script_file}

  defp check_script_file_exists(full_path) do
    case File.exists?(full_path) do
      true -> full_path
      false -> nil
    end
  end

  defp get_extension_config_path(path) do
    case File.dir?(path) do
      true -> Path.join(path, "extension.json")
      false -> Path.dirname(path) |> Path.join("extension.json")
    end
  end

  defp get_extension_module_path(path) do
    case File.dir?(path) do
      true -> Path.join(path, "extension.ex")
      false -> Path.dirname(path) |> Path.join("extension.ex")
    end
  end
end
