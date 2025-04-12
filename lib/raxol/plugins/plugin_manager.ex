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
    # Initialize with a default PluginConfig
    initial_config = PluginConfig.new()
    %__MODULE__{
      plugins: %{},
      config: initial_config,
      api_version: "1.0" # Set a default API version
    }
  end

  @doc """
  Loads a plugin module and initializes it with the given configuration.
  """
  def load_plugin(%__MODULE__{} = manager, module, config \\ %{})
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

    case module.init(merged_config) do
      {:ok, plugin} ->
        # Check API compatibility
        case PluginDependency.check_api_compatibility(
               plugin.api_version,
               manager.api_version
             ) do
          :ok ->
            # Check dependencies
            case PluginDependency.check_dependencies(
                   plugin,
                   list_plugins(manager)
                 ) do
              {:ok, _} ->
                # Update plugin config with merged config
                updated_config =
                  PluginConfig.update_plugin_config(
                    manager.config,
                    plugin_name,
                    merged_config
                  )

                # Save updated config
                case PluginConfig.save(updated_config) do
                  {:ok, saved_config} ->
                    %{
                      manager
                      | plugins: Map.put(manager.plugins, plugin.name, plugin),
                        config: saved_config
                    }

                  {:error, _reason} ->
                    # Continue even if save fails
                    %{
                      manager
                      | plugins: Map.put(manager.plugins, plugin.name, plugin)
                    }
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
    plugins =
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
            {:halt,
             {:error, "Failed to initialize plugin #{module}: #{reason}"}}
        end
      end)

    case plugins do
      {:ok, initialized_plugins} ->
        # Resolve dependencies to get the correct load order
        case PluginDependency.resolve_dependencies(initialized_plugins) do
          {:ok, sorted_plugin_names} ->
            # Load plugins in the correct order
            Enum.reduce_while(
              sorted_plugin_names,
              {:ok, manager},
              fn plugin_name, {:ok, acc_manager} ->
                # Find the plugin in initialized plugins
                case Enum.find(initialized_plugins, fn p ->
                       p.name == plugin_name
                     end) do
                  nil ->
                    {:halt,
                     {:error,
                      "Plugin #{plugin_name} not found in initialized plugins"}}

                  _plugin ->
                    # Load the plugin using its module name
                    case load_plugin(
                           acc_manager,
                           String.to_atom(
                             "Elixir.#{String.replace(plugin_name, "_", ".")}"
                           )
                         ) do
                      updated_manager when is_map(updated_manager) ->
                        {:cont, {:ok, updated_manager}}

                      {:error, reason} ->
                        {:halt,
                         {:error,
                          "Failed to load plugin #{plugin_name}: #{reason}"}}
                    end
                end
              end
            )

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
                %{
                  manager
                  | plugins: Map.delete(manager.plugins, name),
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
                %{
                  manager
                  | plugins:
                      Map.put(manager.plugins, plugin.name, %{
                        plugin
                        | enabled: true
                      }),
                    config: saved_config
                }

              {:error, _reason} ->
                # Continue even if save fails
                %{
                  manager
                  | plugins:
                      Map.put(manager.plugins, plugin.name, %{
                        plugin
                        | enabled: true
                      })
                }
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
            %{
              manager
              | plugins:
                  Map.put(manager.plugins, plugin.name, %{
                    plugin
                    | enabled: false
                  }),
                config: saved_config
            }

          {:error, _reason} ->
            # Continue even if save fails
            %{
              manager
              | plugins:
                  Map.put(manager.plugins, plugin.name, %{
                    plugin
                    | enabled: false
                  })
            }
        end
    end
  end

  @doc """
  Processes input through all enabled plugins.
  """
  def process_input(%__MODULE__{} = manager, input) when is_binary(input) do
    Enum.reduce_while(manager.plugins, {:ok, manager}, fn {_name, plugin},
                                                          {:ok, acc_manager} ->
      if plugin.enabled do
        case plugin.handle_input(input) do
          {:ok, updated_plugin} ->
            {:cont,
             {:ok,
              %{
                acc_manager
                | plugins:
                    Map.put(acc_manager.plugins, plugin.name, updated_plugin)
              }}}

          {:error, reason} ->
            {:halt,
             {:error, "Plugin #{plugin.name} failed to handle input: #{reason}"}}
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
    Enum.reduce_while(manager.plugins, {:ok, manager, output}, fn {_name,
                                                                   plugin},
                                                                  {:ok,
                                                                   acc_manager,
                                                                   acc_output} ->
      if plugin.enabled do
        case plugin.handle_output(output) do
          {:ok, updated_plugin} ->
            {:cont,
             {:ok,
              %{
                acc_manager
                | plugins:
                    Map.put(acc_manager.plugins, plugin.name, updated_plugin)
              }, acc_output}}

          {:ok, updated_plugin, transformed_output} ->
            {:cont,
             {:ok,
              %{
                acc_manager
                | plugins:
                    Map.put(acc_manager.plugins, plugin.name, updated_plugin)
              }, transformed_output}}

          {:error, reason} ->
            {:halt,
             {:error,
              "Plugin #{plugin.name} failed to handle output: #{reason}"}}
        end
      else
        {:cont, {:ok, acc_manager, acc_output}}
      end
    end)
  end

  @doc """
  Processes mouse events through all enabled plugins.
  """
  def process_mouse(%__MODULE__{} = manager, event, emulator_state) when is_tuple(event) do
    Enum.reduce_while(manager.plugins, {:ok, manager}, fn {_name, plugin},
                                                          {:ok, acc_manager} ->
      if plugin.enabled do
        case plugin.handle_mouse(event, emulator_state) do
          {:ok, updated_plugin} ->
            {:cont,
             {:ok,
              %{
                acc_manager
                | plugins:
                    Map.put(acc_manager.plugins, plugin.name, updated_plugin)
              }}}

          {:error, reason} ->
            {:halt,
             {:error,
              "Plugin #{plugin.name} failed to handle mouse event: #{reason}"}}
        end
      else
        {:cont, {:ok, acc_manager}}
      end
    end)
  end

  @doc """
  Notifies all enabled plugins of a terminal resize event.
  """
  def handle_resize(%__MODULE__{} = manager, width, height)
      when is_integer(width) and is_integer(height) do
    Enum.reduce_while(manager.plugins, {:ok, manager}, fn {_name, plugin},
                                                          {:ok, acc_manager} ->
      if plugin.enabled do
        case plugin.handle_resize(width, height) do
          {:ok, updated_plugin} ->
            {:cont,
             {:ok,
              %{
                acc_manager
                | plugins:
                    Map.put(acc_manager.plugins, plugin.name, updated_plugin)
              }}}

          {:error, reason} ->
            {:halt,
             {:error,
              "Plugin #{plugin.name} failed to handle resize: #{reason}"}}
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
  Runs render-related hooks for all enabled plugins.
  Collects any direct output commands (e.g., escape sequences) returned by plugins.
  Returns {:ok, updated_manager, list_of_output_commands}
  """
  def run_render_hooks(%__MODULE__{} = manager) do
    Enum.reduce(manager.plugins, {:ok, manager, []}, fn {_name, plugin}, {:ok, acc_manager, acc_commands} ->
      if plugin.enabled and function_exported?(plugin.__struct__, :handle_render, 1) do
        case plugin.handle_render() do
          {:ok, updated_plugin, command} when not is_nil(command) ->
            updated_manager = %{ acc_manager | plugins: Map.put(acc_manager.plugins, plugin.name, updated_plugin) }
            {:ok, updated_manager, [command | acc_commands]}

          {:ok, updated_plugin} -> # No command returned
            updated_manager = %{ acc_manager | plugins: Map.put(acc_manager.plugins, plugin.name, updated_plugin) }
            {:ok, updated_manager, acc_commands}

          # Allow plugins to just return the command if state doesn't change
          command when is_binary(command) ->
             {:ok, acc_manager, [command | acc_commands]}

          # Ignore other return values or errors for now
          _ ->
            {:ok, acc_manager, acc_commands}
        end
      else
        # Plugin disabled or doesn't implement hook
        {:ok, acc_manager, acc_commands}
      end
    end)
  end

  @doc """
  Gets the current API version of the plugin manager.
  """
  def get_api_version(%__MODULE__{} = manager) do
    manager.api_version
  end

  @doc """
  Updates the state of a specific plugin within the manager.
  The `update_fun` receives the current plugin state and should return the new state.
  """
  def update_plugin(%__MODULE__{} = manager, name, update_fun) when is_binary(name) and is_function(update_fun, 1) do
    case Map.get(manager.plugins, name) do
      nil ->
        {:error, "Plugin #{name} not found"}

      plugin ->
        try do
          new_plugin_state = update_fun.(plugin)
          # Basic validation: ensure it's still the same struct type
          if is_struct(new_plugin_state, plugin.__struct__) do
            updated_manager = %{manager | plugins: Map.put(manager.plugins, name, new_plugin_state)}
            {:ok, updated_manager}
          else
            {:error, "Update function returned invalid state for plugin #{name}"}
          end
        rescue
          e -> {:error, "Error updating plugin #{name}: #{inspect(e)}"}
        end
    end
  end

  @doc """
  Processes renderable cells through all enabled plugins.
  Plugins can modify cells or generate commands (e.g., escape sequences).
  Returns {:ok, updated_manager, processed_cells, list_of_commands, list_of_messages}
  """
  def process_cells(%__MODULE__{} = manager, cells) when is_list(cells) do
    initial_acc = {manager, cells, [], []} # {manager, processed_cells, commands, messages}

    final_acc = Enum.reduce(manager.plugins, initial_acc, fn
      {_name, plugin}, {acc_manager, acc_cells, acc_commands, acc_messages} ->
        if plugin.enabled and function_exported?(plugin.__struct__, :handle_cells, 2) do
          # Pass the current plugin state from acc_manager
          current_plugin_state = Map.get(acc_manager.plugins, plugin.name)
          module = plugin.__struct__ # Get the module atom

          # Call handle_cells using the module atom
          case module.handle_cells(current_plugin_state, acc_cells) do
            # Match the new 4-tuple return
            {updated_plugin_state, processed_cells, new_commands, msg} ->
              # Update the plugin state within the manager accumulator
              new_manager_state = %{acc_manager | plugins: Map.put(acc_manager.plugins, plugin.name, updated_plugin_state)}
              new_messages = if is_nil(msg), do: acc_messages, else: [msg | acc_messages]
              {new_manager_state, processed_cells, acc_commands ++ new_commands, new_messages}

            # Handle potential errors or unexpected returns gracefully (assume 3-tuple if 4-tuple fails)
            # TODO: Log this properly
            {updated_plugin_state, processed_cells, new_commands} ->
              new_manager_state = %{acc_manager | plugins: Map.put(acc_manager.plugins, plugin.name, updated_plugin_state)}
              {new_manager_state, processed_cells, acc_commands ++ new_commands, acc_messages} # No message added

            _other ->
              # Log error or warning?
              {acc_manager, acc_cells, acc_commands, acc_messages} # Pass through unchanged
          end
        else
          # Plugin disabled or doesn't implement handle_cells
          {acc_manager, acc_cells, acc_commands, acc_messages}
        end
    end)

    # Return the final state including messages
    {final_manager, final_cells, final_commands, final_messages} = final_acc
    # Reverse messages so they are in plugin processing order (though maybe not critical)
    {:ok, final_manager, final_cells, final_commands, Enum.reverse(final_messages)}
  end
end
