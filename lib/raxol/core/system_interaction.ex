defmodule Raxol.Core.SystemInteraction do
  @moduledoc """
  Defines a behaviour for interacting with the operating system, allowing for mocking.
  """

  @doc "Returns the OS type like :os.type()"
  @callback get_os_type() :: {:unix, atom()} | {:win32, atom()}

  @doc "Finds an executable like System.find_executable/1"
  @callback find_executable(binary()) :: binary() | nil

  @doc "Executes a system command like System.cmd/3"
  @callback system_cmd(binary(), [binary()], keyword()) ::
              {binary(), non_neg_integer()}
end
