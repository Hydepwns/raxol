defmodule Raxol.Terminal.Input.InputBuffer do
  @moduledoc """
  A simple data structure for managing input buffer state.

  This module provides a stateless API for managing input buffer data,
  separate from the GenServer-based Buffer module that handles process-based buffering.
  """

  defstruct contents: "",
            max_size: 1024,
            overflow_mode: :truncate

  @type overflow_mode :: :truncate | :wrap | :error
  @type t :: %__MODULE__{
          contents: binary(),
          max_size: non_neg_integer(),
          overflow_mode: overflow_mode()
        }

  @doc """
  Creates a new input buffer with default values.
  """
  def new do
    %__MODULE__{}
  end

  @doc """
  Creates a new input buffer with custom max_size and overflow_mode.
  """
  def new(max_size, overflow_mode) do
    %__MODULE__{
      max_size: max_size,
      overflow_mode: overflow_mode
    }
  end

  @doc """
  Gets the current contents of the buffer.
  """
  def get_contents(%__MODULE__{contents: contents}), do: contents

  @doc """
  Gets the maximum size of the buffer.
  """
  def max_size(%__MODULE__{max_size: max_size}), do: max_size

  @doc """
  Gets the overflow mode of the buffer.
  """
  def overflow_mode(%__MODULE__{overflow_mode: overflow_mode}),
    do: overflow_mode

  @doc """
  Sets the contents of the buffer, handling overflow according to the buffer's mode.
  """
  def set_contents(%__MODULE__{} = buffer, new_contents) do
    processed_contents = handle_overflow(buffer, new_contents)
    %{buffer | contents: processed_contents}
  end

  @doc """
  Prepends data to the buffer.
  """
  def prepend(
        %__MODULE__{
          contents: current_contents,
          max_size: max_size,
          overflow_mode: overflow_mode
        } = buffer,
        new_data
      ) do
    combined_contents = new_data <> current_contents

    processed_contents =
      case overflow_mode do
        :truncate when byte_size(combined_contents) > max_size ->
          # For prepend + truncate, keep the rightmost content
          start_pos = byte_size(combined_contents) - max_size
          binary_part(combined_contents, start_pos, max_size)

        :wrap when byte_size(combined_contents) > max_size ->
          # For prepend + wrap, keep the leftmost content
          binary_part(combined_contents, 0, max_size)

        _ ->
          handle_overflow(buffer, combined_contents)
      end

    %{buffer | contents: processed_contents}
  end

  @doc """
  Appends data to the buffer.
  """
  def append(%__MODULE__{contents: current_contents} = buffer, new_data) do
    combined_contents = current_contents <> new_data
    processed_contents = handle_overflow(buffer, combined_contents)
    %{buffer | contents: processed_contents}
  end

  @doc """
  Clears the buffer contents.
  """
  def clear(%__MODULE__{} = buffer) do
    %{buffer | contents: ""}
  end

  @doc """
  Gets the current size (byte count) of the buffer contents.
  """
  def size(%__MODULE__{contents: contents}), do: byte_size(contents)

  @doc """
  Checks if the buffer is empty.
  """
  def empty?(%__MODULE__{contents: ""}), do: true
  def empty?(%__MODULE__{}), do: false

  @doc """
  Sets the maximum size of the buffer.
  """
  def set_max_size(%__MODULE__{} = buffer, new_max_size) do
    updated_buffer = %{buffer | max_size: new_max_size}
    processed_contents = handle_overflow(updated_buffer, buffer.contents)
    %{updated_buffer | contents: processed_contents}
  end

  @doc """
  Sets the overflow mode of the buffer.
  """
  def set_overflow_mode(%__MODULE__{} = buffer, new_overflow_mode) do
    %{buffer | overflow_mode: new_overflow_mode}
  end

  @doc """
  Removes the last character from the buffer (backspace).
  """
  def backspace(%__MODULE__{contents: ""} = buffer), do: buffer

  def backspace(%__MODULE__{contents: contents} = buffer) do
    graphemes = String.graphemes(contents)
    new_contents = graphemes |> Enum.drop(-1) |> Enum.join()
    %{buffer | contents: new_contents}
  end

  @doc """
  Removes the first character from the buffer.
  """
  def delete_first(%__MODULE__{contents: ""} = buffer), do: buffer

  def delete_first(%__MODULE__{contents: contents} = buffer) do
    graphemes = String.graphemes(contents)
    new_contents = graphemes |> Enum.drop(1) |> Enum.join()
    %{buffer | contents: new_contents}
  end

  @doc """
  Inserts a character at the specified position.
  """
  def insert_at(%__MODULE__{contents: contents} = buffer, position, char) do
    graphemes = String.graphemes(contents)
    length = length(graphemes)

    if position < 0 or position > length do
      raise ArgumentError, "Position out of bounds"
    end

    {before, after_part} = Enum.split(graphemes, position)
    new_contents = (before ++ [char] ++ after_part) |> Enum.join()
    processed_contents = handle_overflow(buffer, new_contents)
    %{buffer | contents: processed_contents}
  end

  @doc """
  Replaces a character at the specified position.
  """
  def replace_at(%__MODULE__{contents: contents} = buffer, position, char) do
    graphemes = String.graphemes(contents)
    length = length(graphemes)

    if position < 0 or position >= length do
      raise ArgumentError, "Position out of bounds"
    end

    new_graphemes = List.replace_at(graphemes, position, char)
    new_contents = Enum.join(new_graphemes)
    processed_contents = handle_overflow(buffer, new_contents)
    %{buffer | contents: processed_contents}
  end

  # Private helper functions

  defp handle_overflow(
         %__MODULE__{max_size: max_size, overflow_mode: mode},
         contents
       ) do
    content_length = byte_size(contents)

    if content_length <= max_size do
      contents
    else
      apply_overflow_mode(mode, contents, max_size)
    end
  end

  defp apply_overflow_mode(:truncate, contents, max_size) do
    binary_part(contents, 0, max_size)
  end

  defp apply_overflow_mode(:wrap, contents, max_size) do
    content_length = byte_size(contents)

    if content_length <= max_size do
      contents
    else
      # Take the last max_size bytes
      start_pos = content_length - max_size
      binary_part(contents, start_pos, max_size)
    end
  end

  defp apply_overflow_mode(:error, contents, max_size) do
    if byte_size(contents) > max_size do
      raise RuntimeError, "Buffer overflow"
    else
      contents
    end
  end
end
