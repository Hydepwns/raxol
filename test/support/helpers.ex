defmodule TestHelpers do
  @moduledoc """
  Helper functions for tests.
  """

  def setup_runtime_environment(_context) do
    # Clean up any existing processes
    cleanup_runtime_processes()

    # Reset any global state
    reset_global_state()

    :ok
  end

  defp cleanup_runtime_processes do
    # Stop any running runtime processes
    if pid = Process.whereis(Raxol.Core.Runtime.Supervisor) do
      Process.exit(pid, :shutdown)
    end

    # Wait for processes to stop
    Process.sleep(100)
  end

  defp reset_global_state do
    # Reset any global state that might affect tests
    Application.put_env(:raxol, :test_mode, true)
    Application.put_env(:raxol, :plugin_manager_config, %{})
  end
end
