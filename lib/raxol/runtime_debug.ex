# <<< CHANGED MODULE NAME
defmodule Raxol.RuntimeDebug do
  @moduledoc """
  DEBUG VERSION of Raxol.Runtime.
  Manages the core runtime processes for a Raxol application.
  Starts and supervises the main components like EventLoop, ComponentManager, etc.
  """
  # This module acts as a GenServer, not the main Application
  use GenServer
  # Remove the conflicting behavior
  # use Raxol.App

  require Logger

  # Add @dialyzer directive to suppress unused function warnings
  @dialyzer {:nowarn_function,
   [
     send_plugin_commands: 1,
     render_view_to_cells: 2,
     p_handle_key_event: 2,
     p_handle_mouse_event: 2,
     update_dimensions_in_model: 3
   ]}

  # Placeholder implementation to allow compilation
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    Logger.info("[RuntimeDebug] Initializing with options: #{inspect(opts)}")
    {:ok, %{width: 80, height: 24, model: %{}, options: opts}}
  end

  # Placeholder implementation for handle_info to allow compilation
  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # If the quit_keys functionality from Raxol.App is needed, implement it directly
  def quit_keys do
    [:ctrl_c, :ctrl_d]
  end

  # Private helper functions needed by the module
  @doc """
  Send plugin commands to the runtime.
  """
  @dialyzer {:nowarn_function, send_plugin_commands: 1}
  defp send_plugin_commands(commands) when is_list(commands) do
    Logger.debug(
      "[RuntimeDebug.send_plugin_commands] Commands: #{inspect(commands)}"
    )

    :ok
  end

  @doc """
  Helper to render a view to screen cells.
  """
  @dialyzer {:nowarn_function, render_view_to_cells: 2}
  defp render_view_to_cells(view_elements, dims) do
    Logger.debug(
      "[RuntimeDebug.render_view_to_cells] View elements: #{inspect(view_elements)}"
    )

    Logger.debug(
      "[RuntimeDebug.render_view_to_cells] Dimensions: #{inspect(dims)}"
    )

    []
  end

  @doc """
  Private helper to handle key events.
  """
  @dialyzer {:nowarn_function, p_handle_key_event: 2}
  defp p_handle_key_event(key_event, state) do
    Logger.debug(
      "[RuntimeDebug.p_handle_key_event] Key event: #{inspect(key_event)}"
    )

    {:noreply, state}
  end

  @doc """
  Private helper to handle mouse events.
  """
  @dialyzer {:nowarn_function, p_handle_mouse_event: 2}
  defp p_handle_mouse_event(mouse_event, state) do
    Logger.debug(
      "[RuntimeDebug.p_handle_mouse_event] Mouse event: #{inspect(mouse_event)}"
    )

    {:noreply, state}
  end

  @doc """
  Update dimensions in the model.
  """
  @dialyzer {:nowarn_function, update_dimensions_in_model: 3}
  defp update_dimensions_in_model(model, width, height) do
    Logger.debug(
      "[RuntimeDebug.update_dimensions_in_model] Updating dimensions to #{width}x#{height}"
    )

    Map.merge(model, %{width: width, height: height})
  end
end
