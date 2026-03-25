defmodule Raxol.Core.Runtime.Lifecycle.Shutdown do
  @moduledoc """
  Shutdown, cleanup, and registry management helpers for Lifecycle.
  Extracted from Lifecycle to reduce file size.
  """

  alias Raxol.Core.CompilerState
  alias Raxol.Core.Runtime.Log

  @doc """
  Stops a supervised process by PID; no-ops on nil or dead processes.
  """
  def stop_process(nil, _label), do: :ok

  def stop_process(pid, label) when is_pid(pid) do
    if Process.alive?(pid) do
      Log.info_with_context(
        "[Lifecycle] Stopping #{label} PID: #{inspect(pid)}"
      )

      GenServer.stop(pid, :shutdown, 5_000)
    end
  rescue
    _ -> :ok
  end

  @doc """
  Cleans up the PluginManager if it is still alive.
  """
  def cleanup_plugin_manager(nil, _state), do: :ok
  def cleanup_plugin_manager(false, _state), do: :ok

  def cleanup_plugin_manager(true, state) do
    Log.info_with_context(
      "[Lifecycle] Terminate: Ensuring PluginManager PID #{inspect(state.plugin_manager)} is stopped."
    )

    case Raxol.Core.ErrorHandling.safe_call(fn ->
           GenServer.stop(state.plugin_manager, :shutdown, :infinity)
         end) do
      {:ok, _result} ->
        :ok

      {:error, _reason} ->
        Log.warning_with_context(
          "[Lifecycle] Terminate: Failed to explicitly stop PluginManager #{inspect(state.plugin_manager)}, it might have already stopped.",
          %{}
        )
    end
  end

  @doc """
  Deletes the command registry ETS table if it exists.
  """
  def cleanup_registry_table(nil, _state), do: :ok
  def cleanup_registry_table(false, _state), do: :ok

  def cleanup_registry_table(true, state) do
    case CompilerState.safe_delete_table(state.command_registry_table) do
      :ok ->
        Log.debug(
          "[Lifecycle] Deleted ETS table: #{inspect(state.command_registry_table)}"
        )

      {:error, :table_not_found} ->
        Log.debug(
          "[Lifecycle] ETS table #{inspect(state.command_registry_table)} not found or already deleted."
        )
    end
  end
end
