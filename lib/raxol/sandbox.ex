defmodule Raxol.Sandbox do
  @moduledoc """
  Sandbox execution environment for untrusted code.

  Provides process isolation and resource limiting for running untrusted code safely.

  ## Example

      {:ok, result} = Raxol.Sandbox.execute(fn ->
        untrusted_code()
      end,
        timeout: 5000,
        memory_limit: 100_000_000,
        allowed_modules: [String, Enum]
      )

  ## Note

  This module provides basic sandboxing. For production use with untrusted code,
  consider additional security measures such as OS-level containerization.
  """

  @doc """
  Execute code in a sandboxed environment.

  ## Options

    - `:timeout` - Maximum execution time in milliseconds (default: 5000)
    - `:memory_limit` - Maximum memory in bytes (advisory, not enforced)
    - `:allowed_modules` - List of modules the code can use (not enforced in basic mode)

  ## Example

      {:ok, result} = Raxol.Sandbox.execute(fn ->
        String.upcase("hello")
      end, timeout: 1000)
  """
  @spec execute((-> any()), keyword()) :: {:ok, any()} | {:error, term()}
  def execute(fun, opts \\ []) when is_function(fun, 0) do
    timeout = Keyword.get(opts, :timeout, 5000)

    task =
      Task.async(fn ->
        try do
          {:ok, fun.()}
        rescue
          e -> {:error, {:exception, e}}
        catch
          :exit, reason -> {:error, {:exit, reason}}
        end
      end)

    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, result} -> result
      nil -> {:error, :timeout}
      {:exit, reason} -> {:error, {:exit, reason}}
    end
  end

  @doc """
  Check if sandbox mode is available.
  """
  @spec available?() :: boolean()
  def available?, do: true
end
