defmodule Raxol.Plugins.EventHandler.MouseEvents do
  @moduledoc """
  Handles mouse-related events for plugins.
  """

  require Raxol.Core.Runtime.Log

  alias Raxol.Plugins.Manager.Core
  alias Raxol.Plugins.EventHandler.Common

  @type manager :: Core.t()
  @type mouse_event :: map()
  @type result :: {:ok, manager()} | {:error, term()}

  @doc """
  Dispatches a "mouse_event" to all enabled plugins implementing `handle_mouse_event/3`.
  """
  @spec handle_mouse_event(Core.t(), mouse_event(), map()) :: result()
  def handle_mouse_event(%Core{} = manager, event, rendered_cells) do
    initial_acc = %{
      manager: manager,
      event: event,
      rendered_cells: rendered_cells,
      modified_cells: rendered_cells,
      halt_requested: false
    }

    result =
      Common.dispatch_event(
        manager,
        :handle_mouse_event,
        [event, rendered_cells],
        3,
        initial_acc,
        &handle_mouse_event_result/4
      )

    case result do
      %{manager: updated_manager} ->
        {:ok, updated_manager}

      error ->
        error
    end
  end

  @doc """
  Dispatches a "resize" event to all enabled plugins implementing `handle_resize/3`.
  """
  @spec handle_resize(Core.t(), non_neg_integer(), non_neg_integer()) ::
          result()
  def handle_resize(%Core{} = manager, width, height) do
    initial_acc = %{manager: manager, width: width, height: height}

    result =
      Common.dispatch_event(
        manager,
        :handle_resize,
        [width, height],
        3,
        initial_acc,
        &handle_resize_result/4
      )

    case result do
      %{manager: updated_manager} ->
        {:ok, updated_manager}

      error ->
        error
    end
  end

  # Private result handlers

  defp handle_mouse_event_result(acc, plugin, _callback_name, result) do
    case result do
      {:ok, modified_cells} when is_map(modified_cells) ->
        {:cont, %{acc | modified_cells: modified_cells}}

      {:ok, {updated_plugin, modified_cells}} when is_map(modified_cells) ->
        updated_plugin_state = Common.extract_plugin_state(updated_plugin)

        updated_manager =
          Common.update_manager_state(acc.manager, plugin, updated_plugin_state)

        {:cont,
         %{
           acc
           | manager: updated_manager,
             modified_cells: modified_cells
         }}

      {:ok, updated_plugin} ->
        updated_plugin_state = Common.extract_plugin_state(updated_plugin)

        updated_manager =
          Common.update_manager_state(acc.manager, plugin, updated_plugin_state)

        {:cont, %{acc | manager: updated_manager}}

      {:halt, modified_cells} when is_map(modified_cells) ->
        {:halt, %{acc | modified_cells: modified_cells, halt_requested: true}}

      {:halt, {updated_plugin, modified_cells}} when is_map(modified_cells) ->
        updated_plugin_state = Common.extract_plugin_state(updated_plugin)

        updated_manager =
          Common.update_manager_state(acc.manager, plugin, updated_plugin_state)

        {:halt,
         %{
           acc
           | manager: updated_manager,
             modified_cells: modified_cells,
             halt_requested: true
         }}

      {:error, reason} ->
        Common.log_plugin_error(plugin, :handle_mouse_event, reason)
        {:cont, acc}

      other ->
        Common.log_unexpected_result(plugin, :handle_mouse_event, other)
        {:cont, acc}
    end
  end

  defp handle_resize_result(acc, plugin, _callback_name, result) do
    case result do
      {:ok, updated_plugin} ->
        updated_plugin_state = Common.extract_plugin_state(updated_plugin)

        updated_manager =
          Common.update_manager_state(acc.manager, plugin, updated_plugin_state)

        {:cont, %{acc | manager: updated_manager}}

      {:error, reason} ->
        Common.log_plugin_error(plugin, :handle_resize, reason)
        {:cont, acc}

      other ->
        Common.log_unexpected_result(plugin, :handle_resize, other)
        {:cont, acc}
    end
  end
end
