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

    if state.dispatcher_pid do
      Raxol.Core.Runtime.Log.info_with_context(
        "[#{module_name}] Stopping Dispatcher PID: #{inspect(state.dispatcher_pid)}"
      )

      GenServer.stop(state.dispatcher_pid, :shutdown, :infinity)
    end

    if state.plugin_manager do
      Raxol.Core.Runtime.Log.info_with_context(
        "[#{module_name}] Stopping PluginManager PID: #{inspect(state.plugin_manager)}"
      )

      GenServer.stop(state.plugin_manager, :shutdown, :infinity)
    end

    {:stop, :normal, state}
  end
end
