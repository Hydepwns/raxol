defmodule Raxol.Core.Events.Clipboard do
  @moduledoc """
  Handles clipboard operations for the Raxol application.

  Note: On Linux, this module requires the `xclip` utility to be installed
  for accessing the X11 clipboard. Wayland is not currently supported directly.
  """
  require Logger

  @doc """
  Copies text to the system clipboard.
  """
  @spec copy(String.t()) :: {:ok, String.t()} | {:error, atom() | String.t()}
  def copy(text) when is_binary(text) do
    case :os.type() do
      {:unix, :darwin} ->
        # macOS uses pbcopy
        {_output, exit_status} = System.cmd("pbcopy", [], input: text)

        if exit_status == 0 do
          {:ok, text}
        else
          {:error, :clipboard_command_failed}
        end

      {:unix, _} ->
        # Linux/Unix - Try xclip for X11 clipboard
        case System.find_executable("xclip") do
          nil ->
            Logger.error(
              "Clipboard error: `xclip` command not found. Please install it."
            )

            {:error, :command_not_found}

          _ ->
            case System.cmd("xclip", ["-selection", "clipboard"],
                   input: text,
                   stderr_to_stdout: true
                 ) do
              {_output, 0} ->
                {:ok, text}

              {output, exit_code} ->
                Logger.error(
                  "Failed to copy to clipboard using xclip. Exit code: #{exit_code}, Output: #{output}"
                )

                {:error, {:xclip_failed, output}}
            end
        end

      {:win32, _} ->
        # Windows uses clip
        case System.cmd("clip", [], input: text, stderr_to_stdout: true) do
          {_output, 0} ->
            {:ok, text}

          {output, exit_code} ->
            Logger.error(
              "Failed to copy to clipboard using clip. Exit code: #{exit_code}, Output: #{output}"
            )

            {:error, {:clip_failed, output}}
        end

      {os_type, os_name} ->
        Logger.warning(
          "Clipboard copy not supported on OS: #{os_type}/#{os_name}"
        )

        {:error, :unsupported_os}
    end
  end

  @doc """
  Retrieves text from the system clipboard.
  """
  @spec paste() :: {:ok, String.t()} | {:error, atom() | String.t()}
  def paste do
    case :os.type() do
      {:unix, :darwin} ->
        # macOS uses pbpaste
        case System.cmd("pbpaste", [], stderr_to_stdout: true) do
          {output, 0} ->
            {:ok, String.trim(output)}

          {output, exit_code} ->
            Logger.error(
              "Failed to paste from clipboard using pbpaste. Exit code: #{exit_code}, Output: #{output}"
            )

            {:error, {:pbpaste_failed, output}}
        end

      {:unix, _} ->
        # Linux/Unix - Try xclip for X11 clipboard
        case System.find_executable("xclip") do
          nil ->
            Logger.error(
              "Clipboard error: `xclip` command not found. Please install it."
            )

            {:error, :command_not_found}

          _ ->
            case System.cmd("xclip", ["-selection", "clipboard", "-o"],
                   stderr_to_stdout: true
                 ) do
              # xclip -o often includes a newline
              {output, 0} ->
                {:ok, output}

              {output, exit_code} ->
                # Exit code 1 can mean empty clipboard, which isn't an error for paste
                if exit_code == 1 and String.trim(output) == "" do
                  {:ok, ""}
                else
                  Logger.error(
                    "Failed to paste from clipboard using xclip. Exit code: #{exit_code}, Output: #{output}"
                  )

                  {:error, {:xclip_failed, output}}
                end
            end
        end

      {:win32, _} ->
        # Windows uses PowerShell Get-Clipboard
        # Note: This might be slow if PowerShell startup is slow.
        case System.cmd("powershell", ["-command", "Get-Clipboard"],
               stderr_to_stdout: true
             ) do
          # Windows newlines
          {output, 0} ->
            {:ok, String.trim_trailing(output, "\r\n")}

          {output, exit_code} ->
            Logger.error(
              "Failed to paste from clipboard using PowerShell. Exit code: #{exit_code}, Output: #{output}"
            )

            {:error, {:powershell_get_clipboard_failed, output}}
        end

      {os_type, os_name} ->
        Logger.warning(
          "Clipboard paste not supported on OS: #{os_type}/#{os_name}"
        )

        {:error, :unsupported_os}
    end
  end
end
