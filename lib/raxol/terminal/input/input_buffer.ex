defmodule Raxol.Terminal.Input.InputBuffer do
  alias Raxol.Terminal.Input.Types
  alias Raxol.Terminal.Input.InputBufferUtils

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
    handle_overflow(buffer, new_contents, :prepend)
  end

  @doc """
  Sets the buffer contents.
  """
  def set_contents(%__MODULE__{} = buffer, contents) when is_binary(contents) do
    handle_overflow(buffer, contents)
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
  If the current content exceeds the new max size, it will be handled
  according to the current overflow mode.
  """
  def set_max_size(%__MODULE__{} = buffer, max_size)
      when is_integer(max_size) and max_size > 0 do
    # Update the max_size first
    new_buffer = %{buffer | max_size: max_size}
    # Then, handle potential overflow of existing content with the new size
    handle_overflow(new_buffer, new_buffer.contents)
  end

  @doc """
  Sets the overflow mode of the buffer.
  """
  def set_overflow_mode(%__MODULE__{} = buffer, mode)
      when mode in [:truncate, :error, :wrap] do
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
  Uses graphemes to handle multi-byte characters correctly.
  """
  def backspace(%__MODULE__{contents: contents} = buffer) do
    if String.length(contents) > 0 do
      new_contents =
        contents |> String.graphemes() |> Enum.drop(-1) |> Enum.join()

      %{buffer | contents: new_contents}
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
  Raises ArgumentError if position is out of bounds.
  """
  def insert_at(%__MODULE__{} = buffer, position, char) when is_binary(char) do
    content_len = String.length(buffer.contents)
    _char_len = String.length(char)

    if position < 0 or position > content_len do
      raise ArgumentError, "Position out of bounds"
    end

    # Ensure positive step
    new_contents =
      String.slice(buffer.contents, 0, position) <>
        char <>
        String.slice(buffer.contents, position..-1//1)

    # After insertion, check for overflow
    handle_overflow(buffer, new_contents)
  end

  @doc """
  Replaces a character at the specified position.
  Raises ArgumentError if position is out of bounds.
  """
  def replace_at(%__MODULE__{} = buffer, position, char) when is_binary(char) do
    content_len = String.length(buffer.contents)
    _char_len = String.length(char)

    if position < 0 or position >= content_len do
      raise ArgumentError, "Position out of bounds"
    end

    # Calculate slices carefully
    prefix = String.slice(buffer.contents, 0, position)
    # Ensure positive step
    suffix = String.slice(buffer.contents, (position + String.length(char))..-1//1)

    new_contents = prefix <> char <> suffix

    # After replacement, check for overflow (char might be longer than replaced section)
    handle_overflow(buffer, new_contents)
  end

  @doc """
  Handles escape sequence processing.
  """
  def handle_escape_sequence(%__MODULE__{} = buffer, data) do
    new_sequence = buffer.escape_sequence <> data

    case data do
      # End of escape sequence
      <<c>> when c >= ?@ and c <= ?~ ->
        %{
          buffer
          | contents: buffer.contents <> new_sequence,
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
    handle_overflow(buffer, new_contents, :append)
  end

  @doc false
  defp handle_overflow(
         %__MODULE__{} = buffer,
         new_contents,
         operation \\ :append
       ) do
    content_len = String.length(new_contents)

    if content_len <= buffer.max_size do
      %{buffer | contents: new_contents}
    else
      case buffer.overflow_mode do
        :truncate ->
          # For append/set_contents (default), take the start.
          # For prepend, take the end.
          final_contents =
            if operation == :prepend do
              String.slice(new_contents, -buffer.max_size..-1//1)
            else
              String.slice(new_contents, 0, buffer.max_size)
            end

          %{buffer | contents: final_contents}

        :error ->
          # Raise the error instead of returning the old buffer
          raise RuntimeError, "Buffer overflow"

        :wrap ->
          # For append/set_contents (default), take the end.
          # For prepend, take the start.
          final_contents =
            if operation == :prepend do
              String.slice(new_contents, 0, buffer.max_size)
            else
              String.slice(new_contents, -buffer.max_size..-1//1)
            end

          %{buffer | contents: final_contents}
      end
    end
  end

  def handle_resize(%__MODULE__{} = buffer, new_width) do
    if new_width <= 0 do
      buffer
    else
      {original_logical_line_index, original_pos_in_line} =
        InputBufferUtils.find_logical_position(
          buffer.contents,
          buffer.cursor_pos
        )

      logical_lines_old = String.split(buffer.contents, "\n")

      # Build mapping *during* wrapping (More Accurate Approach)
      {wrapped_lines_new_list, {_final_wrapped_idx, line_mapping}} =
        Enum.map_reduce(Enum.with_index(logical_lines_old), {0, %{}}, fn {line,
                                                                          old_idx},
                                                                         {current_wrapped_idx,
                                                                          acc_mapping} ->
          newly_wrapped_lines = InputBufferUtils.wrap_line(line, new_width)
          num_lines_produced = length(newly_wrapped_lines)

          indices =
            Enum.to_list(
              current_wrapped_idx..(current_wrapped_idx + num_lines_produced - 1)
            )

          {newly_wrapped_lines,
           {current_wrapped_idx + num_lines_produced,
            Map.put(acc_mapping, old_idx, indices)}}
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

      %{
        buffer
        | contents: new_contents,
          width: new_width,
          cursor_pos: new_cursor_pos
      }
    end
  end

  def move_cursor_to_end_of_line(
        %__MODULE__{contents: contents, cursor_pos: cursor_pos} = buffer
      ) do
    # 1. Find the index of the logical line the cursor is currently on
    {logical_line_index, _pos_in_line} =
      InputBufferUtils.find_logical_position(contents, cursor_pos)

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

  # This function appears unused currently.
  # defp insert_at_index(str, index, char) do
  #   {prefix, suffix} = String.split_at(str, index)
  #   # Calculate char length for accurate cursor positioning after insert
  #   _char_len = String.length(char) # Prefix with _ as it seems unused below
  #   prefix <> char <> suffix
  # end
end
