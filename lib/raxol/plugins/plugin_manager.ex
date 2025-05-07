defmodule Raxol.Plugins.PluginManager do
  @moduledoc """
  Manages plugins for the Raxol terminal emulator.
  Handles plugin loading, lifecycle management, and event dispatching.
  """

  require Logger

  alias Raxol.Plugins.{Plugin, PluginConfig, PluginDependency, CellProcessor, EventHandler, Lifecycle}

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
  Delegates to `Raxol.Plugins.Lifecycle.load_plugin/3`.
  """
  def load_plugin(%__MODULE__{} = manager, module, config \\ %{}) when is_atom(module) do
    Lifecycle.load_plugin(manager, module, config)
  end

  @doc """
  Loads multiple plugins in the correct dependency order.
  Delegates to `Raxol.Plugins.Lifecycle.load_plugins/2`.
  """
  def load_plugins(%__MODULE__{} = manager, modules) when is_list(modules) do
    Lifecycle.load_plugins(manager, modules)
  end

  @doc """
  Unloads a plugin by name.
  Delegates to `Raxol.Plugins.Lifecycle.unload_plugin/2`.
  """
  def unload_plugin(%__MODULE__{} = manager, name) when is_binary(name) do
    Lifecycle.unload_plugin(manager, name)
  end

  @doc """
  Enables a plugin by name.
  Delegates to `Raxol.Plugins.Lifecycle.enable_plugin/2`.
  """
  def enable_plugin(%__MODULE__{} = manager, name) when is_binary(name) do
    Lifecycle.enable_plugin(manager, name)
  end

  @doc """
  Disables a plugin by name.
  Delegates to `Raxol.Plugins.Lifecycle.disable_plugin/2`.
  """
  def disable_plugin(%__MODULE__{} = manager, name) when is_binary(name) do
    Lifecycle.disable_plugin(manager, name)
  end

  @doc """
  Processes input through all enabled plugins.
  Delegates to `Raxol.Plugins.EventHandler.handle_input/2`.
  """
  def process_input(%__MODULE__{} = manager, input) when is_binary(input) do
    EventHandler.handle_input(manager, input)
  end

  @doc """
  Processes output through all enabled plugins.
  Returns {:ok, manager, transformed_output} if a plugin transforms the output,
  or {:ok, manager} if no transformation is needed.
  Delegates to `Raxol.Plugins.EventHandler.handle_output/2`.
  """
  def process_output(%__MODULE__{} = manager, output) when is_binary(output) do
    EventHandler.handle_output(manager, output)
  end

  @doc """
  Processes mouse events through all enabled plugins.
  Delegates to `Raxol.Plugins.EventHandler.handle_mouse_legacy/3`.
  """
  def process_mouse(%__MODULE__{} = manager, event, emulator_state)
      when is_tuple(event) do
    EventHandler.handle_mouse_legacy(manager, event, emulator_state)
  end

  @doc """
  Notifies all enabled plugins of a terminal resize event.
  Delegates to `Raxol.Plugins.EventHandler.handle_resize/3`.
  """
  def handle_resize(%__MODULE__{} = manager, width, height)
      when is_integer(width) and is_integer(height) do
    EventHandler.handle_resize(manager, width, height)
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
  Delegates to `Raxol.Plugins.EventHandler.handle_mouse_event/3`.
  """
  def handle_mouse_event(%__MODULE__{} = manager, event, rendered_cells)
      when is_map(event) do
    EventHandler.handle_mouse_event(manager, event, rendered_cells)
  end

  @doc """
  Allows plugins to process or replace cells generated by the renderer.
  Delegates processing to `Raxol.Plugins.CellProcessor`.

  Returns `{:ok, updated_manager, processed_cells, collected_commands}`.
  """
  def handle_cells(%__MODULE__{} = manager, cells, emulator_state)
      when is_list(cells) do
    # Delegate to the CellProcessor module
    Raxol.Plugins.CellProcessor.process(manager, cells, emulator_state)
  end

  @doc """
  Processes a keyboard event through all enabled plugins.
  Plugins can return commands and choose to halt propagation.
  Returns {:ok, updated_manager, list_of_commands, :propagate | :halt} or {:error, reason}.
  Delegates to `Raxol.Plugins.EventHandler.handle_key_event/3`.
  """
  def handle_key_event(%__MODULE__{} = manager, event, rendered_cells)
      when is_map(event) and event.type == :key do
    # Note: EventHandler.handle_key_event internally calls plugin's handle_input/2
    case EventHandler.handle_key_event(manager, event, rendered_cells) do
      {:ok, final_manager, final_commands, propagation_state} ->
        # Reverse commands to maintain original call order
        {:ok, final_manager, Enum.reverse(final_commands), propagation_state}

      # Pass through {:error, reason}
      error ->
        error
    end
  end
end
