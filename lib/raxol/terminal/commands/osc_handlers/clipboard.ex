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

  @spec handle_9(Emulator.t(), String.t()) ::
          {:ok, Emulator.t()} | {:error, term(), Emulator.t()}
  def handle_9(emulator, data) do
    case data do
      "?" ->
        content = Clipboard.get_content(emulator.clipboard)
        response = format_clipboard_response(9, content)
        {:ok, %{emulator | output_buffer: response}}

      content ->
        {:ok, new_clipboard} =
          Clipboard.set_content(emulator.clipboard, content)

        {:ok, %{emulator | clipboard: new_clipboard}}
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
        handle_clipboard_query(emulator, 52)

      {:query, :selection} ->
        handle_selection_query(emulator, 52)

      {:set, :clipboard, content} ->
        handle_clipboard_set(emulator, 52, content)

      {:set, :selection, content} ->
        handle_selection_set(emulator, 52, content)

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

  # Private command handlers
  defp handle_clipboard_query(emulator, command) do
    content = Clipboard.get_content(emulator.clipboard)
    response = format_clipboard_response(command, content)
    {:ok, %{emulator | output_buffer: response}}
  end

  defp handle_selection_query(emulator, command) do
    {:ok, content} = Clipboard.get_selection(emulator.clipboard)
    response = format_selection_response(command, content)
    {:ok, %{emulator | output_buffer: response}}
  end

  defp handle_clipboard_set(emulator, _command, content) do
    {:ok, new_clipboard} = Clipboard.set_content(emulator.clipboard, content)
    {:ok, %{emulator | clipboard: new_clipboard}}
  end

  defp handle_selection_set(emulator, _command, content) do
    {:ok, new_clipboard} = Clipboard.set_selection(emulator.clipboard, content)
    {:ok, %{emulator | clipboard: new_clipboard}}
  end
end
