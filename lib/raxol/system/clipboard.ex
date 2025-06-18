defmodule Raxol.System.Clipboard do
  @moduledoc '''
  Provides consolidated access to the system clipboard across different operating systems.

  Handles interactions with platform-specific clipboard utilities like `pbcopy`/`pbpaste` (macOS),
  `xclip` (Linux/X11), and `clip`/`powershell Get-Clipboard` (Windows).

  Requires `xclip` to be installed on Linux systems using X11.
  Wayland clipboard access might require different utilities not currently handled.
  '''

  @behaviour Raxol.Core.Clipboard.Behaviour

  require Raxol.Core.Runtime.Log

  @doc '''
  Copies the given text to the system clipboard.
  '''
  @impl Raxol.Core.Clipboard.Behaviour
  @spec copy(String.t()) :: :ok | {:error, atom() | String.t()}
  def copy(text) when is_binary(text) do
    case :os.type() do
      {:unix, :darwin} ->
        # macOS uses pbcopy
        case System.cmd("pbcopy", [], input: text, stderr_to_stdout: true) do
          {_output, 0} ->
            :ok

          {output, exit_code} ->
            Raxol.Core.Runtime.Log.error(
              "Failed to copy using pbcopy. Exit code: #{exit_code}, Output: #{output}"
            )

            {:error, {:pbcopy_failed, output}}
        end

      {:unix, _} ->
        # Linux/Unix - Try xclip for X11 clipboard
        case System.find_executable("xclip") do
          nil ->
            Raxol.Core.Runtime.Log.error(
              "Clipboard error: `xclip` command not found. Please install it for clipboard support."
            )

            {:error, :command_not_found}

          _ ->
            case System.cmd("xclip", ["-selection", "clipboard"],
                   input: text,
                   stderr_to_stdout: true
                 ) do
              {_output, 0} ->
                :ok

              {output, exit_code} ->
                Raxol.Core.Runtime.Log.error(
                  "Failed to copy using xclip. Exit code: #{exit_code}, Output: #{output}"
                )

                {:error, {:xclip_failed, output}}
            end
        end

      {:win32, _} ->
        # Windows uses clip
        case System.cmd("clip", [], input: text, stderr_to_stdout: true) do
          {_output, 0} ->
            :ok

          {output, exit_code} ->
            Raxol.Core.Runtime.Log.error(
              "Failed to copy using clip. Exit code: #{exit_code}, Output: #{output}"
            )

            {:error, {:clip_failed, output}}
        end

      _other_os ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "Clipboard copy not supported on this OS.",
          %{}
        )

        {:error, :unsupported_os}
    end
  end

  @doc '''
  Retrieves text from the system clipboard.

  Returns `{:ok, text}` on success, or `{:error, reason}` on failure.
  An empty clipboard is considered success and returns `{:ok, ""}`.
  '''
  @impl Raxol.Core.Clipboard.Behaviour
  @spec paste() :: {:ok, String.t()} | {:error, atom() | String.t()}
  def paste do
    case :os.type() do
      {:unix, :darwin} ->
        # macOS uses pbpaste
        case System.cmd("pbpaste", [], stderr_to_stdout: true) do
          {output, 0} ->
            # pbpaste might add newline
            {:ok, String.trim(output)}

          {output, exit_code} ->
            Raxol.Core.Runtime.Log.error(
              "Failed to paste using pbpaste. Exit code: #{exit_code}, Output: #{output}"
            )

            {:error, {:pbpaste_failed, output}}
        end

      {:unix, _} ->
        # Linux/Unix - Try xclip for X11 clipboard
        case System.find_executable("xclip") do
          nil ->
            Raxol.Core.Runtime.Log.error(
              "Clipboard error: `xclip` command not found. Please install it for clipboard support."
            )

            {:error, :command_not_found}

          _ ->
            case System.cmd("xclip", ["-selection", "clipboard", "-o"],
                   stderr_to_stdout: true
                 ) do
              {output, 0} ->
                # xclip -o usually includes a newline, handled by caller if needed
                {:ok, output}

              {output, exit_code} ->
                # Exit code 1 can mean empty clipboard, which isn't an error for paste
                if exit_code == 1 and String.trim(output) == "" do
                  {:ok, ""}
                else
                  Raxol.Core.Runtime.Log.error(
                    "Failed to paste using xclip. Exit code: #{exit_code}, Output: #{output}"
                  )

                  {:error, {:xclip_failed, output}}
                end
            end
        end

      {:win32, _} ->
        # Windows uses PowerShell Get-Clipboard for better potential Unicode handling
        case System.cmd(
               "powershell",
               ["-noprofile", "-command", "Get-Clipboard"],
               stderr_to_stdout: true
             ) do
          {output, 0} ->
            # Trim potential Windows CRLF
            {:ok, String.trim_trailing(output, "
")}

          {output, exit_code} ->
            # Check if clipboard is empty (often throws an error)
            if String.contains?(output, [
                 "Cannot retrieve the Clipboard.",
                 "Get-Clipboard: Failed to get clipboard content"
               ]) do
              Raxol.Core.Runtime.Log.debug(
                "Clipboard appears empty or inaccessible via PowerShell."
              )

              # Treat as empty clipboard
              {:ok, ""}
            else
              Raxol.Core.Runtime.Log.error(
                "Failed to paste using PowerShell. Exit code: #{exit_code}, Output: #{output}"
              )

              {:error, {:powershell_get_clipboard_failed, output}}
            end
        end

      _other_os ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "Clipboard paste not supported on this OS.",
          %{}
        )

        {:error, :unsupported_os}
    end
  end
end
