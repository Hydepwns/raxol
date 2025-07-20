defmodule Raxol.Terminal.Buffer.Manager.ProcessManager do
  @moduledoc """
  Handles process-related operations for buffer managers.
  Extracted from Raxol.Terminal.Buffer.Manager to improve maintainability.
  """

  @doc """
  Gets the buffer manager PID for the current environment.
  """
  def get_buffer_manager_pid do
    if Mix.env() == :test do
      find_buffer_manager_in_test()
    else
      Raxol.Terminal.Buffer.Manager
    end
  end

  defp find_buffer_manager_in_test do
    case GenServer.whereis(Raxol.Terminal.Buffer.Manager) do
      nil -> find_buffer_manager_by_initial_call()
      pid -> pid
    end
  end

  defp find_buffer_manager_by_initial_call do
    case Process.list() |> Enum.find(&buffer_manager_process?/1) do
      nil -> raise "No buffer manager process found in test environment"
      pid -> pid
    end
  end

  defp buffer_manager_process?(pid) do
    case Process.info(pid, :initial_call) do
      {:initial_call, {Raxol.Terminal.Buffer.Manager, :init, 1}} -> true
      _ -> false
    end
  end
end
