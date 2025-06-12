defmodule Raxol.Terminal.Emulator.Output do
  @moduledoc """
  Handles output processing for the terminal emulator.
  Provides functions for output buffering, processing, and formatting.
  """

  require Raxol.Core.Runtime.Log

  alias Raxol.Terminal.Emulator.Struct, as: EmulatorStruct
  alias Raxol.Terminal.Parser

  @doc """
  Processes output data.
  Returns {:ok, updated_emulator, commands} or {:error, reason}.
  """
  @spec process_output(EmulatorStruct.t(), String.t()) ::
          {:ok, EmulatorStruct.t(), list()} | {:error, String.t()}
  def process_output(%EmulatorStruct{} = emulator, data) when is_binary(data) do
    # Add data to output buffer
    updated_emulator = %{
      emulator
      | output_buffer: emulator.output_buffer <> data
    }

    # Process the output buffer
    case process_buffer(updated_emulator) do
      {:ok, final_emulator, commands} ->
        {:ok, final_emulator, commands}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def process_output(%EmulatorStruct{} = _emulator, invalid_data) do
    {:error, "Invalid output data: #{inspect(invalid_data)}"}
  end

  @doc """
  Gets the current output buffer.
  Returns the current output buffer.
  """
  @spec get_output_buffer(EmulatorStruct.t()) :: String.t()
  def get_output_buffer(%EmulatorStruct{} = emulator) do
    emulator.output_buffer
  end

  @doc """
  Clears the output buffer.
  Returns {:ok, updated_emulator}.
  """
  @spec clear_output_buffer(EmulatorStruct.t()) :: {:ok, EmulatorStruct.t()}
  def clear_output_buffer(%EmulatorStruct{} = emulator) do
    {:ok, %{emulator | output_buffer: ""}}
  end

  @doc """
  Flushes the output buffer.
  Returns {:ok, updated_emulator, commands} or {:error, reason}.
  """
  @spec flush_output_buffer(EmulatorStruct.t()) ::
          {:ok, EmulatorStruct.t(), list()} | {:error, String.t()}
  def flush_output_buffer(%EmulatorStruct{} = emulator) do
    case process_buffer(emulator) do
      {:ok, updated_emulator, commands} ->
        # Clear the buffer after processing
        {:ok, %{updated_emulator | output_buffer: ""}, commands}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Writes data to the output buffer.
  Returns {:ok, updated_emulator}.
  """
  @spec write(EmulatorStruct.t(), String.t()) :: {:ok, EmulatorStruct.t()}
  def write(%EmulatorStruct{} = emulator, data) when is_binary(data) do
    {:ok, %{emulator | output_buffer: emulator.output_buffer <> data}}
  end

  def write(%EmulatorStruct{} = _emulator, invalid_data) do
    {:error, "Invalid write data: #{inspect(invalid_data)}"}
  end

  @doc """
  Writes a line to the output buffer.
  Returns {:ok, updated_emulator}.
  """
  @spec write_line(EmulatorStruct.t(), String.t()) :: {:ok, EmulatorStruct.t()}
  def write_line(%EmulatorStruct{} = emulator, data) when is_binary(data) do
    write(emulator, data <> "\r\n")
  end

  def write_line(%EmulatorStruct{} = _emulator, invalid_data) do
    {:error, "Invalid line data: #{inspect(invalid_data)}"}
  end

  @doc """
  Writes a control character to the output buffer.
  Returns {:ok, updated_emulator}.
  """
  @spec write_control(EmulatorStruct.t(), char()) :: {:ok, EmulatorStruct.t()}
  def write_control(%EmulatorStruct{} = emulator, char)
      when is_integer(char) and char in 0..31 do
    write(emulator, <<char>>)
  end

  def write_control(%EmulatorStruct{} = _emulator, invalid_char) do
    {:error, "Invalid control character: #{inspect(invalid_char)}"}
  end

  @doc """
  Writes an escape sequence to the output buffer.
  Returns {:ok, updated_emulator}.
  """
  @spec write_escape(EmulatorStruct.t(), String.t()) :: {:ok, EmulatorStruct.t()}
  def write_escape(%EmulatorStruct{} = emulator, sequence) when is_binary(sequence) do
    write(emulator, "\e" <> sequence)
  end

  def write_escape(%EmulatorStruct{} = _emulator, invalid_sequence) do
    {:error, "Invalid escape sequence: #{inspect(invalid_sequence)}"}
  end

  # Private helper functions

  defp process_buffer(%EmulatorStruct{} = emulator) do
    # Process the output buffer using the parser
    case Parser.parse(emulator.parser_state, emulator.output_buffer) do
      {:ok, updated_state, commands} ->
        {:ok, %{emulator | parser_state: updated_state}, commands}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
