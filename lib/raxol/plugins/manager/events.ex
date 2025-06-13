defmodule Raxol.Plugins.Manager.Events do
  @moduledoc """
  Handles plugin event processing.
  Provides functions for processing various types of events through plugins.
  """

  require Raxol.Core.Runtime.Log

  alias Raxol.Plugins.EventHandler
  alias Raxol.Plugins.Manager.Core

  @doc """
  Processes input through all enabled plugins.
  Delegates to `Raxol.Plugins.EventHandler.handle_input/2`.
  """
  def process_input(%Core{} = manager, input) when is_binary(input) do
    EventHandler.handle_input(manager, input)
  end

  @doc """
  Processes output through all enabled plugins.
  Returns {:ok, manager, transformed_output} if a plugin transforms the output,
  or {:ok, manager} if no transformation is needed.
  Delegates to `Raxol.Plugins.EventHandler.handle_output/2`.
  """
  def process_output(%Core{} = manager, output) when is_binary(output) do
    EventHandler.handle_output(manager, output)
  end

  @doc """
  Processes mouse events through all enabled plugins.
  Delegates to `Raxol.Plugins.EventHandler.handle_mouse_event/3`.

  @deprecated "Use handle_mouse_event/3 instead. This function will be removed in a future version."
  """
  def process_mouse(%Core{} = manager, event, emulator_state)
      when is_tuple(event) do
    # Convert tuple event to map format
    event_map = case event do
      {x, y, button, modifiers} -> %{
        type: :mouse,
        x: x,
        y: y,
        button: button,
        modifiers: modifiers
      }
      _ -> event
    end

    # Use the new handler
    case handle_mouse_event(manager, event_map, emulator_state) do
      {:ok, updated_manager, _propagation} -> {:ok, updated_manager}
      error -> error
    end
  end

  @doc """
  Notifies all enabled plugins of a terminal resize event.
  Delegates to `Raxol.Plugins.EventHandler.handle_resize/3`.
  """
  def handle_resize(%Core{} = manager, width, height)
      when is_integer(width) and is_integer(height) do
    EventHandler.handle_resize(manager, width, height)
  end

  @doc """
  Processes a mouse event through all enabled plugins, providing cell context.
  Plugins can choose to halt propagation if they handle the event.
  Returns {:ok, updated_manager, :propagate | :halt} or {:error, reason}.
  Delegates to `Raxol.Plugins.EventHandler.handle_mouse_event/3`.
  """
  def handle_mouse_event(%Core{} = manager, event, rendered_cells)
      when is_map(event) do
    EventHandler.handle_mouse_event(manager, event, rendered_cells)
  end

  @doc """
  Broadcasts an event to all enabled plugins.
  Returns {:ok, updated_manager} or {:error, reason}.
  """
  def broadcast_event(%Core{} = manager, event) do
    Enum.reduce_while(manager.plugins, {:ok, manager}, fn {_name, plugin},
                                                          {:ok, acc_manager} ->
      if plugin.enabled do
        # Get the module from the struct
        module = plugin.__struct__

        # Check if module implements handle_event
        if function_exported?(module, :handle_event, 2) do
          case module.handle_event(plugin, event) do
            {:ok, updated_plugin} ->
              updated_manager =
                Core.update_plugins(
                  acc_manager,
                  Map.put(acc_manager.plugins, plugin.name, updated_plugin)
                )

              {:cont, {:ok, updated_manager}}

            {:error, reason} ->
              {:halt, {:error, reason}}
          end
        else
          # Plugin doesn't implement event handling
          {:cont, {:ok, acc_manager}}
        end
      else
        # Plugin disabled
        {:cont, {:ok, acc_manager}}
      end
    end)
  end

  @doc """
  Loads a plugin module and initializes it. Delegates to `Raxol.Plugins.Manager.Core.load_plugin/2` or `/3`.
  Returns `{:ok, updated_manager}` or `{:error, reason}`.
  """
  def load_plugin(%Core{} = manager, module) when is_atom(module) do
    Core.load_plugin(manager, module)
  end

  def load_plugin(%Core{} = manager, module, config)
      when is_atom(module) and is_map(config) do
    Core.load_plugin(manager, module, config)
  end

  def new do
    Core.new()
  end
end
