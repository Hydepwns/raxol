defmodule Raxol.Terminal.Commands.OSCHandlers.Clipboard do
  @moduledoc """
  Handles clipboard-related OSC commands.

  This handler manages clipboard operations, including:
  - Setting and querying clipboard content
  - Managing selection content
  - Handling different clipboard types (primary, clipboard)

  ## Supported Commands

  - OSC 9: Set/Query clipboard content
  - OSC 52: Set/Query clipboard or selection content
  """

  alias Raxol.Terminal.{Emulator, Clipboard}
  require Raxol.Core.Runtime.Log

  @doc """
  Handles OSC 9 command to set/query clipboard content.
  """
  @spec handle_9(Emulator.t(), String.t()) ::
          {:ok, Emulator.t()} | {:error, term(), Emulator.t()}
  def handle_9(emulator, data) do
    case data do
      "?" ->
        case Clipboard.get_content(emulator.clipboard) do
          {:ok, content} ->
            response = format_clipboard_response(9, content)
            {:ok, %{emulator | output_buffer: response}}

          {:error, reason} ->
            Raxol.Core.Runtime.Log.warning(
              "Failed to get clipboard content: #{inspect(reason)}"
            )

            {:error, reason, emulator}
        end

      content ->
        case Clipboard.set_content(emulator.clipboard, content) do
          {:ok, new_clipboard} ->
            {:ok, %{emulator | clipboard: new_clipboard}}

          {:error, reason} ->
            Raxol.Core.Runtime.Log.warning(
              "Failed to set clipboard content: #{inspect(reason)}"
            )

            {:error, reason, emulator}
        end
    end
  end

  @doc """
  Handles OSC 52 command to set/query clipboard or selection content.

  ## Command Format

  - `52;c;?` - Query clipboard content
  - `52;c;content` - Set clipboard content
  - `52;s;?` - Query selection content
  - `52;s;content` - Set selection content

  Where:
  - c: clipboard
  - s: selection
  """
  @spec handle_52(Emulator.t(), String.t()) ::
          {:ok, Emulator.t()} | {:error, term(), Emulator.t()}
  def handle_52(emulator, data) do
    case parse_command(data) do
      {:query, :clipboard} ->
        case Clipboard.get_content(emulator.clipboard) do
          {:ok, content} ->
            response = format_clipboard_response(52, content)
            {:ok, %{emulator | output_buffer: response}}

          {:error, reason} ->
            Raxol.Core.Runtime.Log.warning(
              "Failed to get clipboard content: #{inspect(reason)}"
            )

            {:error, reason, emulator}
        end

      {:query, :selection} ->
        case Clipboard.get_selection(emulator.clipboard) do
          {:ok, content} ->
            response = format_selection_response(52, content)
            {:ok, %{emulator | output_buffer: response}}

          {:error, reason} ->
            Raxol.Core.Runtime.Log.warning(
              "Failed to get selection content: #{inspect(reason)}"
            )

            {:error, reason, emulator}
        end

      {:set, :clipboard, content} ->
        case Clipboard.set_content(emulator.clipboard, content) do
          {:ok, new_clipboard} ->
            {:ok, %{emulator | clipboard: new_clipboard}}

          {:error, reason} ->
            Raxol.Core.Runtime.Log.warning(
              "Failed to set clipboard content: #{inspect(reason)}"
            )

            {:error, reason, emulator}
        end

      {:set, :selection, content} ->
        case Clipboard.set_selection(emulator.clipboard, content) do
          {:ok, new_clipboard} ->
            {:ok, %{emulator | clipboard: new_clipboard}}

          {:error, reason} ->
            Raxol.Core.Runtime.Log.warning(
              "Failed to set selection content: #{inspect(reason)}"
            )

            {:error, reason, emulator}
        end

      {:error, reason} ->
        Raxol.Core.Runtime.Log.warning(
          "Invalid OSC 52 command: #{inspect(data)}"
        )

        {:error, reason, emulator}
    end
  end

  # Private Helpers

  defp parse_command(data) do
    case String.split(data, ";") do
      ["c", "?"] ->
        {:query, :clipboard}

      ["s", "?"] ->
        {:query, :selection}

      ["c" | rest] ->
        {:set, :clipboard, Enum.join(rest, ";")}

      ["s" | rest] ->
        {:set, :selection, Enum.join(rest, ";")}

      _ ->
        {:error, :invalid_format}
    end
  end

  defp format_clipboard_response(command, content) do
    # Format: OSC command;content
    "\e]#{command};#{content}\e\\"
  end

  defp format_selection_response(command, content) do
    # Format: OSC command;s;content
    "\e]#{command};s;#{content}\e\\"
  end
end
