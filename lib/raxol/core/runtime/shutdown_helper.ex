defmodule Raxol.Core.Runtime.ShutdownHelper do
  @moduledoc """
  Common utilities for graceful shutdown of runtime components.
  """

  @doc """
  Handles graceful shutdown of runtime components.
  """
  def handle_shutdown(module_name, state) do
    Raxol.Core.Runtime.Log.info_with_context(
      "[#{module_name}] Received :shutdown cast for #{inspect(state.app_name)}. Stopping dependent processes..."
    )

    case state.dispatcher_pid do
      nil ->
        :ok

      pid ->
        Raxol.Core.Runtime.Log.info_with_context(
          "[#{module_name}] Stopping Dispatcher PID: #{inspect(pid)}"
        )

        GenServer.stop(pid, :shutdown, :infinity)
    end

    case state.plugin_manager do
      nil ->
        :ok

      pid ->
        Raxol.Core.Runtime.Log.info_with_context(
          "[#{module_name}] Stopping PluginManager PID: #{inspect(pid)}"
        )

        GenServer.stop(pid, :shutdown, :infinity)
    end

    {:stop, :normal, state}
  end
end
