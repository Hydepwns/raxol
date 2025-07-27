defmodule Raxol.Plugins.EventHandler.InputEvents do
  @moduledoc """
  Handles input-related events for plugins.
  """

  require Raxol.Core.Runtime.Log

  alias Raxol.Plugins.Manager.Core
  alias Raxol.Plugins.EventHandler.Common

  @type event :: map()
  @type manager :: Core.t()
  @type result :: {:ok, manager()} | {:error, term()}

  @doc """
  Dispatches an "input" event to all enabled plugins implementing `handle_input/2`.
  """
  @spec handle_input(Core.t(), binary()) :: result()
  def handle_input(manager, input) do
    initial_acc = %{manager: manager, input: input}

    result =
      Enum.reduce_while(manager.plugins, initial_acc, fn {_key, plugin}, acc ->
        Common.handle_plugin_event(
          plugin,
          :handle_input,
          [acc.input],
          2,
          acc,
          &handle_input_result/4
        )
      end)

    if is_map(result) do
      {:ok, result.manager}
    else
      result
    end
  end

  @doc """
  Dispatches a "key_event" to all enabled plugins implementing `handle_key_event/2`.
  """
  @spec handle_key_event(Core.t(), map()) :: result()
  def handle_key_event(%Core{} = manager, key_event) do
    initial_acc = %{manager: manager, key_event: key_event, commands: []}

    result =
      Common.dispatch_event(
        manager,
        :handle_key_event,
        [key_event],
        2,
        initial_acc,
        &handle_key_event_result/4
      )

    case result do
      %{manager: updated_manager} ->
        {:ok, updated_manager}

      error ->
        error
    end
  end

  # Private result handlers

  defp handle_input_result(acc, plugin, _callback_name, result) do
    case result do
      {:ok, _updated_plugin, updated_plugin_state} ->
        updated_manager =
          Common.update_manager_state(acc.manager, plugin, updated_plugin_state)

        {:cont, %{acc | manager: updated_manager}}

      {:ok, updated_plugin} ->
        updated_plugin_state = Common.extract_plugin_state(updated_plugin)

        updated_manager =
          Common.update_manager_state(acc.manager, plugin, updated_plugin_state)

        {:cont, %{acc | manager: updated_manager}}

      {:error, reason} ->
        Common.log_plugin_error(plugin, :handle_input, reason)
        {:cont, acc}

      {:halt, updated_plugin} ->
        updated_plugin_state = Common.extract_plugin_state(updated_plugin)

        updated_manager =
          Common.update_manager_state(acc.manager, plugin, updated_plugin_state)

        {:halt, %{acc | manager: updated_manager}}

      other ->
        Common.log_unexpected_result(plugin, :handle_input, other)
        {:cont, acc}
    end
  end

  defp handle_key_event_result(acc, plugin, _callback_name, result) do
    case result do
      {:ok, commands} when is_list(commands) ->
        {:cont, %{acc | commands: acc.commands ++ commands}}

      {:ok, command} ->
        {:cont, %{acc | commands: [command | acc.commands]}}

      {:halt, commands} when is_list(commands) ->
        {:halt, %{acc | commands: Enum.reverse(commands) ++ acc.commands}}

      {:halt, command} ->
        {:halt, %{acc | commands: [command | acc.commands]}}

      {:error, reason} ->
        Common.log_plugin_error(plugin, :handle_key_event, reason)
        {:cont, acc}

      other ->
        Common.log_unexpected_result(plugin, :handle_key_event, other)
        {:cont, acc}
    end
  end
end
