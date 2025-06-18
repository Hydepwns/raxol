defmodule Raxol.Clipboard do
  @moduledoc '''
  Handles clipboard operations across different platforms.
  Provides a unified interface for copy/paste functionality.
  '''

  @doc '''
  Sets text to the system clipboard.
  Returns :ok on success, {:error, reason} on failure.
  '''
  @spec set_text(String.t()) :: :ok | {:error, term()}
  def set_text(text) do
    case :os.type() do
      {:unix, :darwin} ->
        # macOS
        port = Port.open({:spawn, "pbcopy"}, [:binary, :exit_status])
        Port.command(port, text)

        receive do
          {^port, {:exit_status, 0}} -> :ok
          {^port, {:exit_status, status}} -> {:error, {:exit_status, status}}
        end

      {:unix, :linux} ->
        # Linux
        port =
          Port.open({:spawn, "xclip -selection clipboard"}, [
            :binary,
            :exit_status
          ])

        Port.command(port, text)

        receive do
          {^port, {:exit_status, 0}} -> :ok
          {^port, {:exit_status, status}} -> {:error, {:exit_status, status}}
        end

      {:win32, :nt} ->
        # Windows
        port = Port.open({:spawn, "clip"}, [:binary, :exit_status])
        Port.command(port, text)

        receive do
          {^port, {:exit_status, 0}} -> :ok
          {^port, {:exit_status, status}} -> {:error, {:exit_status, status}}
        end

      _ ->
        {:error, :unsupported_platform}
    end
  end

  @doc '''
  Gets text from the system clipboard.
  Returns {:ok, text} on success, {:error, reason} on failure.
  '''
  @spec get_text() :: {:ok, String.t()} | {:error, term()}
  def get_text do
    case :os.type() do
      {:unix, :darwin} ->
        # macOS
        port = Port.open({:spawn, "pbpaste"}, [:binary, :exit_status])

        receive do
          {^port, {:exit_status, 0}, text} -> {:ok, text}
          {^port, {:exit_status, status}} -> {:error, {:exit_status, status}}
        end

      {:unix, :linux} ->
        # Linux
        port =
          Port.open({:spawn, "xclip -selection clipboard -o"}, [
            :binary,
            :exit_status
          ])

        receive do
          {^port, {:exit_status, 0}, text} -> {:ok, text}
          {^port, {:exit_status, status}} -> {:error, {:exit_status, status}}
        end

      {:win32, :nt} ->
        # Windows
        port =
          Port.open({:spawn, "powershell -command Get-Clipboard"}, [
            :binary,
            :exit_status
          ])

        receive do
          {^port, {:exit_status, 0}, text} -> {:ok, text}
          {^port, {:exit_status, status}} -> {:error, {:exit_status, status}}
        end

      _ ->
        {:error, :unsupported_platform}
    end
  end
end
