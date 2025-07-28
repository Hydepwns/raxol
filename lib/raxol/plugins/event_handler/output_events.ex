defmodule Raxol.Plugins.EventHandler.OutputEvents do
  @moduledoc """
  Handles output-related events for plugins.
  """

  require Raxol.Core.Runtime.Log

  alias Raxol.Plugins.Manager.Core
  alias Raxol.Plugins.EventHandler.Common

  @type manager :: Core.t()
  @type result :: {:ok, manager(), binary()} | {:error, term()}

  @doc """
  Dispatches an "output" event to all enabled plugins implementing `handle_output/2`.
  """
  @spec handle_output(Core.t(), binary()) :: {:ok, Core.t(), binary()} | {:error, term()}
  def handle_output(manager, output) do
    initial_acc = %{
      manager: manager,
      output: output,
      transformed_output: output
    }

    result =
      Common.dispatch_event(
        manager,
        :handle_output,
        [output],
        2,
        initial_acc,
        &handle_output_result/4
      )

    case result do
      %{manager: updated_manager, transformed_output: transformed_output} ->
        {:ok, updated_manager, transformed_output}

      error ->
        error
    end
  end

  # Private result handlers

  defp handle_output_result(acc, plugin, _callback_name, result) do
    case result do
      {:ok, transformed_output} when is_binary(transformed_output) ->
        {:cont, %{acc | transformed_output: transformed_output}}

      {:ok, {updated_plugin, transformed_output}}
      when is_binary(transformed_output) ->
        updated_plugin_state = Common.extract_plugin_state(updated_plugin)

        updated_manager =
          Common.update_manager_state(acc.manager, plugin, updated_plugin_state)

        {:cont,
         %{
           acc
           | manager: updated_manager,
             transformed_output: transformed_output
         }}

      {:ok, updated_plugin} ->
        updated_plugin_state = Common.extract_plugin_state(updated_plugin)

        updated_manager =
          Common.update_manager_state(acc.manager, plugin, updated_plugin_state)

        {:cont, %{acc | manager: updated_manager}}

      {:error, reason} ->
        Common.log_plugin_error(plugin, :handle_output, reason)
        {:cont, acc}

      {:halt, transformed_output} when is_binary(transformed_output) ->
        {:halt, %{acc | transformed_output: transformed_output}}

      {:halt, {updated_plugin, transformed_output}}
      when is_binary(transformed_output) ->
        updated_plugin_state = Common.extract_plugin_state(updated_plugin)

        updated_manager =
          Common.update_manager_state(acc.manager, plugin, updated_plugin_state)

        {:halt,
         %{
           acc
           | manager: updated_manager,
             transformed_output: transformed_output
         }}

      other ->
        Common.log_unexpected_result(plugin, :handle_output, other)
        {:cont, acc}
    end
  end
end
