defmodule Raxol.Plugins.Lifecycle do
  @moduledoc """
  Handles the lifecycle management of Raxol plugins.

  This includes loading, unloading, enabling, disabling, and managing
  dependencies and configuration persistence.
  """

  require Raxol.Core.Runtime.Log
  import Raxol.Guards

  # Alias necessary modules
  alias Raxol.Plugins.{PluginConfig, PluginDependency, Manager.Core}
  alias Raxol.Core.Runtime.Plugins.DependencyManager

  @doc """
  Loads a single plugin module and initializes it.

  Handles configuration merging, API compatibility checks, dependency checks,
  and saving the updated configuration.
  Returns `{:ok, updated_manager}` or `{:error, reason}`.
  """
  @spec load_plugin(Core.t(), atom(), map()) ::
          {:ok, Core.t()} | {:error, String.t()}
  def load_plugin(%Core{} = manager, module, config \\ %{})
      when atom?(module) do
    plugin_name = get_plugin_id_from_metadata(module)

    with {:ok, plugin, merged_config} <-
           initialize_plugin_with_config(manager, plugin_name, module, config),
         :ok <- check_for_circular_dependency(plugin, manager),
         {:ok, updated_manager} <-
           update_manager_with_plugin(
             manager,
             plugin,
             plugin_name,
             merged_config
           ) do
      {:ok, updated_manager}
    else
      {:error, reason} -> {:error, format_error(reason, module)}
    end
  end

  # --- Plugin Initialization ---

  defp initialize_plugin_with_config(manager, plugin_name, module, config) do
    with :ok <- validate_plugin_module(module),
         {:ok, merged_config} <-
           get_and_validate_config(manager, plugin_name, module, config),
         {:ok, plugin} <- initialize_plugin(module, merged_config),
         :ok <- validate_plugin_state(plugin),
         :ok <- validate_plugin_compatibility(plugin, manager) do
      # Add module reference to plugin struct and update name to use metadata ID
      # Also promote any config keys to the top-level plugin struct
      plugin_with_module =
        plugin
        |> Map.put(:module, module)
        |> Map.put(:name, plugin_name)
        |> Map.merge(plugin.config)

      {:ok, plugin_with_module, plugin.config}
    end
  end

  defp validate_plugin_module(module) do
    cond do
      not Code.ensure_loaded?(module) ->
        {:error, :module_not_found}

      not function_exported?(module, :init, 1) ->
        {:error, :missing_init}

      not function_exported?(module, :cleanup, 1) ->
        {:error, :missing_cleanup}

      true ->
        :ok
    end
  end

  defp get_and_validate_config(manager, plugin_name, module, config) do
    merged_config = get_merged_config(manager, plugin_name, module, config)
    validate_config_structure(merged_config)
  end

  defp validate_config_structure(config) when map?(config), do: {:ok, config}
  defp validate_config_structure(_), do: {:error, :invalid_config}

  defp initialize_plugin(module, config) do
    try do
      case module.init(config) do
        {:ok, plugin} -> {:ok, plugin}
        {:error, reason} -> {:error, reason}
        other -> {:error, {:invalid_init_return, other}}
      end
    rescue
      error ->
        log_plugin_init_error(module, error)
        {:error, :init_failed}
    end
  end

  defp validate_plugin_state(plugin) do
    case validate_required_fields(plugin) do
      :ok -> validate_field_types(plugin)
      error -> error
    end
  end

  defp validate_required_fields(plugin) do
    required_fields = [:name, :version, :enabled, :config, :api_version]
    missing = Enum.filter(required_fields, &(Map.get(plugin, &1) == nil))

    if Enum.empty?(missing), do: :ok, else: {:error, {:missing_fields, missing}}
  end

  defp validate_field_types(plugin) do
    with :ok <- validate_string_field(plugin.name, :name),
         :ok <- validate_string_field(plugin.version, :version),
         :ok <- validate_boolean_field(plugin.enabled, :enabled),
         :ok <- validate_map_field(plugin.config, :config),
         :ok <- validate_string_field(plugin.api_version, :api_version) do
      :ok
    else
      {:error, {:invalid_field, field, type}} ->
        {:error, {:invalid_field, field, type}}

      error ->
        error
    end
  end

  defp validate_plugin_compatibility(plugin, manager) do
    check_api_compatibility(plugin, manager)
  end

  # --- Manager Update ---

  defp update_manager_with_plugin(manager, plugin, plugin_name, merged_config) do
    case save_plugin_config(manager.config, plugin_name, merged_config) do
      {:ok, saved_config} ->
        {:ok, update_manager_state(manager, plugin, saved_config)}

      {:error, reason} ->
        log_config_save_error(plugin_name, reason)
        {:ok, update_manager_state(manager, plugin, manager.config)}
    end
  end

  defp save_plugin_config(config, plugin_name, merged_config) do
    updated_config =
      PluginConfig.update_plugin_config(config, plugin_name, merged_config)

    PluginConfig.save(updated_config)
  end

  defp update_manager_state(manager, plugin, config) do
    plugin_key = normalize_plugin_key(plugin.name)
    %{
      manager
      | plugins: Map.put(manager.plugins, plugin_key, plugin),
        loaded_plugins: Map.put(manager.loaded_plugins, plugin_key, plugin),
        config: config
    }
  end

  defp update_manager_state(manager, plugin, config, enabled) do
    plugin_key = normalize_plugin_key(plugin.name)
    %{
      manager
      | plugins: Map.put(manager.plugins, plugin_key, %{plugin | enabled: enabled}),
        config: config
    }
  end

  # --- Helper Functions ---

  defp get_plugin_name(module) do
    Atom.to_string(module)
    |> String.split(".")
    |> List.last()
    |> Macro.underscore()
  end

  defp get_merged_config(manager, plugin_name, module, config) do
    default_config = get_default_config(module)

    persisted_config =
      PluginConfig.get_plugin_config(manager.config, plugin_name)

    default_config
    |> Map.merge(persisted_config)
    |> Map.merge(config)
  end

  defp get_default_config(module) do
    if function_exported?(module, :get_metadata, 0) do
      case module.get_metadata() do
        %{default_config: dc} when map?(dc) -> dc
        _ -> %{}
      end
    else
      %{}
    end
  end

  defp check_api_compatibility(plugin, manager) do
    PluginDependency.check_api_compatibility(
      plugin.api_version,
      manager.api_version
    )
  end

  defp check_dependencies(plugin, manager) do
    DependencyManager.check_dependencies(
      plugin.name,
      plugin,
      Core.list_plugins(manager),
      []
    )
  end

  # --- Error Handling and Logging ---

  defp format_error(:module_not_found, module),
    do: "Module #{module} does not exist"

  defp format_error(:missing_init, module),
    do: "Module #{module} does not implement init/1"

  defp format_error(:missing_cleanup, module),
    do: "Module #{module} does not implement cleanup/1"

  defp format_error(:invalid_config, _module),
    do: "Invalid configuration structure"

  defp format_error(:init_failed, module),
    do: "Plugin initialization failed for #{module}"

  defp format_error({:missing_fields, fields}, module),
    do:
      "Missing required fields: #{Enum.join(fields, ", ")} for plugin #{module}"

  defp format_error({:invalid_init_return, value}, module),
    do: "Invalid init return value: #{inspect(value)} for plugin #{module}"

  defp format_error({:error, reason}, module),
    do: "Failed to initialize plugin #{module}: #{inspect(reason)}"

  defp format_error({:circular_dependency, name}, module),
    do: "Dependency cycle detected for plugin #{name}"

  defp log_plugin_init_error(module, error) do
    Raxol.Core.Runtime.Log.error(
      "Plugin initialization failed: #{inspect(error)}",
      %{module: module}
    )
  end

  defp log_config_save_error(plugin_name, reason) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "Failed to save config for plugin #{plugin_name}: #{inspect(reason)}. Proceeding without saved config.",
      %{}
    )
  end

  # --- Field Validation Helpers ---

  defp validate_string_field(value, _field) when binary?(value), do: :ok

  defp validate_string_field(_value, field),
    do: {:error, {:invalid_field, field, :string}}

  defp validate_boolean_field(value, _field) when boolean?(value), do: :ok

  defp validate_boolean_field(_value, field),
    do: {:error, {:invalid_field, field, :boolean}}

  defp validate_map_field(value, _field) when map?(value), do: :ok

  defp validate_map_field(_value, field),
    do: {:error, {:invalid_field, field, :map}}

  @doc """
  Loads multiple plugins in the correct dependency order.

  Initializes all plugins first, resolves dependencies, then loads them
  one by one using `load_plugin/3`.
  Returns `{:ok, updated_manager}` or `{:error, reason}`.
  """
  @spec load_plugins(Core.t(), list(atom())) ::
          {:ok, Core.t()} | {:error, String.t()}
  def load_plugins(%Core{} = manager, modules) when list?(modules) do
    module_configs = prepare_module_configs(modules)

    with {:ok, initialized_plugins} <- initialize_all_plugins_with_configs(manager, module_configs),
         {:ok, sorted_plugin_names} <- resolve_plugin_order(initialized_plugins),
         {:ok, final_manager} <- load_plugins_in_order(manager, initialized_plugins, sorted_plugin_names) do
      {:ok, build_final_manager(final_manager, sorted_plugin_names)}
    else
      error -> handle_load_plugins_error(error)
    end
  end

  defp prepare_module_configs(modules) do
    Enum.map(modules, fn
      {module, config} -> {module, config}
      module -> {module, %{}}
    end)
  end

  defp build_final_manager(manager, sorted_plugin_names) do
    # Since manager.plugins now uses atom keys, we can use them directly
    loaded_plugins =
      manager.plugins
      |> Map.merge(manager.loaded_plugins)

    # Store the load order as atoms
    load_order = Enum.map(sorted_plugin_names, &normalize_plugin_key/1)

    %{manager | loaded_plugins: loaded_plugins, load_order: load_order}
  end

  defp initialize_all_plugins_with_configs(manager, module_configs) do
    Enum.reduce_while(module_configs, {:ok, []}, fn {module, config},
                                                    {:ok, acc_plugins} ->
      # Use metadata ID if available, otherwise fall back to module-derived name
      plugin_name = get_plugin_id_from_metadata(module)

      case initialize_plugin_with_config(manager, plugin_name, module, config) do
        {:ok, plugin, _merged_config} ->
          {:cont, {:ok, [plugin | acc_plugins]}}

        {:error, reason} ->
          {:halt, {:error, :init_failed, module, reason}}
      end
    end)
  end

  defp get_plugin_id_from_metadata(module) do
    if function_exported?(module, :get_metadata, 0) do
      case module.get_metadata() do
        %{id: id} when is_atom(id) -> Atom.to_string(id)
        _ -> get_plugin_name(module)
      end
    else
      get_plugin_name(module)
    end
  end

  defp resolve_plugin_order(initialized_plugins) do
    case DependencyManager.resolve_load_order(
           for plugin <- initialized_plugins,
               into: %{},
               do: {plugin.name, plugin}
         ) do
      {:ok, sorted_plugin_names} -> {:ok, Enum.map(sorted_plugin_names, &normalize_plugin_key/1)}
      {:error, cycle} -> {:error, :circular_dependency, cycle, nil}
      other -> {:error, :resolve_failed, other}
    end
  end

  defp handle_load_plugins_error({:error, :init_failed, module, reason}),
    do: {:error, "Failed to initialize plugin #{module}: #{inspect(reason)}"}

  defp handle_load_plugins_error({:error, :resolve_failed, reason}),
    do: {:error, "Failed to resolve plugin dependencies: #{inspect(reason)}"}

  defp handle_load_plugins_error({:error, :load_failed, name, reason}),
    do: {:error, "Failed to load plugin #{name}: #{inspect(reason)}"}

  defp handle_load_plugins_error({:error, :circular_dependency, cycle, _}),
    do: {:error, "Circular dependency detected: #{Enum.join(cycle, " -> ")}"}

  defp handle_load_plugins_error({:error, reason}),
    do: {:error, "Failed to load plugins: #{inspect(reason)}"}

  # Catch-all clause for any other error patterns
  defp handle_load_plugins_error(error),
    do: {:error, "Failed to load plugins: #{inspect(error)}"}

  @doc """
  Unloads a plugin by name.

  Calls the plugin's `cleanup/1` callback, updates the configuration to disable
  the plugin, saves the configuration, and removes the plugin from the manager state.
  Returns `{:ok, updated_manager}` or `{:error, reason}`.
  """
  @spec unload_plugin(Core.t(), String.t()) ::
          {:ok, Core.t()} | {:error, String.t()}
  def unload_plugin(%Core{} = manager, name) when binary?(name) do
    plugin_key = normalize_plugin_key(name)
    case Map.get(manager.plugins, plugin_key) do
      nil ->
        {:error, "Plugin #{name} not found"}
      plugin ->
        with :ok <- do_plugin_cleanup_and_stop(plugin),
             {:ok, updated_manager} <- update_config_and_remove_plugin(manager, plugin, name) do
          {:ok, updated_manager}
        else
          {:error, reason} ->
            {:error, "Failed to cleanup plugin #{name}: #{inspect(reason)}"}
        end
    end
  end

  defp do_plugin_cleanup_and_stop(plugin) do
    module = plugin.module
    with :ok <- call_plugin_stop(plugin, module),
         :ok <- module.cleanup(plugin) do
      :ok
    else
      error -> error
    end
  end

  defp update_config_and_remove_plugin(manager, plugin, name) do
    plugin_key = normalize_plugin_key(name)
    updated_config = PluginConfig.disable_plugin(manager.config, name)
    case PluginConfig.save(updated_config) do
      {:ok, saved_config} ->
        {:ok, %{manager |
          plugins: Map.delete(manager.plugins, plugin_key),
          loaded_plugins: Map.delete(manager.loaded_plugins, plugin_key),
          config: saved_config}}
      {:error, reason} ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "Failed to save config after unloading plugin #{name}: #{inspect(reason)}. Proceeding anyway.",
          %{}
        )
        {:ok, %{manager |
          plugins: Map.delete(manager.plugins, plugin_key),
          loaded_plugins: Map.delete(manager.loaded_plugins, plugin_key),
          config: manager.config}}
    end
  end

  defp call_plugin_stop(plugin, module) do
    # Check if the plugin module implements the Lifecycle behaviour by checking for stop/1 function
    if function_exported?(module, :stop, 1) do
      case module.stop(plugin.config) do
        {:ok, _updated_config} -> :ok
        {:error, reason} -> {:error, reason}
      end
    else
      :ok
    end
  end

  @doc """
  Enables a plugin by name.

  Checks dependencies, updates the configuration to enable the plugin,
  saves the configuration, and updates the plugin state in the manager.
  Returns `{:ok, updated_manager}` or `{:error, reason}`.
  """
  @spec enable_plugin(Core.t(), String.t()) ::
          {:ok, Core.t()} | {:error, String.t()}
  def enable_plugin(%Core{} = manager, name) when binary?(name) do
    with {:ok, plugin} <- get_plugin(manager, name),
         :ok <- check_plugin_dependencies(plugin, manager),
         {:ok, updated_config} <- update_and_save_config(manager, name, :enable) do
      {:ok, update_manager_state(manager, plugin, updated_config, true)}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_plugin(manager, name) do
    plugin_key = normalize_plugin_key(name)
    case Map.get(manager.plugins, plugin_key) do
      nil -> {:error, "Plugin #{name} not found"}
      plugin -> {:ok, plugin}
    end
  end

  defp check_plugin_dependencies(plugin, manager) do
    DependencyManager.check_dependencies(
      plugin.name,
      plugin,
      Core.list_plugins(manager),
      []
    )
  end

  defp update_and_save_config(manager, name, action) do
    updated_config =
      case action do
        :enable -> PluginConfig.enable_plugin(manager.config, name)
        :disable -> PluginConfig.disable_plugin(manager.config, name)
      end

    case PluginConfig.save(updated_config) do
      {:ok, saved_config} ->
        {:ok, saved_config}

      {:error, reason} ->
        log_config_save_error(name, reason)
        {:ok, manager.config}
    end
  end

  @doc """
  Disables a plugin by name.

  Updates the configuration to disable the plugin, saves the configuration,
  and updates the plugin state in the manager.
  Returns `{:ok, updated_manager}` or `{:error, reason}`.
  """
  @spec disable_plugin(Core.t(), String.t()) ::
          {:ok, Core.t()} | {:error, String.t()}
  def disable_plugin(%Core{} = manager, name) when binary?(name) do
    with {:ok, plugin} <- get_plugin(manager, name),
         {:ok, updated_config} <-
           update_and_save_config(manager, name, :disable) do
      {:ok, update_manager_state(manager, plugin, updated_config, false)}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # --- Private Helper Functions for load_plugins/2 ---

  # Loads plugins in a specific order based on resolved dependencies.
  @spec load_plugins_in_order(Core.t(), list(map()), list(String.t())) ::
          {:ok, Core.t()} | {:error, :load_failed, String.t(), any()}
  defp load_plugins_in_order(manager, initialized_plugins, sorted_plugin_names) do
    Enum.reduce_while(
      sorted_plugin_names,
      {:ok, manager},
      &load_single_plugin(&1, &2, initialized_plugins)
    )
  end

  defp load_single_plugin(plugin_name, {:ok, acc_manager}, initialized_plugins) do
    case find_and_load_plugin(plugin_name, acc_manager, initialized_plugins) do
      {:ok, updated_manager} ->
        # Call start/1 on plugins that implement the Lifecycle behaviour
        case call_plugin_start(
               plugin_name,
               updated_manager,
               initialized_plugins
             ) do
          {:ok, final_manager} -> {:cont, {:ok, final_manager}}
          error -> {:halt, error}
        end

      error ->
        {:halt, error}
    end
  end

  defp call_plugin_start(plugin_name, manager, initialized_plugins) do
    case find_plugin_and_start(plugin_name, manager, initialized_plugins) do
      {:ok, updated_manager} -> {:ok, updated_manager}
      {:error, reason} -> {:error, :start_failed, plugin_name, reason}
    end
  end

  defp find_plugin_and_start(plugin_name, manager, initialized_plugins) do
    # Convert plugin_name to string for comparison since plugin.name is a string
    plugin_name_str = if is_atom(plugin_name), do: Atom.to_string(plugin_name), else: plugin_name
    case Enum.find(initialized_plugins, &(&1.name == plugin_name_str)) do
      nil -> {:error, "Plugin not found"}
      plugin -> start_plugin_if_supported(plugin, manager)
    end
  end

  defp start_plugin_if_supported(plugin, manager) do
    if function_exported?(plugin.module, :start, 1) do
      handle_plugin_start(plugin, manager)
    else
      {:ok, manager}
    end
  end

  defp handle_plugin_start(plugin, manager) do
    case plugin.module.start(plugin.config) do
      {:ok, updated_config} -> update_manager_with_plugin_config(manager, plugin, updated_config)
      {:error, reason} -> {:error, reason}
    end
  end

  defp update_manager_with_plugin_config(manager, plugin, updated_config) do
    # Merge any new keys from updated_config into the top-level plugin struct
    # This allows plugins to add state fields that are accessible directly on the plugin
    plugin_with_promoted_config =
      plugin
      |> Map.merge(updated_config)
      |> Map.put(:config, updated_config)

    plugin_key = normalize_plugin_key(plugin.name)
    updated_plugins = Map.put(manager.plugins, plugin_key, plugin_with_promoted_config)
    updated_loaded_plugins = Map.put(manager.loaded_plugins, plugin_key, plugin_with_promoted_config)

    {:ok, %{manager | plugins: updated_plugins, loaded_plugins: updated_loaded_plugins}}
  end

  defp find_and_load_plugin(plugin_name, acc_manager, initialized_plugins) do
    # Convert plugin_name to string for comparison since plugin.name is a string
    plugin_name_str = if is_atom(plugin_name), do: Atom.to_string(plugin_name), else: plugin_name
    case Enum.find(initialized_plugins, &(&1.name == plugin_name_str)) do
      plugin when not nil?(plugin) ->
        # Use the module reference stored in the plugin struct
        load_plugin(acc_manager, plugin.module)

      nil ->
        Raxol.Core.Runtime.Log.error(
          "Plugin #{plugin_name} found in sorted list but not in initialized list."
        )

        {:error, :load_failed, plugin_name, "Not found in initialized list"}
    end
  end

  defp handle_plugin_error(plugin, callback_name, plugin_result, _acc) do
    case plugin_result do
      {:error, reason} ->
        log_plugin_error(plugin, callback_name, reason)
        {:halt, {:error, reason}}

      other ->
        log_unexpected_result(plugin, callback_name, other)
        {:cont, {:error, "Unexpected result"}}
    end
  end

  defp log_plugin_error(plugin, callback_name, reason) do
    Raxol.Core.Runtime.Log.error_with_stacktrace(
      "Plugin #{plugin.name} failed during #{callback_name}",
      reason,
      nil,
      %{
        plugin: plugin.name,
        callback: callback_name,
        module: __MODULE__
      }
    )
  end

  defp log_unexpected_result(plugin, callback_name, result) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "Plugin #{plugin.name} returned unexpected value from #{callback_name}",
      %{
        plugin: plugin.name,
        callback: callback_name,
        value: result,
        module: __MODULE__
      }
    )
  end

  defp check_for_circular_dependency(plugin, manager) do
    # Ensure all keys are strings for the resolver, but atom for plugins map
    plugin_key = plugin.name
    plugins =
      manager.plugins
      |> Enum.map(fn {k, v} ->
        key = if is_atom(k), do: Atom.to_string(k), else: k
        {key, v}
      end)
      |> Enum.into(%{})
      |> Map.put(plugin_key, plugin)
    plugins_atom_keys =
      plugins
      |> Enum.map(fn {k, v} -> {normalize_plugin_key(k), v} end)
      |> Enum.into(%{})
    case Raxol.Core.Runtime.Plugins.DependencyManager.Core.resolve_load_order(plugins) do
      {:ok, _order} -> :ok
      {:error, :circular_dependency, _cycle, _chain} ->
        {:error, {:circular_dependency, plugin.name}}
      other ->
        :ok # fallback, should not happen
    end
  end

  # Helper to normalize plugin keys to atoms
  defp normalize_plugin_key(key) when is_atom(key), do: key
  defp normalize_plugin_key(key) when is_binary(key), do: String.to_atom(key)
end
