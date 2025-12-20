defmodule Raxol.Terminal.Input.ClipboardHandler do
  @moduledoc """
  Handles clipboard operations for the terminal emulator.

  Supports both local system clipboard operations and OSC 52 escape sequences
  for remote clipboard access over SSH and other terminal connections.

  ## OSC 52 Support

  OSC 52 allows applications to read from and write to the system clipboard
  even when running over SSH or in remote terminal sessions. This module
  can generate OSC 52 sequences to communicate clipboard operations to
  compatible terminal emulators.

  ## Features

  - Local system clipboard integration (pbcopy/pbpaste, xclip, etc.)
  - OSC 52 escape sequences for remote clipboard access
  - Base64 encoding/decoding for OSC 52 payloads
  - Bracketed paste mode support
  - Security controls and size limits
  """

  alias Raxol.Core.Runtime.Log
  alias Raxol.System.Clipboard
  alias Raxol.Terminal.Input.CoreHandler
  # OSC 52 constants
  @osc_52_prefix "\e]52;"
  @osc_52_suffix "\e\\"
  # Some terminals have limits
  @max_osc_52_length 100_000
  @clipboard_targets %{
    clipboard: "c",
    primary: "p",
    secondary: "s",
    select: "0",
    cut_buffer0: "1",
    cut_buffer1: "2",
    cut_buffer2: "3",
    cut_buffer3: "4"
  }

  @doc """
  Handles clipboard paste operation.
  """
  def handle_paste(%CoreHandler{} = handler) do
    case Clipboard.paste() do
      {:ok, text} ->
        new_buffer =
          CoreHandler.insert_text(handler.buffer, handler.cursor_position, text)

        new_position = handler.cursor_position + String.length(text)
        {:ok, %{handler | buffer: new_buffer, cursor_position: new_position}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Handles clipboard copy operation.
  (Currently copies the entire buffer)
  """
  def handle_copy(%CoreHandler{} = handler) do
    case Clipboard.copy(handler.buffer) do
      :ok ->
        {:ok, handler}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Handles clipboard cut operation.
  (Currently cuts the entire buffer)
  """
  def handle_cut(%CoreHandler{} = handler) do
    case Clipboard.copy(handler.buffer) do
      :ok ->
        {:ok,
         %{
           handler
           | buffer: "",
             cursor_position: 0
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Generates an OSC 52 escape sequence to copy text to the system clipboard.

  This is useful for remote terminal sessions where direct clipboard access
  is not available (such as over SSH).

  ## Parameters

  - `text` - Text to copy to clipboard
  - `options` - Options map with optional keys:
    - `:target` - Clipboard target (default: :clipboard)
    - `:max_length` - Maximum length to copy (default: @max_osc_52_length)

  ## Returns

  - `{:ok, osc_sequence}` - OSC 52 escape sequence to send to terminal
  - `{:error, reason}` - Error if text is too long or other issues

  ## Examples

      iex> ClipboardHandler.generate_osc52_copy("Hello, World!")
      {:ok, "\e]52;c;SGVsbG8sIFdvcmxkIQ==\e\\"}

      iex> ClipboardHandler.generate_osc52_copy("test", target: :primary)
      {:ok, "\e]52;p;dGVzdA==\e\\"}
  """
  def generate_osc52_copy(text, options \\ %{}) when is_binary(text) do
    target = Map.get(options, :target, :clipboard)
    max_length = Map.get(options, :max_length, @max_osc_52_length)

    cond do
      byte_size(text) > max_length ->
        {:error, {:text_too_long, byte_size(text), max_length}}

      not Map.has_key?(@clipboard_targets, target) ->
        {:error, {:invalid_target, target}}

      true ->
        target_code = @clipboard_targets[target]
        encoded_text = Base.encode64(text)

        sequence =
          @osc_52_prefix <> target_code <> ";" <> encoded_text <> @osc_52_suffix

        {:ok, sequence}
    end
  end

  @doc """
  Generates an OSC 52 escape sequence to query the system clipboard.

  ## Parameters

  - `target` - Clipboard target to query (default: :clipboard)

  ## Returns

  - `{:ok, osc_sequence}` - OSC 52 query sequence to send to terminal
  - `{:error, reason}` - Error for invalid target

  ## Examples

      iex> ClipboardHandler.generate_osc52_query()
      {:ok, "\e]52;c;?\e\\"}

      iex> ClipboardHandler.generate_osc52_query(:primary)
      {:ok, "\e]52;p;?\e\\"}
  """
  def generate_osc52_query(target \\ :clipboard) do
    case Map.get(@clipboard_targets, target) do
      nil ->
        {:error, {:invalid_target, target}}

      target_code ->
        sequence = @osc_52_prefix <> target_code <> ";?" <> @osc_52_suffix
        {:ok, sequence}
    end
  end

  @doc """
  Parses an OSC 52 response from the terminal.

  When a terminal responds to an OSC 52 query, it sends back the clipboard
  contents as a base64-encoded string. This function decodes the response.

  ## Parameters

  - `osc_response` - Raw OSC 52 response from terminal

  ## Returns

  - `{:ok, {target, text}}` - Decoded clipboard target and text
  - `{:error, reason}` - Error if response is malformed

  ## Examples

      iex> ClipboardHandler.parse_osc52_response("\e]52;c;SGVsbG8=\e\\")
      {:ok, {:clipboard, "Hello"}}
  """
  def parse_osc52_response(response) when is_binary(response) do
    with true <- String.starts_with?(response, @osc_52_prefix),
         true <- String.ends_with?(response, @osc_52_suffix),
         content <-
           String.slice(
             response,
             String.length(@osc_52_prefix)..(-String.length(@osc_52_suffix) - 1)
           ),
         [target_code, encoded_data] <- String.split(content, ";", parts: 2),
         {:ok, target} <- find_target_by_code(target_code),
         {:ok, decoded_text} <- Base.decode64(encoded_data) do
      {:ok, {target, decoded_text}}
    else
      false -> {:error, :invalid_osc52_format}
      :error -> {:error, :base64_decode_error}
      {:error, reason} -> {:error, reason}
      _ -> {:error, :malformed_response}
    end
  end

  @doc """
  Enables bracketed paste mode by generating the appropriate escape sequence.

  Bracketed paste mode allows terminals to distinguish between typed text
  and pasted text, preventing issues with automatic indentation and other
  editor features.

  ## Returns

  - `binary()` - Escape sequence to enable bracketed paste mode
  """
  def enable_bracketed_paste do
    "\e[?2004h"
  end

  @doc """
  Disables bracketed paste mode.

  ## Returns

  - `binary()` - Escape sequence to disable bracketed paste mode
  """
  def disable_bracketed_paste do
    "\e[?2004l"
  end

  @doc """
  Detects if a terminal supports OSC 52 based on environment variables.

  ## Returns

  - `:supported` - Terminal likely supports OSC 52
  - `:unsupported` - Terminal likely does not support OSC 52
  - `:unknown` - Cannot determine terminal capabilities
  """
  def detect_osc52_support do
    term = System.get_env("TERM", "")
    term_program = System.get_env("TERM_PROGRAM", "")
    ssh_connection = System.get_env("SSH_CONNECTION")

    cond do
      # Known terminals with good OSC 52 support
      term_program in ["iTerm.app", "Terminal.app", "WezTerm"] -> :supported
      String.contains?(term, ["xterm", "screen", "tmux"]) -> :supported
      term in ["alacritty", "kitty"] -> :supported
      # If we're in an SSH session, OSC 52 is often the only way
      ssh_connection != nil -> :supported
      # Basic terminals that might not support it
      term in ["dumb", "vt100", "vt52"] -> :unsupported
      # Unknown
      true -> :unknown
    end
  end

  @doc """
  Handles clipboard operations with automatic fallback between local and OSC 52.

  Attempts local clipboard access first, falls back to OSC 52 if running
  in a remote session or if local access fails.

  ## Parameters

  - `operation` - `:copy` or `:paste`
  - `text` - Text to copy (required for :copy, ignored for :paste)
  - `options` - Options including `:force_osc52` to skip local clipboard

  ## Returns

  - For copy: `{:ok, output}` where output is either `:ok` or an OSC 52 sequence
  - For paste: `{:ok, text}` or `{:error, :paste_not_supported_osc52}`
  """
  def handle_clipboard_with_fallback(operation, text \\ nil, options \\ %{})

  def handle_clipboard_with_fallback(:copy, text, options)
      when is_binary(text) do
    force_osc52 = Map.get(options, :force_osc52, false)

    if force_osc52 or should_use_osc52?() do
      case generate_osc52_copy(text, options) do
        {:ok, sequence} ->
          Log.info("Generated OSC 52 clipboard copy sequence")
          {:ok, {:osc52, sequence}}

        error ->
          error
      end
    else
      case Clipboard.copy(text) do
        :ok ->
          {:ok, :local}

        {:error, _reason} ->
          # Fallback to OSC 52
          case generate_osc52_copy(text, options) do
            {:ok, sequence} ->
              Log.info("Falling back to OSC 52 after local clipboard failure")

              {:ok, {:osc52, sequence}}

            error ->
              error
          end
      end
    end
  end

  def handle_clipboard_with_fallback(:paste, _text, options) do
    force_osc52 = Map.get(options, :force_osc52, false)

    if force_osc52 or should_use_osc52?() do
      # For OSC 52 paste, we need to send a query and wait for response
      # This is more complex and usually handled at a higher level
      case generate_osc52_query(Map.get(options, :target, :clipboard)) do
        {:ok, sequence} ->
          Log.info("Generated OSC 52 clipboard query sequence")
          {:ok, {:osc52_query, sequence}}

        error ->
          error
      end
    else
      Clipboard.paste()
    end
  end

  def handle_clipboard_with_fallback(operation, _text, _options) do
    {:error, {:invalid_operation, operation}}
  end

  # Private functions

  defp find_target_by_code(code) do
    case Enum.find(@clipboard_targets, fn {_target, target_code} ->
           target_code == code
         end) do
      {target, _code} -> {:ok, target}
      nil -> {:error, {:unknown_target_code, code}}
    end
  end

  defp should_use_osc52? do
    # Use OSC 52 if we're in a remote session or if the terminal supports it
    # but local clipboard access might be limited
    ssh_connection = System.get_env("SSH_CONNECTION")
    term_program = System.get_env("TERM_PROGRAM", "")

    # macOS local terminals
    ssh_connection != nil or
      (detect_osc52_support() == :supported and
         term_program not in ["Terminal.app", "iTerm.app"])
  end
end
