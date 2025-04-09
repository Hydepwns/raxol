defmodule Raxol.Terminal.Input.InputBuffer do
  alias Raxol.Terminal.Input.InputBufferUtils
  alias Raxol.Terminal.Input.Types

  @moduledoc """
  Handles input buffering for the terminal emulator.
  Provides functionality for storing, retrieving, and manipulating input data.
  """

  defstruct [
    :contents,
    :max_size,
    :overflow_mode,
    :escape_sequence,
    :escape_sequence_mode,
    cursor_pos: 0,
    width: 80
  ]

  @type t :: Types.input_buffer()

  @doc """
  Creates a new input buffer with default values.
  """
  def new(max_size \\ 1024, overflow_mode \\ :truncate) do
    %__MODULE__{
      contents: "",
      max_size: max_size,
      overflow_mode: overflow_mode,
      escape_sequence: "",
      escape_sequence_mode: false,
      cursor_pos: 0,
      width: 80
    }
  end

  @doc """
  Appends data to the buffer, handling escape sequences appropriately.
  """
  def append(%__MODULE__{} = buffer, data) when is_binary(data) do
    if buffer.escape_sequence_mode do
      handle_escape_sequence(buffer, data)
    else
      case data do
        "\e" ->
          %{buffer | escape_sequence_mode: true, escape_sequence: "\e"}
        _ ->
          append_to_contents(buffer, data)
      end
    end
  end

  @doc """
  Prepends data to the buffer.
  """
  def prepend(%__MODULE__{} = buffer, data) when is_binary(data) do
    new_contents = data <> buffer.contents

    if String.length(new_contents) <= buffer.max_size do
      %{buffer | contents: new_contents}
    else
      case buffer.overflow_mode do
        :truncate ->
          %{buffer | contents: String.slice(new_contents, 0, buffer.max_size)}
        :error ->
          buffer
        :wrap ->
          %{buffer | contents: String.slice(new_contents, -buffer.max_size..-1)}
      end
    end
  end

  @doc """
  Sets the buffer contents.
  """
  def set_contents(%__MODULE__{} = buffer, contents) when is_binary(contents) do
    if String.length(contents) <= buffer.max_size do
      %{buffer | contents: contents}
    else
      case buffer.overflow_mode do
        :truncate ->
          %{buffer | contents: String.slice(contents, 0, buffer.max_size)}
        :error ->
          buffer
        :wrap ->
          %{buffer | contents: String.slice(contents, -buffer.max_size..-1)}
      end
    end
  end

  @doc """
  Gets the buffer contents.
  """
  def get_contents(%__MODULE__{} = buffer) do
    buffer.contents
  end

  @doc """
  Clears the buffer.
  """
  def clear(%__MODULE__{} = buffer) do
    %{buffer | contents: ""}
  end

  @doc """
  Checks if the buffer is empty.
  """
  def empty?(%__MODULE__{} = buffer) do
    buffer.contents == ""
  end

  @doc """
  Gets the current size of the buffer.
  """
  def size(%__MODULE__{} = buffer) do
    String.length(buffer.contents)
  end

  @doc """
  Gets the maximum size of the buffer.
  """
  def max_size(%__MODULE__{} = buffer) do
    buffer.max_size
  end

  @doc """
  Sets the maximum size of the buffer.
  """
  def set_max_size(%__MODULE__{} = buffer, max_size) when is_integer(max_size) and max_size > 0 do
    %{buffer | max_size: max_size}
  end

  @doc """
  Sets the overflow mode of the buffer.
  """
  def set_overflow_mode(%__MODULE__{} = buffer, mode) when mode in [:truncate, :error, :wrap] do
    %{buffer | overflow_mode: mode}
  end

  @doc """
  Gets the overflow mode of the buffer.
  """
  def overflow_mode(%__MODULE__{} = buffer) do
    buffer.overflow_mode
  end

  @doc """
  Removes the last character from the buffer.
  """
  def backspace(%__MODULE__{} = buffer) do
    if String.length(buffer.contents) > 0 do
      %{buffer | contents: String.slice(buffer.contents, 0..-2//-1)}
    else
      buffer
    end
  end

  @doc """
  Removes the first character from the buffer.
  """
  def delete_first(%__MODULE__{} = buffer) do
    if String.length(buffer.contents) > 0 do
      %{buffer | contents: String.slice(buffer.contents, 1..-1//1)}
    else
      buffer
    end
  end

  @doc """
  Inserts a character at the specified position.
  """
  def insert_at(%__MODULE__{} = buffer, position, char) when is_binary(char) do
    if String.length(char) == 1 and position <= String.length(buffer.contents) do
      new_contents =
        String.slice(buffer.contents, 0, position) <>
        char <>
        String.slice(buffer.contents, position..-1)

      %{buffer | contents: new_contents}
    else
      buffer
    end
  end

  @doc """
  Replaces a character at the specified position.
  """
  def replace_at(%__MODULE__{} = buffer, position, char) when is_binary(char) do
    if String.length(char) == 1 and position <= String.length(buffer.contents) do
      new_contents =
        String.slice(buffer.contents, 0, position) <>
        char <>
        String.slice(buffer.contents, position + 1..-1)

      %{buffer | contents: new_contents}
    else
      buffer
    end
  end

  @doc """
  Handles escape sequence processing.
  """
  def handle_escape_sequence(%__MODULE__{} = buffer, data) do
    new_sequence = buffer.escape_sequence <> data

    case data do
      # End of escape sequence
      <<c>> when c >= ?@ and c <= ?~ ->
        %{buffer |
          contents: buffer.contents <> new_sequence,
          escape_sequence: "",
          escape_sequence_mode: false
        }
      # More escape sequence data
      _ ->
        %{buffer | escape_sequence: new_sequence}
    end
  end

  defp append_to_contents(%__MODULE__{} = buffer, data) do
    new_contents = buffer.contents <> data

    if String.length(new_contents) <= buffer.max_size do
      %{buffer | contents: new_contents}
    else
      case buffer.overflow_mode do
        :truncate ->
          %{buffer | contents: String.slice(new_contents, 0, buffer.max_size)}
        :error ->
          buffer
        :wrap ->
          %{buffer | contents: String.slice(new_contents, -buffer.max_size..-1)}
      end
    end
  end

  def handle_resize(%__MODULE__{} = buffer, new_width) do
    if new_width <= 0 do
      buffer
    else
      {original_logical_line_index, original_pos_in_line} =
        InputBufferUtils.find_logical_position(buffer.contents, buffer.cursor_pos)

      logical_lines_old = String.split(buffer.contents, "\n")

      # Build mapping *during* wrapping (More Accurate Approach)
      {wrapped_lines_new_list, {_final_wrapped_idx, line_mapping}} =
        Enum.map_reduce(Enum.with_index(logical_lines_old), {0, %{}}, fn {line, old_idx}, {current_wrapped_idx, acc_mapping} ->
          newly_wrapped_lines = InputBufferUtils.wrap_line(line, new_width)
          num_lines_produced = length(newly_wrapped_lines)
          indices = Enum.to_list(current_wrapped_idx .. (current_wrapped_idx + num_lines_produced - 1))
          {newly_wrapped_lines, {current_wrapped_idx + num_lines_produced, Map.put(acc_mapping, old_idx, indices)}}
        end)

      wrapped_lines_new = List.flatten(wrapped_lines_new_list)
      new_contents = Enum.join(wrapped_lines_new, "\n")

      new_cursor_pos =
        InputBufferUtils.calculate_new_cursor_pos_v2(
          line_mapping,
          wrapped_lines_new,
          original_logical_line_index,
          original_pos_in_line,
          new_contents
        )

      %{buffer | contents: new_contents, width: new_width, cursor_pos: new_cursor_pos}
    end
  end

  def move_cursor_to_end_of_line(%__MODULE__{contents: contents, cursor_pos: cursor_pos} = buffer) do
    # 1. Find the index of the logical line the cursor is currently on
    {logical_line_index, _pos_in_line} = InputBufferUtils.find_logical_position(contents, cursor_pos)

    # 2. Calculate the character offset for the end of that logical line
    logical_lines = String.split(contents, "\n")

    new_cursor_pos =
      Enum.reduce(0..logical_line_index, 0, fn i, acc ->
        # Add length of the current line
        current_line_len = String.length(Enum.at(logical_lines, i))
        # Add 1 for the newline, unless it's the very last line being considered *and* it's the last line of the buffer
        newline_char_count = if i < logical_line_index, do: 1, else: 0
        acc + current_line_len + newline_char_count
      end)

    %{buffer | cursor_pos: new_cursor_pos}
  end
end
