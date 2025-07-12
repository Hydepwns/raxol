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

  @spec write(t(), String.t()) :: t()
  def write(%__MODULE__{} = state, data) do
    %{state | buffer: state.buffer <> data}
  end

  @spec flush(t()) :: t()
  def flush(%__MODULE__{} = state) do
    %{state | buffer: ""}
  end

  @spec clear(t()) :: t()
  def clear(%__MODULE__{} = state) do
    %{state | buffer: "", control_sequences: []}
  end

  @spec enqueue_control_sequence(t(), String.t()) :: t()
  def enqueue_control_sequence(%__MODULE__{} = state, sequence) do
    %{state | control_sequences: state.control_sequences ++ [sequence]}
  end
end
