defmodule Raxol.Core.Runtime.Plugins.FileWatcherBehaviour do
  @moduledoc '''
  Behaviour defining the interface for file watching operations.
  '''

  @callback start_link(opts :: Keyword.t()) :: {:ok, pid()} | {:error, term()}
  @callback stop(pid :: pid()) :: :ok
  @callback watch_file(
              pid :: pid(),
              file_path :: String.t(),
              callback :: function()
            ) :: :ok | {:error, term()}
  @callback unwatch_file(pid :: pid(), file_path :: String.t()) ::
              :ok | {:error, term()}
  @callback get_watched_files(pid :: pid()) :: [String.t()]
  @callback setup_file_watching(pid :: pid()) :: :ok | {:error, term()}
end
