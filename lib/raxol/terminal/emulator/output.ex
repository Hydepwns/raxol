defmodule Raxol.Terminal.Emulator.Output do
  @moduledoc """
  Handles output processing for the terminal emulator.
  Provides functions for output buffering, processing, and formatting.
  """

  require Raxol.Core.Runtime.Log

  alias Raxol.Terminal.{
    Emulator,
    Parser
  }

  @doc """
  Processes output data.
  Returns {:ok, updated_emulator, commands} or {:error, reason}.
  """
  @spec process_output(Emulator.t(), String.t()) ::
          {:ok, Emulator.t(), list()} | {:error, String.t()}
  def process_output(%Emulator{} = emulator, data) when is_binary(data) do
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

  def process_output(%Emulator{} = _emulator, invalid_data) do
    {:error, "Invalid output data: #{inspect(invalid_data)}"}
  end

  @doc """
  Gets the current output buffer.
  Returns the current output buffer.
  """
  @spec get_output_buffer(Emulator.t()) :: String.t()
  def get_output_buffer(%Emulator{} = emulator) do
    emulator.output_buffer
  end

  @doc """
  Clears the output buffer.
  Returns {:ok, updated_emulator}.
  """
  @spec clear_output_buffer(Emulator.t()) :: {:ok, Emulator.t()}
  def clear_output_buffer(%Emulator{} = emulator) do
    {:ok, %{emulator | output_buffer: ""}}
  end

  @doc """
  Flushes the output buffer.
  Returns {:ok, updated_emulator, commands} or {:error, reason}.
  """
  @spec flush_output_buffer(Emulator.t()) ::
          {:ok, Emulator.t(), list()} | {:error, String.t()}
  def flush_output_buffer(%Emulator{} = emulator) do
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
  @spec write(Emulator.t(), String.t()) :: {:ok, Emulator.t()}
  def write(%Emulator{} = emulator, data) when is_binary(data) do
    {:ok, %{emulator | output_buffer: emulator.output_buffer <> data}}
  end

  def write(%Emulator{} = _emulator, invalid_data) do
    {:error, "Invalid write data: #{inspect(invalid_data)}"}
  end

  @doc """
  Writes a line to the output buffer.
  Returns {:ok, updated_emulator}.
  """
  @spec write_line(Emulator.t(), String.t()) :: {:ok, Emulator.t()}
  def write_line(%Emulator{} = emulator, data) when is_binary(data) do
    write(emulator, data <> "\r\n")
  end

  def write_line(%Emulator{} = _emulator, invalid_data) do
    {:error, "Invalid line data: #{inspect(invalid_data)}"}
  end

  @doc """
  Writes a control character to the output buffer.
  Returns {:ok, updated_emulator}.
  """
  @spec write_control(Emulator.t(), char()) :: {:ok, Emulator.t()}
  def write_control(%Emulator{} = emulator, char)
      when is_integer(char) and char in 0..31 do
    write(emulator, <<char>>)
  end

  def write_control(%Emulator{} = _emulator, invalid_char) do
    {:error, "Invalid control character: #{inspect(invalid_char)}"}
  end

  @doc """
  Writes an escape sequence to the output buffer.
  Returns {:ok, updated_emulator}.
  """
  @spec write_escape(Emulator.t(), String.t()) :: {:ok, Emulator.t()}
  def write_escape(%Emulator{} = emulator, sequence) when is_binary(sequence) do
    write(emulator, "\e" <> sequence)
  end

  def write_escape(%Emulator{} = _emulator, invalid_sequence) do
    {:error, "Invalid escape sequence: #{inspect(invalid_sequence)}"}
  end

  # Private helper functions

  defp process_buffer(%Emulator{} = emulator) do
    # Process the output buffer using the parser
    case Parser.parse(emulator.parser_state, emulator.output_buffer) do
      {:ok, updated_state, commands} ->
        {:ok, %{emulator | parser_state: updated_state}, commands}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
