defmodule Raxol.Terminal.ScreenBuffer.Output do
  @moduledoc """
  Handles output buffer operations for the terminal screen buffer.
  This module manages the output buffer state and provides functions for writing,
  flushing, and clearing the buffer.
  """

  @type t :: %__MODULE__{
          buffer: String.t(),
          control_sequences: list(String.t())
        }

  defstruct buffer: "", control_sequences: []

  @doc """
  Writes data to the output buffer.
  Returns a new output buffer state with the data appended.
  """
  @spec write(t(), String.t()) :: t()
  def write(%__MODULE__{} = state, data) do
    %{state | buffer: state.buffer <> data}
  end

  @doc """
  Flushes the output buffer.
  Returns a new output buffer state with an empty buffer.
  """
  @spec flush(t()) :: t()
  def flush(%__MODULE__{} = state) do
    %{state | buffer: ""}
  end

  @doc """
  Clears the output buffer and control sequences.
  Returns a new output buffer state with empty buffer and control sequences.
  """
  @spec clear(t()) :: t()
  def clear(%__MODULE__{} = state) do
    %{state | buffer: "", control_sequences: []}
  end

  @doc """
  Enqueues a control sequence to be processed.
  Returns a new output buffer state with the sequence added to the queue.
  """
  @spec enqueue_control_sequence(t(), String.t()) :: t()
  def enqueue_control_sequence(%__MODULE__{} = state, sequence) do
    %{state | control_sequences: state.control_sequences ++ [sequence]}
  end
end
