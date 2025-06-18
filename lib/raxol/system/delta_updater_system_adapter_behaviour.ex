defmodule Raxol.System.DeltaUpdaterSystemAdapterBehaviour do
  @moduledoc '''
  Behaviour for a system adapter used by DeltaUpdater.

  This module defines the contract for functions that interact with the system,
  allowing for different implementations (e.g., a real one and a mock for tests).
  '''

  @doc '''
  Performs an HTTP request.
  Mirrors `:httpc.request/4` or similar functionality.
  `method` is an atom e.g. `:get`, `:post`.
  `url_with_headers` is typically `{charlist_url, list_of_headers}`.
  `http_options` and `stream_options` are keyword lists or lists of tuples.
  '''
  @callback httpc_request(
              method :: atom(),
              url_with_headers :: {charlist(), list()},
              http_options :: Keyword.t() | list(),
              stream_options :: Keyword.t() | list()
            ) ::
              {:ok,
               {{http_version :: tuple(), status_code :: integer(),
                 reason_phrase :: charlist()}, headers :: list(),
                body :: charlist() | binary()}}
              | {:ok, :saved_to_file}
              | {:error, reason :: any()}

  @doc '''
  Gets the operating system type.
  Mirrors `:os.type/0`.
  '''
  @callback os_type() :: {:win32, atom()} | {:unix, atom()}

  @doc '''
  Gets the path to the system's temporary directory.
  Mirrors `System.tmp_dir!/0` or `System.tmp_dir/0`.
  '''
  @callback system_tmp_dir() :: {:ok, String.t()} | {:error, reason :: any()}

  @doc '''
  Gets the value of an environment variable.
  Mirrors `System.get_env/1`.
  '''
  @callback system_get_env(varname :: String.t()) :: String.t() | nil

  @doc '''
  Gets the command-line arguments passed to the program.
  Mirrors `System.argv/0`.
  '''
  @callback system_argv() :: list(String.t())

  @doc '''
  Executes a system command.
  Mirrors `System.cmd/3`.
  Options can include e.g. `:stderr_to_stdout`.
  '''
  @callback system_cmd(
              command :: String.t(),
              args :: list(String.t()),
              options :: Keyword.t()
            ) :: {output :: String.t(), exit_status :: integer()}

  @doc '''
  Creates a directory, including any necessary parent directories.
  Mirrors `File.mkdir_p!/1` or `File.mkdir_p/1`.
  '''
  @callback file_mkdir_p(path :: String.t()) :: :ok | {:error, reason :: atom()}

  @doc '''
  Removes a file or directory recursively.
  Mirrors `File.rm_rf!/1` or `File.rm_rf/1`.
  '''
  @callback file_rm_rf(path :: String.t()) :: :ok | {:error, reason :: atom()}

  @doc '''
  Changes the mode of a file.
  Mirrors `File.chmod!/2` or `File.chmod/2`.
  '''
  @callback file_chmod(path :: String.t(), mode :: integer()) ::
              :ok | {:error, reason :: atom()}

  @doc '''
  Replaces the current executable with a new one.
  This abstracts the call to `Raxol.System.Updater.do_replace_executable/3`.
  '''
  @callback updater_do_replace_executable(
              current_exe :: String.t(),
              new_exe :: String.t(),
              platform :: String.t()
            ) :: :ok | {:error, reason :: any()}

  @doc 'Gets the current version string.'
  @callback current_version() :: String.t()

  @doc 'Performs a simple HTTP GET request and returns the body as a string.'
  @callback http_get(url :: String.t()) :: {:ok, String.t()} | {:error, any()}
end
