defmodule Raxol.Plugins.PluginManager do
  @moduledoc """
  Manages plugins for the Raxol terminal emulator.
  Handles plugin loading, lifecycle management, and event dispatching.
  """

  alias Raxol.Plugins.{Plugin, PluginConfig, PluginDependency}

  @type t :: %__MODULE__{
    plugins: %{String.t() => Plugin.t()},
    config: PluginConfig.t(),
    api_version: String.t()
  }

  defstruct [
    :plugins,
    :config,
    :api_version
  ]

  @doc """
  Creates a new plugin manager with default configuration.
  """
  def new(_config \\ %{}) do
    %{
      plugins: [],
      initialized_plugins: []
    }
  end

  @doc """
  Loads a plugin module and initializes it with the given configuration.
  """
  def load_plugin(%__MODULE__{} = manager, module, config \\ %{}) when is_atom(module) do
    # Get persisted config for this plugin
    plugin_name = Atom.to_string(module) |> String.split(".") |> List.last() |> Macro.underscore()
    persisted_config = PluginConfig.get_plugin_config(manager.config, plugin_name)
    
    # Merge persisted config with provided config
    merged_config = Map.merge(persisted_config, config)
    
    case module.init(merged_config) do
      {:ok, plugin} ->
        # Check API compatibility
        case PluginDependency.check_api_compatibility(plugin.api_version, manager.api_version) do
          :ok ->
            # Check dependencies
            case PluginDependency.check_dependencies(plugin, list_plugins(manager)) do
              {:ok, _} ->
                # Update plugin config with merged config
                updated_config = PluginConfig.update_plugin_config(manager.config, plugin_name, merged_config)
                
                # Save updated config
                case PluginConfig.save(updated_config) do
                  {:ok, saved_config} ->
                    %{manager | 
                      plugins: Map.put(manager.plugins, plugin.name, plugin),
                      config: saved_config
                    }
                  {:error, _reason} ->
                    # Continue even if save fails
                    %{manager | plugins: Map.put(manager.plugins, plugin.name, plugin)}
                end
              {:error, reason} ->
                {:error, "Failed to load plugin #{module}: #{reason}"}
            end
          {:error, reason} ->
            {:error, "Failed to load plugin #{module}: #{reason}"}
        end
      {:error, reason} ->
        {:error, "Failed to load plugin #{module}: #{reason}"}
    end
  end

  @doc """
  Loads multiple plugins in the correct dependency order.
  """
  def load_plugins(%__MODULE__{} = manager, modules) when is_list(modules) do
    # First, initialize all plugins without adding them to the manager
    plugins = Enum.reduce_while(modules, {:ok, []}, fn module, {:ok, acc_plugins} ->
      plugin_name = Atom.to_string(module) |> String.split(".") |> List.last() |> Macro.underscore()
      persisted_config = PluginConfig.get_plugin_config(manager.config, plugin_name)
      
      case module.init(persisted_config) do
        {:ok, plugin} -> {:cont, {:ok, [plugin | acc_plugins]}}
        {:error, reason} -> {:halt, {:error, "Failed to initialize plugin #{module}: #{reason}"}}
      end
    end)
    
    case plugins do
      {:ok, initialized_plugins} ->
        # Resolve dependencies to get the correct load order
        case PluginDependency.resolve_dependencies(initialized_plugins) do
          {:ok, sorted_plugin_names} ->
            # Load plugins in the correct order
            Enum.reduce_while(sorted_plugin_names, {:ok, manager}, fn plugin_name, {:ok, acc_manager} ->
              # Find the plugin in initialized plugins
              case Enum.find(initialized_plugins, fn p -> p.name == plugin_name end) do
                nil -> {:halt, {:error, "Plugin #{plugin_name} not found in initialized plugins"}}
                _plugin ->
                  # Load the plugin using its module name
                  case load_plugin(acc_manager, String.to_atom("Elixir.#{String.replace(plugin_name, "_", ".")}")) do
                    updated_manager when is_map(updated_manager) ->
                      {:cont, {:ok, updated_manager}}
                    {:error, reason} ->
                      {:halt, {:error, "Failed to load plugin #{plugin_name}: #{reason}"}}
                  end
              end
            end)
          {:error, reason} ->
            {:error, "Failed to resolve plugin dependencies: #{reason}"}
        end
      {:error, _reason} = error ->
        error
    end
  end

  @doc """
  Unloads a plugin by name.
  """
  def unload_plugin(%__MODULE__{} = manager, name) when is_binary(name) do
    case Map.get(manager.plugins, name) do
      nil ->
        {:error, "Plugin #{name} not found"}
      plugin ->
        case plugin.cleanup() do
          :ok ->
            # Update config to disable plugin
            updated_config = PluginConfig.disable_plugin(manager.config, name)
            
            # Save updated config
            case PluginConfig.save(updated_config) do
              {:ok, saved_config} ->
                %{manager | 
                  plugins: Map.delete(manager.plugins, name),
                  config: saved_config
                }
              {:error, _reason} ->
                # Continue even if save fails
                %{manager | plugins: Map.delete(manager.plugins, name)}
            end
          {:error, reason} ->
            {:error, "Failed to cleanup plugin #{name}: #{reason}"}
        end
    end
  end

  @doc """
  Enables a plugin by name.
  """
  def enable_plugin(%__MODULE__{} = manager, name) when is_binary(name) do
    case Map.get(manager.plugins, name) do
      nil ->
        {:error, "Plugin #{name} not found"}
      plugin ->
        # Check dependencies before enabling
        case PluginDependency.check_dependencies(plugin, list_plugins(manager)) do
          {:ok, _} ->
            # Update config to enable plugin
            updated_config = PluginConfig.enable_plugin(manager.config, name)
            
            # Save updated config
            case PluginConfig.save(updated_config) do
              {:ok, saved_config} ->
                %{manager | 
                  plugins: Map.put(manager.plugins, plugin.name, %{plugin | enabled: true}),
                  config: saved_config
                }
              {:error, _reason} ->
                # Continue even if save fails
                %{manager | plugins: Map.put(manager.plugins, plugin.name, %{plugin | enabled: true})}
            end
          {:error, reason} ->
            {:error, "Cannot enable plugin #{name}: #{reason}"}
        end
    end
  end

  @doc """
  Disables a plugin by name.
  """
  def disable_plugin(%__MODULE__{} = manager, name) when is_binary(name) do
    case Map.get(manager.plugins, name) do
      nil ->
        {:error, "Plugin #{name} not found"}
      plugin ->
        # Update config to disable plugin
        updated_config = PluginConfig.disable_plugin(manager.config, name)
        
        # Save updated config
        case PluginConfig.save(updated_config) do
          {:ok, saved_config} ->
            %{manager | 
              plugins: Map.put(manager.plugins, plugin.name, %{plugin | enabled: false}),
              config: saved_config
            }
          {:error, _reason} ->
            # Continue even if save fails
            %{manager | plugins: Map.put(manager.plugins, plugin.name, %{plugin | enabled: false})}
        end
    end
  end

  @doc """
  Processes input through all enabled plugins.
  """
  def process_input(%__MODULE__{} = manager, input) when is_binary(input) do
    Enum.reduce_while(manager.plugins, {:ok, manager}, fn {_name, plugin}, {:ok, acc_manager} ->
      if plugin.enabled do
        case plugin.handle_input(input) do
          {:ok, updated_plugin} ->
            {:cont, {:ok, %{acc_manager | plugins: Map.put(acc_manager.plugins, plugin.name, updated_plugin)}}}
          {:error, reason} ->
            {:halt, {:error, "Plugin #{plugin.name} failed to handle input: #{reason}"}}
        end
      else
        {:cont, {:ok, acc_manager}}
      end
    end)
  end

  @doc """
  Processes output through all enabled plugins.
  Returns {:ok, manager, transformed_output} if a plugin transforms the output,
  or {:ok, manager} if no transformation is needed.
  """
  def process_output(%__MODULE__{} = manager, output) when is_binary(output) do
    Enum.reduce_while(manager.plugins, {:ok, manager, output}, fn {_name, plugin}, {:ok, acc_manager, acc_output} ->
      if plugin.enabled do
        case plugin.handle_output(output) do
          {:ok, updated_plugin} ->
            {:cont, {:ok, %{acc_manager | plugins: Map.put(acc_manager.plugins, plugin.name, updated_plugin)}, acc_output}}
          {:ok, updated_plugin, transformed_output} ->
            {:cont, {:ok, %{acc_manager | plugins: Map.put(acc_manager.plugins, plugin.name, updated_plugin)}, transformed_output}}
          {:error, reason} ->
            {:halt, {:error, "Plugin #{plugin.name} failed to handle output: #{reason}"}}
        end
      else
        {:cont, {:ok, acc_manager, acc_output}}
      end
    end)
  end

  @doc """
  Processes mouse events through all enabled plugins.
  """
  def process_mouse(%__MODULE__{} = manager, event) when is_tuple(event) do
    Enum.reduce_while(manager.plugins, {:ok, manager}, fn {_name, plugin}, {:ok, acc_manager} ->
      if plugin.enabled do
        case plugin.handle_mouse(event) do
          {:ok, updated_plugin} ->
            {:cont, {:ok, %{acc_manager | plugins: Map.put(acc_manager.plugins, plugin.name, updated_plugin)}}}
          {:error, reason} ->
            {:halt, {:error, "Plugin #{plugin.name} failed to handle mouse event: #{reason}"}}
        end
      else
        {:cont, {:ok, acc_manager}}
      end
    end)
  end

  @doc """
  Notifies all enabled plugins of a terminal resize event.
  """
  def handle_resize(%__MODULE__{} = manager, width, height) when is_integer(width) and is_integer(height) do
    Enum.reduce_while(manager.plugins, {:ok, manager}, fn {_name, plugin}, {:ok, acc_manager} ->
      if plugin.enabled do
        case plugin.handle_resize(width, height) do
          {:ok, updated_plugin} ->
            {:cont, {:ok, %{acc_manager | plugins: Map.put(acc_manager.plugins, plugin.name, updated_plugin)}}}
          {:error, reason} ->
            {:halt, {:error, "Plugin #{plugin.name} failed to handle resize: #{reason}"}}
        end
      else
        {:cont, {:ok, acc_manager}}
      end
    end)
  end

  @doc """
  Gets a list of all loaded plugins.
  """
  def list_plugins(%__MODULE__{} = manager) do
    Map.values(manager.plugins)
  end

  @doc """
  Gets a plugin by name.
  """
  def get_plugin(%__MODULE__{} = manager, name) when is_binary(name) do
    Map.get(manager.plugins, name)
  end
  
  @doc """
  Gets the current API version of the plugin manager.
  """
  def get_api_version(%__MODULE__{} = manager) do
    manager.api_version
  end
end 