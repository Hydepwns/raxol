defmodule Raxol.System.Interaction do
  @moduledoc """
  Behaviour for abstracting system interactions like running commands,
  finding executables, and getting OS type. Allows for easier testing.
  """

  @type os_type :: {:unix, :linux} | {:unix, :darwin} | {:win32, :nt} | {:unix, atom()} | {:win32, atom()}

  @doc """
  Returns the OS type.
  """
  @callback get_os_type() :: os_type()

  @doc """
  Finds the full path to an executable. Returns `nil` if not found.
  """
  @callback find_executable(binary()) :: binary() | nil

  @doc """
  Executes a system command.
  Returns `{output, exit_status}` on success.
  Can raise exceptions on errors depending on the implementation.
  Options can be passed to control execution (e.g., `stderr_to_stdout`).
  """
  @callback system_cmd(binary(), list(binary()), list(atom() | tuple())) :: {binary(), integer()}
end
