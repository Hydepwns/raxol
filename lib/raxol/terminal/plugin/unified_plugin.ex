defmodule Raxol.Terminal.Plugin.UnifiedPlugin do
  @moduledoc """
  Unified plugin system for the Raxol terminal emulator.
  Handles themes, scripting, and extensions.
  """

  use GenServer
  require Logger

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
  def start_link(opts \\ []) do
    opts = if is_map(opts), do: Enum.into(opts, []), else: opts
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

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
  def init(opts) do
    opts_map = Map.new(opts)

    state = %{
      plugins: %{},
      plugin_paths: Map.get(opts_map, :plugin_paths, []),
      auto_load: Map.get(opts_map, :auto_load, true),
      plugin_config: Map.get(opts_map, :plugin_config, %{})
    }

    if state.auto_load do
      load_plugins_from_paths(state.plugin_paths)
    end

    {:ok, state}
  end

  def handle_call({:load_plugin, path, type, opts}, _from, state) do
    case do_load_plugin(path, type, opts, state) do
      {:ok, plugin_id, plugin_state} ->
        new_state = put_in(state.plugins[plugin_id], plugin_state)
        {:reply, {:ok, plugin_id}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:unload_plugin, plugin_id}, _from, state) do
    case do_unload_plugin(plugin_id, state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:get_plugin_state, plugin_id}, _from, state) do
    case Map.get(state.plugins, plugin_id) do
      nil -> {:reply, {:error, :plugin_not_found}, state}
      plugin_state -> {:reply, {:ok, plugin_state}, state}
    end
  end

  def handle_call({:get_plugins, opts}, _from, state) do
    plugins = filter_plugins(state.plugins, opts)
    {:reply, {:ok, plugins}, state}
  end

  def handle_call({:update_plugin_config, plugin_id, config}, _from, state) do
    case do_update_plugin_config(plugin_id, config, state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(
        {:execute_plugin_function, plugin_id, function, args},
        _from,
        state
      ) do
    case do_execute_plugin_function(plugin_id, function, args, state) do
      {:ok, result} ->
        {:reply, {:ok, result}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:reload_plugin, plugin_id}, _from, state) do
    case do_reload_plugin(plugin_id, state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  # Private Functions
  defp do_load_plugin(path, type, opts, state) do
    with {:ok, plugin_id} <- generate_plugin_id(path),
         {:ok, plugin_state} <- load_plugin_state(path, type, opts),
         :ok <- validate_plugin(plugin_state) do
      # Check dependencies and set status accordingly
      case check_dependencies(plugin_state, state.plugins) do
        :ok ->
          {:ok, plugin_id, plugin_state}

        {:error, :module_not_found} ->
          # Plugin loads but is inactive due to missing dependencies
          inactive_plugin_state = %{plugin_state | status: :inactive}
          {:ok, plugin_id, inactive_plugin_state}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp do_unload_plugin(plugin_id, state) do
    case Map.get(state.plugins, plugin_id) do
      nil ->
        {:error, :plugin_not_found}

      plugin_state ->
        case cleanup_plugin(plugin_state) do
          :ok ->
            new_state = update_in(state.plugins, &Map.delete(&1, plugin_id))
            {:ok, new_state}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp do_update_plugin_config(plugin_id, config, state) do
    case Map.get(state.plugins, plugin_id) do
      nil ->
        {:error, :plugin_not_found}

      plugin_state ->
        case validate_plugin_config(config) do
          :ok ->
            new_plugin_state = put_in(plugin_state.config, config)
            new_state = put_in(state.plugins[plugin_id], new_plugin_state)
            {:ok, new_state}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp do_execute_plugin_function(plugin_id, function, args, state) do
    case Map.get(state.plugins, plugin_id) do
      nil ->
        {:error, :plugin_not_found}

      plugin_state ->
        case plugin_state.status do
          :active ->
            execute_function(plugin_state, function, args)

          :inactive ->
            {:error, :plugin_inactive}

          :error ->
            {:error, :plugin_error}
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
            new_state = put_in(state.plugins[plugin_id], new_plugin_state)
            {:ok, new_state}

          {:error, _reason} ->
            # Set plugin status to error and return reload_failed
            error_plugin_state = %{
              plugin_state
              | status: :error,
                error: :reload_failed
            }

            _new_state = put_in(state.plugins[plugin_id], error_plugin_state)
            {:error, :reload_failed}
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
    case Enum.all?(plugin_state.dependencies, &Map.has_key?(loaded_plugins, &1)) do
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

  defp process_plugin_file(base_path, file) do
    full_path = Path.join(base_path, file)

    if File.dir?(full_path) do
      load_plugin_from_directory(full_path)
    else
      load_plugin_from_file(full_path)
    end
  end

  defp log_plugin_directory_error(path, reason) do
    Logger.error("Failed to list plugin directory #{path}: #{reason}")
  end

  defp load_plugin_from_directory(path) do
    with {:ok, plugin_type} <- determine_directory_plugin_type(path),
         {:ok, config} <- load_plugin_config(path) do
      load_plugin_state(path, plugin_type, config)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp determine_directory_plugin_type(path) do
    cond do
      File.exists?(Path.join(path, "theme.ex")) -> {:ok, :theme}
      File.exists?(Path.join(path, "extension.ex")) -> {:ok, :extension}
      File.exists?(Path.join(path, "script.ex")) -> {:ok, :script}
      true -> {:error, :unknown_plugin_type}
    end
  end

  defp load_plugin_config(path) do
    config_path = Path.join(path, "config.exs")

    if File.exists?(config_path) do
      Code.eval_file(config_path)
    else
      {:ok, %{}}
    end
  end

  defp load_plugin_from_file(path) do
    case Path.extname(path) do
      ".ex" -> load_elixir_plugin(path)
      ".exs" -> load_script_plugin(path, [])
      _ -> {:error, :unsupported_file_type}
    end
  end

  defp load_elixir_plugin(path) do
    with {:ok, module} <- Code.compile_file(path),
         {:ok, plugin_type} <- determine_plugin_type(module) do
      load_plugin_state(path, plugin_type, [])
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp determine_plugin_type(module) do
    cond do
      function_exported?(module, :theme_info, 0) -> {:ok, :theme}
      function_exported?(module, :extension_info, 0) -> {:ok, :extension}
      true -> {:error, :unknown_plugin_type}
    end
  end

  # Theme Plugin Functions
  defp load_theme_plugin(path, opts) do
    opts = if is_map(opts), do: Enum.into(opts, []), else: opts

    with {:ok, theme_config} <- load_theme_config(path),
         {:ok, theme_module} <- load_theme_module(path),
         {:ok, plugin_id} <- generate_plugin_id(path) do
      theme_state = %{
        id: plugin_id,
        type: :theme,
        name: Keyword.get(opts, :name, "Unnamed Theme"),
        version: Keyword.get(opts, :version, "1.0.0"),
        description: Keyword.get(opts, :description, ""),
        author: Keyword.get(opts, :author, "Unknown"),
        dependencies: Keyword.get(opts, :dependencies, []),
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

  defp cleanup_theme_plugin(plugin_state) do
    case plugin_state.module do
      nil ->
        :ok

      module ->
        try do
          if function_exported?(module, :cleanup, 1) do
            module.cleanup(plugin_state.config)
          end

          :ok
        rescue
          e ->
            Logger.error("Failed to cleanup theme plugin: #{inspect(e)}")
            {:error, :cleanup_failed}
        end
    end
  end

  defp execute_theme_function(plugin_state, function, args) do
    case plugin_state.module do
      nil ->
        {:error, :module_not_loaded}

      module ->
        try do
          if function_exported?(module, function, length(args)) do
            result = apply(module, function, args)

            case result do
              {:ok, unwrapped_result} -> {:ok, unwrapped_result}
              {:error, reason} -> {:error, reason}
              other -> {:ok, other}
            end
          else
            {:error, :function_not_exported}
          end
        rescue
          e ->
            Logger.error("Failed to execute theme function: #{inspect(e)}")
            {:error, :execution_failed}
        end
    end
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
    if is_map(opts), do: Enum.into(opts, []), else: opts
  end

  defp handle_script_path(path) do
    cond do
      File.dir?(path) -> find_script_in_directory(path)
      not File.exists?(path) -> {:error, :file_not_found}
      true -> {:ok, path}
    end
  end

  defp find_script_in_directory(path) do
    script_file = find_script_file(path)

    if script_file do
      {:ok, script_file}
    else
      {:error, :invalid_plugin_format}
    end
  end

  defp find_script_file(path) do
    cond do
      File.exists?(Path.join(path, "script.ex")) ->
        Path.join(path, "script.ex")

      File.exists?(Path.join(path, "script.exs")) ->
        Path.join(path, "script.exs")

      true ->
        nil
    end
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
      version: Keyword.get(opts, :version, "1.0.0"),
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
    try do
      {:ok, ast} = Code.string_to_quoted(content)
      compiled = Code.compile_quoted(ast)

      case compiled do
        [{module, _bin} | _] -> {:ok, module}
        _ -> {:error, :compilation_failed}
      end
    rescue
      e ->
        Logger.error("Failed to compile script: #{inspect(e)}")
        {:error, :compilation_failed}
    end
  end

  defp cleanup_script_plugin(plugin_state) do
    case plugin_state.module do
      nil ->
        :ok

      module ->
        try do
          if function_exported?(module, :cleanup, 1) do
            module.cleanup(plugin_state.config)
          end

          :ok
        rescue
          e ->
            Logger.error("Failed to cleanup script plugin: #{inspect(e)}")
            {:error, :cleanup_failed}
        end
    end
  end

  defp execute_script_function(plugin_state, function, args) do
    case plugin_state.module do
      nil ->
        {:error, :module_not_loaded}

      module ->
        try do
          if function_exported?(module, function, length(args)) do
            result = apply(module, function, args)

            case result do
              {:ok, unwrapped_result} -> {:ok, unwrapped_result}
              {:error, reason} -> {:error, reason}
              other -> {:ok, other}
            end
          else
            {:error, :function_not_exported}
          end
        rescue
          e ->
            Logger.error("Failed to execute script function: #{inspect(e)}")
            {:error, :execution_failed}
        end
    end
  end

  # Extension Plugin Functions
  defp load_extension_plugin(path, opts) do
    opts = if is_map(opts), do: Enum.into(opts, []), else: opts

    with {:ok, extension_config} <- load_extension_config(path),
         {:ok, extension_module} <- load_extension_module(path),
         {:ok, plugin_id} <- generate_plugin_id(path) do
      extension_state = %{
        id: plugin_id,
        type: :extension,
        name: Keyword.get(opts, :name, "Unnamed Extension"),
        version: Keyword.get(opts, :version, "1.0.0"),
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

  defp cleanup_extension_plugin(plugin_state) do
    case plugin_state.module do
      nil ->
        :ok

      module ->
        try do
          if function_exported?(module, :cleanup, 1) do
            module.cleanup(plugin_state.config)
          end

          :ok
        rescue
          e ->
            Logger.error("Failed to cleanup extension plugin: #{inspect(e)}")
            {:error, :cleanup_failed}
        end
    end
  end

  defp execute_extension_function(plugin_state, function, args) do
    case plugin_state.module do
      nil ->
        {:error, :module_not_loaded}

      module ->
        try do
          if function_exported?(module, function, length(args)) do
            result = apply(module, function, args)

            case result do
              {:ok, unwrapped_result} -> {:ok, unwrapped_result}
              {:error, reason} -> {:error, reason}
              other -> {:ok, other}
            end
          else
            {:error, :function_not_exported}
          end
        rescue
          e ->
            Logger.error("Failed to execute extension function: #{inspect(e)}")
            {:error, :execution_failed}
        end
    end
  end

  # Helper Functions
  defp load_theme_config(path) do
    config_path = Path.join(path, "theme.exs")

    case File.exists?(config_path) do
      true -> Code.eval_file(config_path)
      false -> {:ok, %{}}
    end
  end

  defp load_theme_module(path) do
    module_path = Path.join(path, "theme.ex")

    case File.exists?(module_path) do
      true ->
        case Code.compile_file(module_path) do
          [{module, _bin} | _] -> {:ok, module}
          _ -> {:error, :invalid_plugin_format}
        end

      false ->
        {:error, :invalid_plugin_format}
    end
  end

  defp load_extension_config(path) do
    config_path = Path.join(path, "config.exs")

    case File.exists?(config_path) do
      true -> Code.eval_file(config_path)
      false -> {:ok, %{}}
    end
  end

  defp load_extension_module(path) do
    module_path = Path.join(path, "extension.ex")

    case File.exists?(module_path) do
      true ->
        case Code.compile_file(module_path) do
          [{module, _bin} | _] -> {:ok, module}
          _ -> {:error, :invalid_plugin_format}
        end

      false ->
        {:error, :invalid_plugin_format}
    end
  end
end
