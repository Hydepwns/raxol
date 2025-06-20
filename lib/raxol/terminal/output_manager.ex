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
  Formats control characters for display.
  Returns the formatted string.
  """
  @spec format_control_chars(String.t()) :: String.t()
  def format_control_chars(string) do
    string
    |> String.to_charlist()
    |> Enum.map(fn char ->
      case char do
        0 -> "^@"
        1 -> "^A"
        2 -> "^B"
        3 -> "^C"
        4 -> "^D"
        5 -> "^E"
        6 -> "^F"
        7 -> "^G"
        8 -> "^H"
        9 -> "^I"
        10 -> "^J"
        11 -> "^K"
        12 -> "^L"
        13 -> "^M"
        14 -> "^N"
        15 -> "^O"
        16 -> "^P"
        17 -> "^Q"
        18 -> "^R"
        19 -> "^S"
        20 -> "^T"
        21 -> "^U"
        22 -> "^V"
        23 -> "^W"
        24 -> "^X"
        25 -> "^Y"
        26 -> "^Z"
        27 -> "^["
        28 -> "^\\"
        29 -> "^]"
        30 -> "^^"
        31 -> "^_"
        127 -> "^?"
        _ when char < 32 -> "\\x#{:io_lib.format("~2.16.0b", [char])}"
        _ -> <<char::utf8>>
      end
    end)
    |> Enum.join("")
  end

  @doc """
  Formats Unicode characters for display.
  Returns the formatted string.
  """
  @spec format_unicode(String.t()) :: String.t()
  def format_unicode(string) do
    string
    |> String.to_charlist()
    |> Enum.map(fn char ->
      if char > 0xFFFF do
        "U+#{:io_lib.format("~4.16.0b", [char])}"
      else
        <<char::utf8>>
      end
    end)
    |> Enum.join("")
  end
end
