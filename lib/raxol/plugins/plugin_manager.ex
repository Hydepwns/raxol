defmodule Raxol.Plugins.PluginManager do
  @moduledoc """
  Manages plugins for the Raxol terminal emulator.
  Handles plugin loading, lifecycle management, and event dispatching.
  """

  require Logger

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
      # Set a default API version
      api_version: "1.0"
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
                    {:ok,
                     %{
                       manager
                       | plugins: Map.put(manager.plugins, plugin.name, plugin),
                         config: saved_config
                     }}

                  {:error, _reason} ->
                    # Continue even if save fails, return manager with plugin loaded
                    {:ok,
                     %{
                       manager
                       | plugins: Map.put(manager.plugins, plugin.name, plugin)
                         # Maybe log the config save error here?
                     }}
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
                      # Match on {:ok, updated_manager} now
                      {:ok, updated_manager} ->
                        {:cont, {:ok, updated_manager}}

                      # Handle the direct manager return case (if any remain after fixing load_plugin/2)
                      updated_manager when is_map(updated_manager) ->
                        Logger.warning(
                          "load_plugin returned manager directly, expected {:ok, manager}",
                          plugin: plugin_name
                        )

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
        # Get module from struct BEFORE calling cleanup
        module = plugin.__struct__
        # Call cleanup on the module, passing the plugin state
        case module.cleanup(plugin) do
          :ok ->
            # Update config to disable plugin
            updated_config = PluginConfig.disable_plugin(manager.config, name)

            # Save updated config
            case PluginConfig.save(updated_config) do
              {:ok, saved_config} ->
                # Return {:ok, updated_manager}
                {:ok,
                 %{
                   manager
                   | plugins: Map.delete(manager.plugins, name),
                     config: saved_config
                 }}

              {:error, _reason} ->
                # Continue even if save fails, but still return {:ok, updated_manager}
                {:ok, %{manager | plugins: Map.delete(manager.plugins, name)}}
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
        # Get module from struct BEFORE calling handle_output
        module = plugin.__struct__
        # Call handle_output on the module, passing plugin state and output
        case module.handle_output(plugin, output) do
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
  def process_mouse(%__MODULE__{} = manager, event, emulator_state)
      when is_tuple(event) do
    Enum.reduce_while(manager.plugins, {:ok, manager}, fn {_name, plugin},
                                                          {:ok, acc_manager} ->
      if plugin.enabled do
        # Get module from struct BEFORE calling handle_mouse
        module = plugin.__struct__
        # Check if module implements handle_mouse/3
        if function_exported?(module, :handle_mouse, 3) do
          # Call handle_mouse on the module, passing plugin state, event, and emulator_state
          case module.handle_mouse(plugin, event, emulator_state) do
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
          # Plugin disabled or doesn't implement handle_mouse/3, continue
          {:cont, {:ok, acc_manager}}
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
        # Get module from struct BEFORE calling handle_resize
        module = plugin.__struct__
        # Check if module implements handle_resize/3
        if function_exported?(module, :handle_resize, 3) do
          # Call handle_resize on the module, passing plugin state, width, and height
          case module.handle_resize(plugin, width, height) do
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
          # Plugin disabled or doesn't implement handle_resize/3, continue
          {:cont, {:ok, acc_manager}}
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
    Enum.reduce(manager.plugins, {:ok, manager, []}, fn {_name, plugin},
                                                        {:ok, acc_manager,
                                                         acc_commands} ->
      if plugin.enabled do
        # Get the module from the struct
        module = plugin.__struct__

        # Check if module implements handle_render
        if function_exported?(module, :handle_render, 1) do
          # Call using the module with plugin state as first argument
          case module.handle_render(plugin) do
            {:ok, updated_plugin, command} when not is_nil(command) ->
              updated_manager = %{
                acc_manager
                | plugins:
                    Map.put(acc_manager.plugins, plugin.name, updated_plugin)
              }

              {:ok, updated_manager, [command | acc_commands]}

            # No command returned
            {:ok, updated_plugin} ->
              updated_manager = %{
                acc_manager
                | plugins:
                    Map.put(acc_manager.plugins, plugin.name, updated_plugin)
              }

              {:ok, updated_manager, acc_commands}

            # Allow plugins to just return the command if state doesn't change
            command when is_binary(command) ->
              {:ok, acc_manager, [command | acc_commands]}

            # Ignore other return values or errors for now
            _ ->
              {:ok, acc_manager, acc_commands}
          end
        else
          # Plugin doesn't implement hook
          {:ok, acc_manager, acc_commands}
        end
      else
        # Plugin disabled
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
  def update_plugin(%__MODULE__{} = manager, name, update_fun)
      when is_binary(name) and is_function(update_fun, 1) do
    case Map.get(manager.plugins, name) do
      nil ->
        {:error, "Plugin #{name} not found"}

      plugin ->
        try do
          new_plugin_state = update_fun.(plugin)
          # Basic validation: ensure it's still the same struct type
          if is_struct(new_plugin_state, plugin.__struct__) do
            updated_manager = %{
              manager
              | plugins: Map.put(manager.plugins, name, new_plugin_state)
            }

            {:ok, updated_manager}
          else
            {:error,
             "Update function returned invalid state for plugin #{name}"}
          end
        rescue
          e -> {:error, "Error updating plugin #{name}: #{inspect(e)}"}
        end
    end
  end

  @doc """
  Processes a mouse event through all enabled plugins, providing cell context.
  Plugins can choose to halt propagation if they handle the event.
  Returns {:ok, updated_manager, :propagate | :halt} or {:error, reason}.
  """
  def handle_mouse_event(%__MODULE__{} = manager, event, rendered_cells)
      when is_map(event) do
    # Reduce over enabled plugins, stopping if one halts
    Enum.reduce_while(manager.plugins, {:ok, manager, :propagate}, fn
      {_name, plugin}, {:ok, acc_manager, _propagation_state} ->
        if plugin.enabled and
             function_exported?(plugin.__struct__, :handle_mouse, 3) do
          # Pass the current plugin state, the event map, and the rendered cell context
          current_plugin_state = Map.get(acc_manager.plugins, plugin.name)
          module = plugin.__struct__

          case module.handle_mouse(current_plugin_state, event, rendered_cells) do
            {:ok, updated_plugin_state, :propagate} ->
              new_manager_state = %{
                acc_manager
                | plugins:
                    Map.put(
                      acc_manager.plugins,
                      plugin.name,
                      updated_plugin_state
                    )
              }

              # Continue processing other plugins
              {:cont, {:ok, new_manager_state, :propagate}}

            {:ok, updated_plugin_state, :halt} ->
              new_manager_state = %{
                acc_manager
                | plugins:
                    Map.put(
                      acc_manager.plugins,
                      plugin.name,
                      updated_plugin_state
                    )
              }

              # Halt processing, this plugin handled it
              {:halt, {:ok, new_manager_state, :halt}}

            {:error, reason} ->
              Logger.error(
                "Error from plugin #{plugin.name} in handle_mouse: #{inspect(reason)}"
              )

              # Halt with an error
              {:halt, {:error, reason}}

            # Invalid return from plugin
            _ ->
              Logger.warning(
                "Invalid return from #{plugin.name}.handle_mouse/3. Propagating."
              )

              # Continue, assuming propagate
              {:cont, {:ok, acc_manager, :propagate}}
          end
        else
          # Plugin disabled or doesn't implement handle_mouse/3, continue
          {:cont, {:ok, acc_manager, :propagate}}
        end
    end)
  end

  @doc """
  Allows plugins to process or replace cells generated by the renderer.
  Iterates through enabled plugins that implement `handle_cells/3`.
  The callback should return `{:ok, updated_plugin_state, cells_to_render, commands}`.

  Returns `{:ok, updated_manager, processed_cells, collected_commands}`.
  """
  def handle_cells(%__MODULE__{} = manager, cells, emulator_state)
      when is_list(cells) do
    Logger.debug(
      "[PluginManager.handle_cells] Processing #{length(cells)} cells..."
    )

    # Accumulator: {updated_manager, processed_cells_list_reversed, collected_commands_list}
    initial_acc = {manager, [], []}

    {final_manager, final_cells_rev, final_commands} =
      Enum.reduce(cells, initial_acc, fn cell,
                                         {acc_manager, processed_cells_rev,
                                          acc_commands} ->
        # Check if the cell is a placeholder potentially handled by a plugin
        case cell do
          %{type: :placeholder, value: placeholder_value} = placeholder_cell ->
            Logger.debug(
              "[PluginManager.handle_cells] Found placeholder: #{inspect(placeholder_value)}"
            )

            # Find plugins that might handle this placeholder type
            # Inner accumulator: {handled_flag, manager_state, list_of_replacement_cells, list_of_new_commands}
            # Default replacement_cells to an empty list, signifying removal if not handled.
            # Start inner loop with current outer loop manager state
            inner_initial_acc = {false, acc_manager, [], []}

            # Result of inner loop: {handled_flag, manager_state_after_inner_loop, replacement_cells_list, new_commands_list}
            # Find the specific plugin based on the placeholder value
            plugin_name =
              case placeholder_value do
                :image -> "image"
                :chart -> "visualization"
                :treemap -> "visualization"
                # Unknown placeholder type
                _ -> nil
              end

            {_plugin_handled, manager_after_inner_loop, replacement_cells,
             new_commands} =
              if plugin_name do
                # Get the specific plugin state
                case Map.get(acc_manager.plugins, plugin_name) do
                  nil ->
                    Logger.warning(
                      "[PluginManager.handle_cells] Plugin '#{plugin_name}' not loaded for placeholder '#{placeholder_value}'. Skipping."
                    )

                    # Return default accumulator if plugin not found
                    inner_initial_acc

                  plugin ->
                    # Call only the relevant plugin's handle_cells
                    if plugin.enabled and
                         function_exported?(plugin.__struct__, :handle_cells, 3) do
                      # Log state *before* calling plugin, especially for ImagePlugin
                      if plugin_name == "image" do
                        Logger.debug(
                          "[PluginManager.handle_cells] Before calling ImagePlugin.handle_cells. sequence_just_generated: #{inspect(Map.get(plugin, :sequence_just_generated))}"
                        )
                      end

                      # Log the opts specifically
                      Logger.debug(
                        "[PluginManager.handle_cells] Placeholder opts: #{inspect(Map.get(placeholder_cell, :opts))}"
                      )

                      Logger.debug(
                        "[PluginManager.handle_cells] Calling #{plugin_name}.handle_cells for placeholder...\nCELL DATA: #{inspect(placeholder_cell)}"
                      )

                      try do
                        # Assign result to variable first
                        handle_cells_result =
                          plugin.__struct__.handle_cells(
                            placeholder_cell,
                            emulator_state,
                            plugin
                          )

                        # Now match on the result variable
                        case handle_cells_result do
                          # Plugin handled it, returning cells and commands
                          {:ok, updated_plugin_state, plugin_cells,
                           plugin_commands}
                          when is_list(plugin_cells) ->
                            if plugin_name == "image" do
                              Logger.debug(
                                "[PluginManager.handle_cells] After ImagePlugin.handle_cells returned {:ok, ...}. sequence_just_generated: #{inspect(Map.get(updated_plugin_state, :sequence_just_generated))}"
                              )
                            end

                            Logger.debug(
                              "[PluginManager.handle_cells] Plugin #{plugin_name} handled placeholder. Cells: #{length(plugin_cells)}, Commands: #{length(plugin_commands)}"
                            )

                            # Update manager state
                            updated_inner_manager = %{
                              acc_manager
                              | plugins:
                                  Map.put(
                                    acc_manager.plugins,
                                    plugin_name,
                                    updated_plugin_state
                                  )
                            }

                            # Return the result for the outer loop (handled = true)
                            {true, updated_inner_manager, plugin_cells,
                             plugin_commands}

                          # Plugin declined or returned unexpected success format
                          {:ok, updated_plugin_state, _invalid_cells,
                           plugin_commands} ->
                            Logger.warning(
                              "[PluginManager.handle_cells] Plugin #{plugin_name} handled placeholder but returned invalid cell format. Treating as decline."
                            )

                            # Update manager state
                            updated_inner_manager = %{
                              acc_manager
                              | plugins:
                                  Map.put(
                                    acc_manager.plugins,
                                    plugin_name,
                                    updated_plugin_state
                                  )
                            }

                            # Return default accumulator (handled = false), but with updated manager and commands
                            {false, updated_inner_manager, [], plugin_commands}

                          # Handle cases where plugin declines (:cont)
                          {:cont, updated_plugin_state} ->
                            Logger.debug(
                              "[PluginManager.handle_cells] Plugin #{plugin_name} returned :cont. State Flag: #{inspect(Map.get(updated_plugin_state, :sequence_just_generated))}"
                            )

                            if plugin_name == "image" do
                              Logger.debug(
                                "[PluginManager.handle_cells] After ImagePlugin.handle_cells returned {:cont, ...}. sequence_just_generated: #{inspect(Map.get(updated_plugin_state, :sequence_just_generated))}"
                              )
                            end

                            Logger.debug(
                              "[PluginManager.handle_cells] Plugin #{plugin_name} declined placeholder."
                            )

                            # Update manager state
                            updated_inner_manager = %{
                              acc_manager
                              | plugins:
                                  Map.put(
                                    acc_manager.plugins,
                                    plugin_name,
                                    updated_plugin_state
                                  )
                            }

                            # Return default accumulator (handled = false), but with updated manager
                            {false, updated_inner_manager, [], []}

                          # {:error, _} or other unexpected return
                          _ ->
                            Logger.warning(
                              "[PluginManager.handle_cells] Plugin #{plugin_name} returned unexpected value from handle_cells. Skipping."
                            )

                            # Return default accumulator
                            inner_initial_acc
                        end
                      rescue
                        e ->
                          Logger.error(
                            "[PluginManager.handle_cells] RESCUED Error calling #{plugin_name}.handle_cells: #{inspect(e)}. Placeholder was: #{inspect(placeholder_cell)}"
                          )

                          # Return default accumulator
                          inner_initial_acc
                      end

                      # End try/rescue
                    else
                      # Plugin exists but is disabled or doesn't implement handle_cells
                      Logger.debug(
                        "[PluginManager.handle_cells] Plugin '#{plugin_name}' disabled or does not implement handle_cells/3. Skipping."
                      )

                      inner_initial_acc
                    end

                    # End if plugin enabled/implements
                end

                # End case Map.get plugin
              else
                # No plugin name determined for this placeholder value
                Logger.warning(
                  "[PluginManager.handle_cells] Unknown placeholder value: #{placeholder_value}. Skipping."
                )

                inner_initial_acc
              end

            # End if plugin_name

            # Return the accumulator for the NEXT outer loop iteration.
            # Use the manager state resulting from the inner processing.
            {manager_after_inner_loop, replacement_cells ++ processed_cells_rev,
             acc_commands ++ new_commands}

          # Original cell was not a placeholder, assume it's {x, y, map}
          valid_cell ->
            # Prepend to the reversed list, pass original acc_manager forward
            {acc_manager, [valid_cell | processed_cells_rev], acc_commands}
        end
      end)

    # End of outer Enum.reduce

    final_cells = Enum.reverse(final_cells_rev)

    Logger.debug(
      "[PluginManager.handle_cells] Finished. Final Cells: #{length(final_cells)}, Commands: #{length(final_commands)}"
    )

    # Return the final manager state accumulated through the outer loop
    {:ok, final_manager, final_cells, final_commands}
  end

  @doc """
  Processes a keyboard event through all enabled plugins.
  Plugins can return commands and choose to halt propagation.
  Returns {:ok, updated_manager, list_of_commands, :propagate | :halt} or {:error, reason}.
  """
  def handle_key_event(%__MODULE__{} = manager, event, _rendered_cells)
      when is_map(event) and event.type == :key do
    # Reduce over enabled plugins, collecting commands and stopping if one halts
    # {status, manager, commands, propagation}
    initial_acc = {:ok, manager, [], :propagate}

    Enum.reduce_while(manager.plugins, initial_acc, fn
      {_name, plugin}, {:ok, acc_manager, acc_commands, _propagation_state} ->
        if plugin.enabled and
             function_exported?(plugin.__struct__, :handle_input, 2) do
          # Pass the current plugin state and the event map
          # NOTE: We are passing the *event map* to handle_input, which expects a string.
          # This is a temporary adaptation. Ideally, a new callback like handle_key_event
          # should be defined in the Plugin behaviour.
          current_plugin_state = Map.get(acc_manager.plugins, plugin.name)
          module = plugin.__struct__

          case module.handle_input(current_plugin_state, event) do
            # Plugin returns {:ok, state, command}
            {:ok, updated_plugin_state, {:command, command_data}} ->
              new_manager_state = %{
                acc_manager
                | plugins:
                    Map.put(
                      acc_manager.plugins,
                      plugin.name,
                      updated_plugin_state
                    )
              }

              # Continue processing, add command, assume propagation (plugin didn't explicitly halt)
              {:cont,
               {:ok, new_manager_state, [command_data | acc_commands],
                :propagate}}

            # Plugin returns {:ok, state} (no command)
            {:ok, updated_plugin_state} ->
              new_manager_state = %{
                acc_manager
                | plugins:
                    Map.put(
                      acc_manager.plugins,
                      plugin.name,
                      updated_plugin_state
                    )
              }

              # Continue processing, no command added
              {:cont, {:ok, new_manager_state, acc_commands, :propagate}}

            # TODO: Add support for explicit :halt if needed
            # {:ok, updated_plugin_state, :halt} -> ...
            # {:ok, updated_plugin_state, {:command, cmd}, :halt} -> ...

            {:error, reason} ->
              Logger.error(
                "Error from plugin #{plugin.name} in handle_input: #{inspect(reason)}"
              )

              # Halt with an error
              {:halt, {:error, reason}}

            # Invalid return from plugin
            _ ->
              Logger.warning(
                "Invalid return from #{plugin.name}.handle_input/2. Propagating."
              )

              # Continue, assuming propagate
              {:cont, {:ok, acc_manager, acc_commands, :propagate}}
          end
        else
          # Plugin disabled or doesn't implement handle_input/2, continue
          {:cont, {:ok, acc_manager, acc_commands, :propagate}}
        end
    end)
    # Reverse commands to maintain order? Depends on processing logic.
    |> case do
      {:ok, final_manager, final_commands, propagation_state} ->
        {:ok, final_manager, Enum.reverse(final_commands), propagation_state}

      # Pass through {:error, reason}
      error ->
        error
    end
  end
end
