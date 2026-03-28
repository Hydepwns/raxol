defmodule Raxol.Core.Runtime.Plugins.FileWatcherBehaviour do
  @moduledoc """
  Behavior for file watcher plugins.
  """

  @doc """
  Callback for handling file change events.
  """
  @callback handle_file_change(file_path :: String.t(), change_type :: atom()) ::
              :ok | {:error, term()}

  @doc """
  Callback for starting the file watcher.
  """
  @callback start_watching(paths :: list(String.t()), opts :: keyword()) ::
              {:ok, pid()} | {:error, term()}

  @doc """
  Callback for stopping the file watcher.
  """
  @callback stop_watching(watcher_pid :: pid()) :: :ok
end
