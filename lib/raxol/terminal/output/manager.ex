defmodule Raxol.Terminal.Output.Manager do
  @moduledoc '''
  Manages terminal output buffering and control sequences.
  '''

  defstruct [
    output_buffer: "",
    control_sequences: [],
    buffer_size: 0,
    max_buffer_size: 1024 * 1024  # 1MB default buffer size
  ]

  @type t :: %__MODULE__{
    output_buffer: String.t(),
    control_sequences: [String.t()],
    buffer_size: non_neg_integer(),
    max_buffer_size: pos_integer()
  }

  @doc '''
  Creates a new output manager instance.
  '''
  def new(opts \\ []) do
    %__MODULE__{
      max_buffer_size: Keyword.get(opts, :max_buffer_size, 1024 * 1024)
    }
  end

  @doc '''
  Enqueues output to the buffer.
  '''
  def enqueue_output(%__MODULE__{} = state, output) when is_binary(output) do
    new_size = state.buffer_size + byte_size(output)

    if new_size > state.max_buffer_size do
      # If buffer would exceed max size, truncate the output
      truncated_size = state.max_buffer_size - state.buffer_size
      truncated_output = binary_part(output, 0, truncated_size)
      %{state |
        output_buffer: state.output_buffer <> truncated_output,
        buffer_size: state.max_buffer_size
      }
    else
      %{state |
        output_buffer: state.output_buffer <> output,
        buffer_size: new_size
      }
    end
  end

  @doc '''
  Flushes the output buffer and returns the content.
  '''
  def flush_output(%__MODULE__{} = state) do
    output = state.output_buffer
    new_state = %{state |
      output_buffer: "",
      buffer_size: 0
    }
    {output, new_state}
  end

  @doc '''
  Clears the output buffer.
  '''
  def clear_output_buffer(%__MODULE__{} = state) do
    %{state |
      output_buffer: "",
      buffer_size: 0
    }
  end

  @doc '''
  Gets the current output buffer content.
  '''
  def get_output_buffer(%__MODULE__{} = state) do
    state.output_buffer
  end

  @doc '''
  Enqueues a control sequence to be processed.
  '''
  def enqueue_control_sequence(%__MODULE__{} = state, sequence) when is_binary(sequence) do
    %{state |
      control_sequences: [sequence | state.control_sequences]
    }
  end

  @doc '''
  Gets the next control sequence from the queue.
  '''
  def get_next_control_sequence(%__MODULE__{} = state) do
    case state.control_sequences do
      [sequence | rest] ->
        {sequence, %{state | control_sequences: rest}}
      [] ->
        {nil, state}
    end
  end

  @doc '''
  Gets all pending control sequences.
  '''
  def get_pending_control_sequences(%__MODULE__{} = state) do
    state.control_sequences
  end

  @doc '''
  Clears all pending control sequences.
  '''
  def clear_control_sequences(%__MODULE__{} = state) do
    %{state | control_sequences: []}
  end

  @doc '''
  Gets the current buffer size.
  '''
  def get_buffer_size(%__MODULE__{} = state) do
    state.buffer_size
  end

  @doc '''
  Sets the maximum buffer size.
  '''
  def set_max_buffer_size(%__MODULE__{} = state, size) when is_integer(size) and size > 0 do
    %{state | max_buffer_size: size}
  end
end
