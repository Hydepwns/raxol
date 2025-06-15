defmodule Raxol.Plugins.Lifecycle do
  @moduledoc """
  Handles the lifecycle management of Raxol plugins.

  This includes loading, unloading, enabling, disabling, and managing
  dependencies and configuration persistence.
  """

  require Raxol.Core.Runtime.Log

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
  def load_plugin(%Core{} = manager, module, config \\ %{}) when is_atom(module) do
    plugin_name = get_plugin_name(module)
    merged_config = get_merged_config(manager, plugin_name, module, config)

    with {:ok, plugin} <- module.init(merged_config),
         :ok <- check_api_compatibility(plugin, manager),
         :ok <- check_dependencies(plugin, manager) do
      handle_successful_load(manager, plugin, plugin_name, merged_config)
    else
      error -> handle_load_error(error, module)
    end
  end

  defp get_plugin_name(module) do
    Atom.to_string(module)
    |> String.split(".")
    |> List.last()
    |> Macro.underscore()
  end

  defp get_merged_config(manager, plugin_name, module, config) do
    default_config = get_default_config(module)
    persisted_config = PluginConfig.get_plugin_config(manager.config, plugin_name)

    default_config
    |> Map.merge(persisted_config)
    |> Map.merge(config)
  end

  defp get_default_config(module) do
    if function_exported?(module, :get_metadata, 0) do
      case module.get_metadata() do
        %{default_config: dc} when is_map(dc) -> dc
        _ -> %{}
      end
    else
      %{}
    end
  end

  defp check_api_compatibility(plugin, manager) do
    PluginDependency.check_api_compatibility(plugin.api_version, manager.api_version)
  end

  defp check_dependencies(plugin, manager) do
    DependencyManager.check_dependencies(
      plugin.name,
      plugin,
      Core.list_plugins(manager),
      []
    )
  end

  defp handle_successful_load(manager, plugin, plugin_name, merged_config) do
    updated_config = PluginConfig.update_plugin_config(manager.config, plugin_name, merged_config)

    case PluginConfig.save(updated_config) do
      {:ok, saved_config} ->
        {:ok, %{manager | plugins: Map.put(manager.plugins, plugin.name, plugin), config: saved_config}}
      {:error, reason} ->
        log_config_save_error(plugin_name, reason)
        {:ok, %{manager | plugins: Map.put(manager.plugins, plugin.name, plugin), config: manager.config}}
    end
  end

  defp handle_load_error({:error, :api_incompatible}, module), do: {:error, "API version mismatch for plugin #{module}"}
  defp handle_load_error({:error, :dependency_missing, missing}, module), do: {:error, "Missing dependency #{missing} for plugin #{module}"}
  defp handle_load_error({:error, :dependency_cycle, cycle}, _module), do: {:error, "Dependency cycle detected: #{inspect(cycle)}"}
  defp handle_load_error({:error, reason}, module), do: {:error, "Failed to initialize plugin #{module}: #{inspect(reason)}"}
  defp handle_load_error({:error, :missing_version, missing, _chain}, module), do: {:error, "Missing version for dependency(ies): #{Enum.join(missing, ", ")} for plugin #{module}"}

  defp log_config_save_error(plugin_name, reason) do
    Raxol.Core.Runtime.Log.warning_with_context(
      "Failed to save config for plugin #{plugin_name}: #{inspect(reason)}. Proceeding without saved config.",
      %{}
    )
  end

  @doc """
  Loads multiple plugins in the correct dependency order.

  Initializes all plugins first, resolves dependencies, then loads them
  one by one using `load_plugin/3`.
  Returns `{:ok, updated_manager}` or `{:error, reason}`.
  """
  @spec load_plugins(Core.t(), list(atom())) ::
          {:ok, Core.t()} | {:error, String.t()}
  def load_plugins(%Core{} = manager, modules) when is_list(modules) do
    with {:ok, initialized_plugins} <- initialize_all_plugins(manager, modules),
         {:ok, sorted_plugin_names} <- resolve_plugin_order(initialized_plugins),
         {:ok, final_manager} <- load_plugins_in_order(manager, initialized_plugins, sorted_plugin_names) do
      {:ok, final_manager}
    else
      error -> handle_load_plugins_error(error)
    end
  end

  defp resolve_plugin_order(initialized_plugins) do
    DependencyManager.resolve_load_order(
      for plugin <- initialized_plugins,
          into: %{},
          do: {plugin.name, plugin}
    )
  end

  defp handle_load_plugins_error({:error, :init_failed, module, reason}),
    do: {:error, "Failed to initialize plugin #{module}: #{inspect(reason)}"}
  defp handle_load_plugins_error({:error, :resolve_failed, reason}),
    do: {:error, "Failed to resolve plugin dependencies: #{inspect(reason)}"}
  defp handle_load_plugins_error({:error, :load_failed, name, reason}),
    do: {:error, "Failed to load plugin #{name}: #{inspect(reason)}"}
  defp handle_load_plugins_error({:error, reason}),
    do: {:error, "Failed to load plugins: #{inspect(reason)}"}

  @doc """
  Unloads a plugin by name.

  Calls the plugin's `cleanup/1` callback, updates the configuration to disable
  the plugin, saves the configuration, and removes the plugin from the manager state.
  Returns `{:ok, updated_manager}` or `{:error, reason}`.
  """
  @spec unload_plugin(Core.t(), String.t()) ::
          {:ok, Core.t()} | {:error, String.t()}
  def unload_plugin(%Core{} = manager, name) when is_binary(name) do
    case Map.get(manager.plugins, name) do
      nil ->
        {:error, "Plugin #{name} not found"}

      plugin ->
        module = plugin.__struct__

        with :ok <- module.cleanup(plugin),
             # Update config to disable plugin
             updated_config = PluginConfig.disable_plugin(manager.config, name),
             # Attempt to save updated config
             {:ok_or_error, saved_or_original_config} <-
               {:ok_or_error, PluginConfig.save(updated_config)} do
          # Determine final config (saved or original if save failed)
          final_config =
            case saved_or_original_config do
              {:ok, saved_config} ->
                saved_config

              {:error, reason} ->
                Raxol.Core.Runtime.Log.warning_with_context(
                  "Failed to save config after unloading plugin #{name}: #{inspect(reason)}. Proceeding anyway.",
                  %{}
                )

                # Use config state before failed save
                manager.config
            end

          {:ok,
           %{
             manager
             | plugins: Map.delete(manager.plugins, name),
               config: final_config
           }}
        else
          {:error, reason} ->
            {:error, "Failed to cleanup plugin #{name}: #{inspect(reason)}"}

            # _ -> {:error, "Unknown error unloading plugin #{name}"} # Consider more specific errors
        end
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
  def enable_plugin(%Core{} = manager, name) when is_binary(name) do
    with {:ok, plugin} <- get_plugin(manager, name),
         :ok <- check_plugin_dependencies(plugin, manager),
         {:ok, updated_config} <- update_and_save_config(manager, name, :enable) do
      {:ok, update_manager_state(manager, plugin, updated_config, true)}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp get_plugin(manager, name) do
    case Map.get(manager.plugins, name) do
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
      {:ok, saved_config} -> {:ok, saved_config}
      {:error, reason} ->
        log_config_save_error(name, reason)
        {:ok, manager.config}
    end
  end

  defp update_manager_state(manager, plugin, config, enabled) do
    %{manager |
      plugins: Map.put(manager.plugins, plugin.name, %{plugin | enabled: enabled}),
      config: config
    }
  end

  @doc """
  Disables a plugin by name.

  Updates the configuration to disable the plugin, saves the configuration,
  and updates the plugin state in the manager.
  Returns `{:ok, updated_manager}` or `{:error, reason}`.
  """
  @spec disable_plugin(Core.t(), String.t()) ::
          {:ok, Core.t()} | {:error, String.t()}
  def disable_plugin(%Core{} = manager, name) when is_binary(name) do
    with {:ok, plugin} <- get_plugin(manager, name),
         {:ok, updated_config} <- update_and_save_config(manager, name, :disable) do
      {:ok, update_manager_state(manager, plugin, updated_config, false)}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # --- Private Helper Functions for load_plugins/2 ---

  # Initializes a list of plugin modules without adding them to the manager state.
  @spec initialize_all_plugins(Core.t(), list(atom())) ::
          {:ok, list(map())} | {:error, :init_failed, atom(), any()}
  defp initialize_all_plugins(manager, modules) do
    Enum.reduce_while(modules, {:ok, []}, fn module, {:ok, acc_plugins} ->
      plugin_name =
        Atom.to_string(module)
        |> String.split(".")
        |> List.last()
        |> Macro.underscore()

      persisted_config =
        PluginConfig.get_plugin_config(manager.config, plugin_name)

      case module.init(persisted_config) do
        {:ok, plugin} ->
          {:cont, {:ok, [plugin | acc_plugins]}}

        {:error, reason} ->
          {:halt, {:error, :init_failed, module, reason}}
      end
    end)
  end

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
      {:ok, updated_manager} -> {:cont, {:ok, updated_manager}}
      error -> {:halt, error}
    end
  end

  defp find_and_load_plugin(plugin_name, acc_manager, initialized_plugins) do
    with plugin when not is_nil(plugin) <- Enum.find(initialized_plugins, &(&1.name == plugin_name)),
         plugin_module <- get_plugin_module(plugin_name) do
      load_plugin(acc_manager, plugin_module)
    else
      nil ->
        Raxol.Core.Runtime.Log.error("Plugin #{plugin_name} found in sorted list but not in initialized list.")
        {:error, :load_failed, plugin_name, "Not found in initialized list"}
    end
  end

  defp get_plugin_module(plugin_name) do
    module_str = "Elixir.Raxol.Plugins." <>
      Enum.map_join(String.split(plugin_name, "_"), "", &String.capitalize/1)
    String.to_existing_atom(module_str)
  end
end
