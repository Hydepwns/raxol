defmodule Raxol.Terminal.OutputManager do
  @moduledoc """
  Manages terminal output operations including writing, flushing, and output buffering.
  This module is responsible for handling all output-related operations in the terminal.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.OutputBuffer
  require Raxol.Core.Runtime.Log

  @doc """
  Gets the output buffer instance.
  Returns the output buffer.
  """
  @spec get_buffer(Emulator.t()) :: OutputBuffer.t()
  def get_buffer(emulator) do
    emulator.output_buffer
  end

  @doc """
  Updates the output buffer instance.
  Returns the updated emulator.
  """
  @spec update_buffer(Emulator.t(), OutputBuffer.t()) :: Emulator.t()
  def update_buffer(emulator, buffer) do
    %{emulator | output_buffer: buffer}
  end

  @doc """
  Writes a string to the output buffer.
  Returns the updated emulator.
  """
  @spec write(Emulator.t(), String.t()) :: Emulator.t()
  def write(emulator, string) do
    buffer = OutputBuffer.write(emulator.output_buffer, string)
    update_buffer(emulator, buffer)
  end

  @doc """
  Writes a string to the output buffer with a newline.
  Returns the updated emulator.
  """
  @spec writeln(Emulator.t(), String.t()) :: Emulator.t()
  def writeln(emulator, string) do
    buffer = OutputBuffer.writeln(emulator.output_buffer, string)
    update_buffer(emulator, buffer)
  end

  @doc """
  Flushes the output buffer.
  Returns {:ok, updated_emulator} or {:error, reason}.
  """
  @spec flush(Emulator.t()) :: {:ok, Emulator.t()} | {:error, String.t()}
  def flush(emulator) do
    case OutputBuffer.flush(emulator.output_buffer) do
      {:ok, new_buffer} ->
        {:ok, update_buffer(emulator, new_buffer)}

      {:error, reason} ->
        {:error, "Failed to flush output buffer: #{inspect(reason)}"}
    end
  end

  @doc """
  Clears the output buffer.
  Returns the updated emulator.
  """
  @spec clear(Emulator.t()) :: Emulator.t()
  def clear(emulator) do
    buffer = OutputBuffer.clear(emulator.output_buffer)
    update_buffer(emulator, buffer)
  end

  @doc """
  Gets the current output buffer content.
  Returns the buffer content as a string.
  """
  @spec get_content(Emulator.t()) :: String.t()
  def get_content(emulator) do
    OutputBuffer.get_content(emulator.output_buffer)
  end

  @doc """
  Sets the output buffer content.
  Returns the updated emulator.
  """
  @spec set_content(Emulator.t(), String.t()) :: Emulator.t()
  def set_content(emulator, content) do
    buffer = OutputBuffer.set_content(emulator.output_buffer, content)
    update_buffer(emulator, buffer)
  end

  @doc """
  Gets the output buffer size.
  Returns the number of bytes in the buffer.
  """
  @spec get_size(Emulator.t()) :: non_neg_integer()
  def get_size(emulator) do
    OutputBuffer.get_size(emulator.output_buffer)
  end

  @doc """
  Checks if the output buffer is empty.
  Returns true if the buffer is empty, false otherwise.
  """
  @spec empty?(Emulator.t()) :: boolean()
  def empty?(emulator) do
    OutputBuffer.empty?(emulator.output_buffer)
  end

  @doc """
  Sets the output buffer mode.
  Returns the updated emulator.
  """
  @spec set_mode(Emulator.t(), atom()) :: Emulator.t()
  def set_mode(emulator, mode) do
    buffer = OutputBuffer.set_mode(emulator.output_buffer, mode)
    update_buffer(emulator, buffer)
  end

  @doc """
  Gets the current output buffer mode.
  Returns the current mode.
  """
  @spec get_mode(Emulator.t()) :: atom()
  def get_mode(emulator) do
    OutputBuffer.get_mode(emulator.output_buffer)
  end

  @doc """
  Sets the output buffer encoding.
  Returns the updated emulator.
  """
  @spec set_encoding(Emulator.t(), String.t()) :: Emulator.t()
  def set_encoding(emulator, encoding) do
    buffer = OutputBuffer.set_encoding(emulator.output_buffer, encoding)
    update_buffer(emulator, buffer)
  end

  @doc """
  Gets the current output buffer encoding.
  Returns the current encoding.
  """
  @spec get_encoding(Emulator.t()) :: String.t()
  def get_encoding(emulator) do
    OutputBuffer.get_encoding(emulator.output_buffer)
  end

  @doc """
  Formats ANSI escape sequences for display.
  Returns the formatted string with ANSI sequences replaced by readable descriptions.
  """
  @spec format_ansi_sequences(String.t()) :: String.t()
  def format_ansi_sequences(string) do
    Enum.reduce(@ansi_patterns, string, &apply_ansi_pattern/2)
  end

  defp apply_ansi_pattern({pattern, replacement}, acc)
       when is_binary(replacement) do
    String.replace(acc, pattern, replacement)
  end

  defp apply_ansi_pattern({pattern, replacement}, acc)
       when is_function(replacement, 1) do
    Regex.replace(pattern, acc, fn _, a -> replacement.(a) end)
  end

  defp apply_ansi_pattern({pattern, replacement}, acc)
       when is_function(replacement, 2) do
    Regex.replace(pattern, acc, fn _, a, b -> replacement.(a, b) end)
  end

  @ansi_patterns [
    # Cursor movement sequences - handle missing parameters
    {~r/\e\[(\d+)A/, "CURSOR_UP(\\1)"},
    {~r/\e\[A/, "CURSOR_UP(1)"},
    {~r/\e\[(\d+)B/, "CURSOR_DOWN(\\1)"},
    {~r/\e\[B/, "CURSOR_DOWN(1)"},
    {~r/\e\[(\d+)C/, "CURSOR_FORWARD(\\1)"},
    {~r/\e\[C/, "CURSOR_FORWARD(1)"},
    {~r/\e\[(\d+)D/, "CURSOR_BACKWARD(\\1)"},
    {~r/\e\[D/, "CURSOR_BACKWARD(1)"},
    # Multi-parameter cursor position
    {~r/\e\[((?:\d+;)+\d+)H/,
     fn params ->
       "CURSOR_POSITION(" <> String.replace(params, ";", ";") <> ")"
     end},
    {~r/\e\[(\d+);(\d+)H/, "CURSOR_POSITION(\\1;\\2)"},
    {~r/\e\[;H/, "CURSOR_POSITION(1;1)"},
    {~r/\e\[H/, "CURSOR_HOME"},
    {~r/\e\[s/, "CURSOR_SAVE"},
    {~r/\e\[u/, "CURSOR_RESTORE"},
    # Text attribute sequences (SGR) - handle reset specifically
    {~r/\e\[0m/, "RESET_ATTRIBUTES"},
    {~r/\e\[m/, "RESET_ATTRIBUTES"},
    {~r/\e\[(\d+(?:;\d+)*)m/, "SGR(\\1)"},
    # Screen manipulation sequences - handle missing parameters
    {~r/\e\[(\d+)J/, "CLEAR_SCREEN(\\1)"},
    {~r/\e\[J/, "CLEAR_SCREEN(0)"},
    {~r/\e\[(\d+)K/, "CLEAR_LINE(\\1)"},
    {~r/\e\[K/, "CLEAR_LINE(0)"},
    {~r/\e\[(\d+)L/, "INSERT_LINE(\\1)"},
    {~r/\e\[L/, "INSERT_LINE(1)"},
    {~r/\e\[(\d+)M/, "DELETE_LINE(\\1)"},
    {~r/\e\[M/, "DELETE_LINE(1)"},
    # Mode setting sequences
    {~r/\e\[\?(\d+)h/, "SET_MODE(\\1)"},
    {~r/\e\[\?(\d+)l/, "RESET_MODE(\\1)"},
    # Device status sequences
    {~r/\e\[(\d+)n/, "DEVICE_STATUS(\\1)"},
    # Character set sequences
    {~r/\e\(([A-Z0-9])/, "DESIGNATE_CHARSET(G0,\\1)"},
    {~r/\e\)([A-Z0-9])/, "DESIGNATE_CHARSET(G1,\\1)"},
    # OSC sequences - use comma for title codes (0,1,2), semicolon for others
    {~r/\e\](\d+);([^\a]*)\a/,
     fn code, rest ->
       case code do
         "0" -> "OSC(" <> code <> "," <> rest <> ")"
         "1" -> "OSC(" <> code <> "," <> rest <> ")"
         "2" -> "OSC(" <> code <> "," <> rest <> ")"
         _ -> "OSC(" <> code <> ";" <> rest <> ")"
       end
     end},
    {~r/\e\](\d+;[^\a]*)\a/, "OSC(\\1)"}
  ]

  @doc """
  Formats control characters for display.
  Returns the formatted string.
  """
  @spec format_control_chars(String.t()) :: String.t()
  def format_control_chars(string) do
    string
    |> String.graphemes()
    |> Enum.map_join("", &format_control_char/1)
  end

  defp format_control_char(char) do
    case Map.get(@control_char_map, char) do
      nil ->
        try do
          if byte_size(char) == 1 do
            <<c::utf8>> = char

            if c < 32 do
              "\\x#{:io_lib.format("~2.16.0b", [c])}"
            else
              char
            end
          else
            char
          end
        rescue
          _ -> char
        end

      formatted ->
        formatted
    end
  end

  @control_char_map %{
    "\x00" => "^@",
    "\x01" => "^A",
    "\x02" => "^B",
    "\x03" => "^C",
    "\x04" => "^D",
    "\x05" => "^E",
    "\x06" => "^F",
    "\x07" => "^G",
    "\x08" => "^H",
    "\x09" => "^I",
    "\x0A" => "^J",
    "\x0B" => "^K",
    "\x0C" => "^L",
    "\x0D" => "^M",
    "\x0E" => "^N",
    "\x0F" => "^O",
    "\x10" => "^P",
    "\x11" => "^Q",
    "\x12" => "^R",
    "\x13" => "^S",
    "\x14" => "^T",
    "\x15" => "^U",
    "\x16" => "^V",
    "\x17" => "^W",
    "\x18" => "^X",
    "\x19" => "^Y",
    "\x1A" => "^Z",
    "\x1B" => "^[",
    "\x1C" => "^\\",
    "\x1D" => "^]",
    "\x1E" => "^^",
    "\x1F" => "^_",
    "\x7F" => "^?"
  }

  @doc """
  Formats Unicode characters for display.
  Returns the formatted string.
  """
  @spec format_unicode(String.t()) :: String.t()
  def format_unicode(string) do
    string
    |> String.graphemes()
    |> Enum.map_join("", fn char ->
      case String.to_charlist(char) do
        [codepoint] when codepoint > 0xFFFF ->
          "U+" <> String.upcase(Integer.to_string(codepoint, 16))

        _ ->
          char
      end
    end)
  end
end
