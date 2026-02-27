defmodule Raxol.Terminal.ScreenBuffer.Output do
  @moduledoc """
  Deprecated: This module is not used in the codebase.

  Originally intended for output buffer operations but never integrated.
  Output is handled by `Raxol.Terminal.OutputBuffer` instead.
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
    %{state | control_sequences: [sequence | state.control_sequences]}
  end
end
