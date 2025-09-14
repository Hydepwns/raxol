defmodule File.Behaviour do
  @moduledoc """
  Defines the behaviour for file system operations.
  This is used for mocking in tests.
  """

  @doc """
  Gets file statistics.
  """
  @callback stat(path :: String.t()) ::
              {:ok, File.Stat.t()} | {:error, File.posix()}

  @doc """
  Checks if a file exists.
  """
  @callback exists?(path :: String.t()) :: boolean()

  @doc """
  Reads file contents.
  """
  @callback read(path :: String.t()) :: {:ok, binary()} | {:error, File.posix()}

  @doc """
  Writes content to a file.
  """
  @callback write(path :: String.t(), content :: binary()) ::
              :ok | {:error, File.posix()}

  @doc """
  Removes a file.
  """
  @callback rm(path :: String.t()) :: :ok | {:error, File.posix()}

  @doc """
  Creates a directory and its parent directories.
  """
  @callback mkdir_p(path :: String.t()) :: :ok | {:error, File.posix()}
end
