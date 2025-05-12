defmodule Raxol.Plugins.Lifecycle do
  @moduledoc """
  Handles the lifecycle management of Raxol plugins.

  This includes loading, unloading, enabling, disabling, and managing
  dependencies and configuration persistence.
  """

  require Logger

  # Alias necessary modules
  alias Raxol.Plugins.{Plugin, PluginConfig, PluginDependency, PluginManager}
  alias Raxol.Core.Runtime.Plugins.DependencyManager

  @doc """
  Loads a single plugin module and initializes it.

  Handles configuration merging, API compatibility checks, dependency checks,
  and saving the updated configuration.
  Returns `{:ok, updated_manager}` or `{:error, reason}`.
  """
  @spec load_plugin(PluginManager.t(), atom(), map()) ::
          {:ok, PluginManager.t()} | {:error, String.t()}
  def load_plugin(%PluginManager{} = manager, module, config \\ %{})
      when is_atom(module) do
    # Get persisted config for this plugin
    plugin_name =
      Atom.to_string(module)
      |> String.split(".")
      |> List.last()
      |> Macro.underscore()

    persisted_config =
      PluginConfig.get_plugin_config(manager.config, plugin_name)

    # Merge persisted config with provided config
    merged_config = Map.merge(persisted_config, config)

    with {:ok, plugin} <- module.init(merged_config),
         :ok <-
           PluginDependency.check_api_compatibility(
             plugin.api_version,
             manager.api_version
           ),
         {:ok, _} <-
           DependencyManager.check_dependencies(
             plugin.name,
             plugin,
             PluginManager.list_plugins(manager),
             []
           ),
         # Update plugin config with merged config
         updated_config =
           PluginConfig.update_plugin_config(
             manager.config,
             plugin_name,
             merged_config
           ),
         # Attempt to save updated config
         {:ok_or_error, saved_or_original_config} <-
           {:ok_or_error, PluginConfig.save(updated_config)} do
      # Determine final config (saved or original if save failed)
      final_config =
        case saved_or_original_config do
          {:ok, saved_config} ->
            saved_config

          {:error, reason} ->
            Logger.warning(
              "Failed to save config for plugin #{plugin_name}: #{inspect(reason)}. Proceeding without saved config."
            )

            # Use the config state *before* the failed save attempt
            manager.config
        end

      {:ok,
       %{
         manager
         | plugins: Map.put(manager.plugins, plugin.name, plugin),
           config: final_config
       }}
    else
      # Error handling for the with statement
      # Pass through existing error messages
      {:error, reason} when is_binary(reason) ->
        {:error, reason}

      {:error, :api_incompatible} ->
        {:error, "API version mismatch for plugin #{module}"}

      {:error, :dependency_missing, missing} ->
        {:error, "Missing dependency #{missing} for plugin #{module}"}

      {:error, :dependency_cycle, cycle} ->
        {:error, "Dependency cycle detected: #{inspect(cycle)}"}

      {:error, init_reason} ->
        {:error,
         "Failed to initialize plugin #{module}: #{inspect(init_reason)}"}

        # Catch potential config save error if not handled by the case above (shouldn't happen with {:ok_or_error, ...})
        # _ -> {:error, "Unknown error loading plugin #{module}"} # Consider a more specific error
    end
  end

  @doc """
  Loads multiple plugins in the correct dependency order.

  Initializes all plugins first, resolves dependencies, then loads them
  one by one using `load_plugin/3`.
  Returns `{:ok, updated_manager}` or `{:error, reason}`.
  """
  @spec load_plugins(PluginManager.t(), list(atom())) ::
          {:ok, PluginManager.t()} | {:error, String.t()}
  def load_plugins(%PluginManager{} = manager, modules) when is_list(modules) do
    with {:ok, initialized_plugins} <- initialize_all_plugins(manager, modules),
         {:ok, sorted_plugin_names} <- DependencyManager.resolve_load_order(
           for plugin <- initialized_plugins, into: %{}, do: {plugin.name, plugin}
         ),
         {:ok, final_manager} <-
           load_plugins_in_order(
             manager,
             initialized_plugins,
             sorted_plugin_names
           ) do
      {:ok, final_manager}
    else
      {:error, :init_failed, module, reason} ->
        {:error, "Failed to initialize plugin #{module}: #{inspect(reason)}"}

      {:error, :resolve_failed, reason} ->
        {:error, "Failed to resolve plugin dependencies: #{inspect(reason)}"}

      {:error, :load_failed, name, reason} ->
        {:error, "Failed to load plugin #{name}: #{inspect(reason)}"}

      # Catch other potential errors from `with`
      {:error, reason} ->
        {:error, "Failed to load plugins: #{inspect(reason)}"}
    end
  end

  @doc """
  Unloads a plugin by name.

  Calls the plugin's `cleanup/1` callback, updates the configuration to disable
  the plugin, saves the configuration, and removes the plugin from the manager state.
  Returns `{:ok, updated_manager}` or `{:error, reason}`.
  """
  @spec unload_plugin(PluginManager.t(), String.t()) ::
          {:ok, PluginManager.t()} | {:error, String.t()}
  def unload_plugin(%PluginManager{} = manager, name) when is_binary(name) do
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
                Logger.warning(
                  "Failed to save config after unloading plugin #{name}: #{inspect(reason)}. Proceeding anyway."
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
  @spec enable_plugin(PluginManager.t(), String.t()) ::
          {:ok, PluginManager.t()} | {:error, String.t()}
  def enable_plugin(%PluginManager{} = manager, name) when is_binary(name) do
    case Map.get(manager.plugins, name) do
      nil ->
        {:error, "Plugin #{name} not found"}

      plugin ->
        with {:ok, _} <-
               DependencyManager.check_dependencies(
                 plugin.name,
                 plugin,
                 PluginManager.list_plugins(manager),
                 []
               ),
             # Update config to enable plugin
             updated_config = PluginConfig.enable_plugin(manager.config, name),
             # Attempt to save updated config
             {:ok_or_error, saved_or_original_config} <-
               {:ok_or_error, PluginConfig.save(updated_config)} do
          final_config =
            case saved_or_original_config do
              {:ok, saved_config} ->
                saved_config

              {:error, reason} ->
                Logger.warning(
                  "Failed to save config after enabling plugin #{name}: #{inspect(reason)}. Proceeding anyway."
                )

                manager.config
            end

          {:ok,
           %{
             manager
             | plugins:
                 Map.put(manager.plugins, plugin.name, %{plugin | enabled: true}),
               config: final_config
           }}
        else
          {:error, :dependency_missing, missing} ->
            {:error,
             "Cannot enable plugin #{name}: Missing dependency #{missing}"}

          {:error, :dependency_cycle, cycle} ->
            {:error,
             "Cannot enable plugin #{name}: Dependency cycle detected #{inspect(cycle)}"}

          {:error, reason} ->
            # Catch-all for other check_dependencies errors
            {:error, "Cannot enable plugin #{name}: #{inspect(reason)}"}

            # _ -> {:error, "Unknown error enabling plugin #{name}"} # Consider more specific errors
        end
    end
  end

  @doc """
  Disables a plugin by name.

  Updates the configuration to disable the plugin, saves the configuration,
  and updates the plugin state in the manager.
  Returns `{:ok, updated_manager}` or `{:error, reason}`.
  """
  @spec disable_plugin(PluginManager.t(), String.t()) ::
          {:ok, PluginManager.t()} | {:error, String.t()}
  def disable_plugin(%PluginManager{} = manager, name) when is_binary(name) do
    case Map.get(manager.plugins, name) do
      nil ->
        {:error, "Plugin #{name} not found"}

      plugin ->
        # Update config to disable plugin
        updated_config = PluginConfig.disable_plugin(manager.config, name)

        # Save updated config
        case PluginConfig.save(updated_config) do
          {:ok, saved_config} ->
            {:ok,
             %{
               manager
               | plugins:
                   Map.put(manager.plugins, plugin.name, %{
                     plugin
                     | enabled: false
                   }),
                 config: saved_config
             }}

          {:error, reason} ->
            Logger.warning(
              "Failed to save config after disabling plugin #{name}: #{inspect(reason)}. Proceeding anyway."
            )

            # Continue even if save fails, but use the manager state before the save attempt
            {:ok,
             %{
               manager
               | plugins:
                   Map.put(manager.plugins, plugin.name, %{
                     plugin
                     | enabled: false
                   })
                 # config remains manager.config
             }}
        end
    end
  end

  # --- Private Helper Functions for load_plugins/2 ---

  # Initializes a list of plugin modules without adding them to the manager state.
  @spec initialize_all_plugins(PluginManager.t(), list(atom())) ::
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
  @spec load_plugins_in_order(PluginManager.t(), list(map()), list(String.t())) ::
          {:ok, PluginManager.t()} | {:error, :load_failed, String.t(), any()}
  defp load_plugins_in_order(manager, initialized_plugins, sorted_plugin_names) do
    Enum.reduce_while(
      sorted_plugin_names,
      {:ok, manager},
      fn plugin_name, {:ok, acc_manager} ->
        # Find the pre-initialized plugin struct
        case Enum.find(initialized_plugins, &(&1.name == plugin_name)) do
          nil ->
            # This should technically not happen if resolve_dependencies is correct
            Logger.error(
              "Plugin #{plugin_name} found in sorted list but not in initialized list."
            )

            {:halt,
             {:error, :load_failed, plugin_name,
              "Not found in initialized list"}}

          plugin ->
            # Load the plugin using its module name
            # We assume the module name can be derived from the plugin name
            # This might need adjustment if plugin names don't map directly
            # Example derivation, adjust if needed:
            module_name_parts =
              String.split(plugin_name, "_") |> Enum.map(&String.capitalize/1)

            # Adjust namespace if needed
            module_str =
              "Elixir.Raxol.Plugins." <> Enum.join(module_name_parts, "")

            plugin_module = String.to_existing_atom(module_str)

            # Call the single load_plugin function (now in this module)
            case load_plugin(acc_manager, plugin_module) do
              {:ok, updated_manager} ->
                {:cont, {:ok, updated_manager}}

              {:error, reason} ->
                {:halt, {:error, :load_failed, plugin_name, reason}}
            end
        end
      end
    )
  end
end
