defmodule FileSystem.Behaviour do
  @moduledoc '''
  Defines the behaviour for file system watching functionality.
  This is used for mocking in tests.
  '''

  @doc '''
  Starts a file system watcher for the given directories.
  '''
  @callback start_link(dirs: [String.t()]) :: {:ok, pid()} | {:error, term()}

  @doc '''
  Subscribes to file system events from the watcher.
  '''
  @callback subscribe(pid()) :: :ok | {:error, term()}
end
