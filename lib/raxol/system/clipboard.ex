defmodule Raxol.System.Clipboard do
  @moduledoc """
  Provides consolidated access to the system clipboard across different operating systems.

  Handles interactions with platform-specific clipboard utilities like `pbcopy`/`pbpaste` (macOS),
  `xclip` (Linux/X11), and `clip`/`powershell Get-Clipboard` (Windows).

  Requires `xclip` to be installed on Linux systems using X11.
  Wayland clipboard access might require different utilities not currently handled.
  """

  @behaviour Raxol.Core.Clipboard.Behaviour

  import Raxol.Guards
  require Raxol.Core.Runtime.Log

  @doc """
  Copies the given text to the system clipboard.
  """
  @impl Raxol.Core.Clipboard.Behaviour
  @spec copy(String.t()) :: :ok | {:error, atom() | String.t()}
  def copy(text) when binary?(text) do
    case :os.type() do
      {:unix, :darwin} -> copy_macos(text)
      {:unix, _} -> copy_linux(text)
      {:win32, _} -> copy_windows(text)
      _other_os -> copy_unsupported_os()
    end
  end

  defp copy_macos(text) do
    case System.cmd("pbcopy", [], input: text, stderr_to_stdout: true) do
      {_output, 0} ->
        :ok

      {output, exit_code} ->
        Raxol.Core.Runtime.Log.error(
          "Failed to copy using pbcopy. Exit code: #{exit_code}, Output: #{output}"
        )

        {:error, {:pbcopy_failed, output}}
    end
  end

  defp copy_linux(text) do
    case System.find_executable("xclip") do
      nil ->
        Raxol.Core.Runtime.Log.error(
          "Clipboard error: `xclip` command not found. Please install it for clipboard support."
        )

        {:error, :command_not_found}

      _ ->
        copy_with_xclip(text)
    end
  end

  defp copy_with_xclip(text) do
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

  defp copy_windows(text) do
    case System.cmd("clip", [], input: text, stderr_to_stdout: true) do
      {_output, 0} ->
        :ok

      {output, exit_code} ->
        Raxol.Core.Runtime.Log.error(
          "Failed to copy using clip. Exit code: #{exit_code}, Output: #{output}"
        )

        {:error, {:clip_failed, output}}
    end
  end

  defp copy_unsupported_os do
    Raxol.Core.Runtime.Log.warning_with_context(
      "Clipboard copy not supported on this OS.",
      %{}
    )

    {:error, :unsupported_os}
  end

  @doc """
  Retrieves text from the system clipboard.

  Returns `{:ok, text}` on success, or `{:error, reason}` on failure.
  An empty clipboard is considered success and returns `{:ok, ""}`.
  """
  @impl Raxol.Core.Clipboard.Behaviour
  @spec paste() :: {:ok, String.t()} | {:error, atom() | String.t()}
  def paste do
    case :os.type() do
      {:unix, :darwin} -> paste_macos()
      {:unix, _} -> paste_linux()
      {:win32, _} -> paste_windows()
      _other_os -> paste_unsupported_os()
    end
  end

  defp paste_macos do
    case System.cmd("pbpaste", [], stderr_to_stdout: true) do
      {output, 0} ->
        {:ok, String.trim(output)}

      {output, exit_code} ->
        Raxol.Core.Runtime.Log.error(
          "Failed to paste using pbpaste. Exit code: #{exit_code}, Output: #{output}"
        )

        {:error, {:pbpaste_failed, output}}
    end
  end

  defp paste_linux do
    case System.find_executable("xclip") do
      nil ->
        Raxol.Core.Runtime.Log.error(
          "Clipboard error: `xclip` command not found. Please install it for clipboard support."
        )

        {:error, :command_not_found}

      _ ->
        paste_with_xclip()
    end
  end

  defp paste_with_xclip do
    case System.cmd("xclip", ["-selection", "clipboard", "-o"],
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        {:ok, output}

      {output, exit_code} ->
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

  defp paste_windows do
    case System.cmd("powershell", ["-noprofile", "-command", "Get-Clipboard"],
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        {:ok, String.trim_trailing(output, "\r\n")}

      {output, exit_code} ->
        if String.contains?(output, [
             "Cannot retrieve the Clipboard.",
             "Get-Clipboard: Failed to get clipboard content"
           ]) do
          Raxol.Core.Runtime.Log.debug(
            "Clipboard appears empty or inaccessible via PowerShell."
          )

          {:ok, ""}
        else
          Raxol.Core.Runtime.Log.error(
            "Failed to paste using PowerShell. Exit code: #{exit_code}, Output: #{output}"
          )

          {:error, {:powershell_get_clipboard_failed, output}}
        end
    end
  end

  defp paste_unsupported_os do
    Raxol.Core.Runtime.Log.warning_with_context(
      "Clipboard paste not supported on this OS.",
      %{}
    )

    {:error, :unsupported_os}
  end
end
