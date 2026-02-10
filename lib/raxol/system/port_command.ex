defmodule Raxol.System.PortCommand do
  @moduledoc """
  Utility for running external commands with stdin input via Port.

  This module provides a way to execute external commands and pass
  data to their stdin, which System.cmd/3 doesn't support directly.
  """

  @doc """
  Runs a command with the given arguments, passing input to stdin.

  Returns `{:ok, output}` on success (exit code 0) or `{:error, output}` on failure.

  ## Options

  - `:timeout` - Maximum time to wait for the command in milliseconds (default: 30000)

  ## Examples

      iex> PortCommand.run("cat", [], "hello")
      {:ok, "hello"}

      iex> PortCommand.run("grep", ["pattern"], "no match here")
      {:error, ""}
  """
  @spec run(String.t(), [String.t()], String.t(), keyword()) ::
          {:ok, String.t()} | {:error, String.t()}
  def run(command, args, input, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 30_000)

    case System.find_executable(command) do
      nil ->
        {:error, "command not found: #{command}"}

      executable ->
        port =
          Port.open(
            {:spawn_executable, executable},
            [:binary, :exit_status, :stderr_to_stdout, {:args, args}]
          )

        Port.command(port, input)
        Port.close(port)
        collect_output(port, "", timeout)
    end
  end

  @spec collect_output(port(), String.t(), non_neg_integer()) ::
          {:ok, String.t()} | {:error, String.t()}
  defp collect_output(port, acc, timeout) do
    receive do
      {^port, {:data, data}} ->
        collect_output(port, acc <> data, timeout)

      {^port, {:exit_status, 0}} ->
        {:ok, acc}

      {^port, {:exit_status, _status}} ->
        {:error, acc}
    after
      timeout ->
        {:error, "timeout waiting for command"}
    end
  end
end
