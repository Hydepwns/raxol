defmodule Raxol.Plugins.Manager.State do
  @moduledoc """
  Handles plugin state management and updates.
  Provides functions for updating plugin state and managing plugin lifecycle states.
  """

  require Logger

  alias Raxol.Plugins.{Plugin, Lifecycle}
  alias Raxol.Plugins.Manager.Core

  @doc """
  Updates the state of a specific plugin within the manager.
  The `update_fun` receives the current plugin state and should return the new state.
  """
  def update_plugin(%Core{} = manager, name, update_fun)
      when is_binary(name) and is_function(update_fun, 1) do
    case Core.get_plugin(manager, name) do
      nil ->
        {:error, "Plugin #{name} not found"}

      plugin ->
        try do
          new_plugin_state = update_fun.(plugin)
          # Basic validation: ensure it's still the same struct type
          if is_struct(new_plugin_state, plugin.__struct__) do
            updated_manager = Core.update_plugins(
              manager,
              Map.put(manager.plugins, name, new_plugin_state)
            )

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
  Enables a plugin by name.
  Delegates to `Raxol.Plugins.Lifecycle.enable_plugin/2`.
  """
  def enable_plugin(%Core{} = manager, name) when is_binary(name) do
    Lifecycle.enable_plugin(manager, name)
  end

  @doc """
  Disables a plugin by name.
  Delegates to `Raxol.Plugins.Lifecycle.disable_plugin/2`.
  """
  def disable_plugin(%Core{} = manager, name) when is_binary(name) do
    Lifecycle.disable_plugin(manager, name)
  end

  @doc """
  Loads a plugin module and initializes it with the given configuration.
  Delegates to `Raxol.Plugins.Lifecycle.load_plugin/3`.
  """
  def load_plugin(%Core{} = manager, module, config \\ %{})
      when is_atom(module) do
    Lifecycle.load_plugin(manager, module, config)
  end

  @doc """
  Loads multiple plugins in the correct dependency order.
  Delegates to `Raxol.Plugins.Lifecycle.load_plugins/2`.
  """
  def load_plugins(%Core{} = manager, modules) when is_list(modules) do
    Lifecycle.load_plugins(manager, modules)
  end

  @doc """
  Unloads a plugin by name.
  Delegates to `Raxol.Plugins.Lifecycle.unload_plugin/2`.
  """
  def unload_plugin(%Core{} = manager, name) when is_binary(name) do
    Lifecycle.unload_plugin(manager, name)
  end
end
