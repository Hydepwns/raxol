defmodule Raxol.Terminal.Buffer.Operations.Text do
  @moduledoc """
  Handles text operations for terminal buffers including character and string writing.
  """

  alias Raxol.Terminal.Buffer.Cell

  @doc """
  Writes a character to the buffer at the specified position.
  """
  # Handle ScreenBuffer structs - this is the main path used by the emulator
  def write_char(%Raxol.Terminal.ScreenBuffer{} = buffer, x, y, char, style)
      when is_integer(x) and is_integer(y) and is_binary(char) and is_map(style) do
    # Use the ScreenBuffer's own write_char implementation
    Raxol.Terminal.ScreenBuffer.write_char(buffer, x, y, char, style)
  end

  # Handle list buffers - this should only be used for internal operations
  def write_char(buffer, x, y, char, style)
      when is_list(buffer) and is_integer(x) and is_integer(y) and
             is_binary(char) and is_map(style) do
    new_buffer =
      buffer
      |> Enum.with_index()
      |> Enum.map(fn {row, row_y} ->
        case row_y == y do
          true ->
            replace_cell(row, x, char, style)

          false ->
            row
        end
      end)

    # Return just the buffer, not a tuple, to avoid corruption
    new_buffer
  end

  defp replace_cell(row, x, char, style) do
    Enum.with_index(row)
    |> Enum.map(fn {cell, col_x} ->
      case col_x == x do
        true ->
          Cell.new(char, style)

        false ->
          cell
      end
    end)
  end

  @doc """
  Writes a string to the buffer.
  """
  def write_string(buffer, x, y, string) do
    Raxol.Terminal.Buffer.Writer.write_string(buffer, x, y, string)
  end

  @doc """
  Writes data to the buffer.
  """
  def write(buffer, data, opts \\ [])

  def write(%Raxol.Terminal.Buffer.Manager.BufferImpl{} = buffer, data, opts) do
    # Handle BufferImpl structs
    case classify_data(data) do
      {:char, x, y, char} ->
        write_char_to_buffer_impl(buffer, x, y, char, opts)

      {:string, x, y, string} ->
        write_string_to_buffer_impl(buffer, x, y, string, opts)

      :unknown ->
        handle_unknown_data(buffer, data)
    end
  end

  def write(buffer, data, opts) do
    case classify_data(data) do
      {:char, x, y, char} -> write_char_data(buffer, x, y, char, opts)
      {:string, x, y, string} -> write_string_data(buffer, x, y, string)
      :unknown -> buffer
    end
  end

  defp classify_data({x, y, char})
       when is_integer(x) and is_integer(y) and is_binary(char) and
              byte_size(char) == 1 do
    {:char, x, y, char}
  end

  defp classify_data({x, y, string})
       when is_integer(x) and is_integer(y) and is_binary(string) and
              byte_size(string) > 1 do
    {:string, x, y, string}
  end

  defp classify_data(_), do: :unknown

  defp write_char_data(buffer, x, y, char, opts) do
    Raxol.Terminal.Buffer.Writer.write_char(
      buffer,
      x,
      y,
      char,
      Keyword.get(opts, :style)
    )
  end

  defp write_string_data(buffer, x, y, string) do
    Raxol.Terminal.Buffer.Writer.write_string(buffer, x, y, string)
  end

  defp write_char_to_buffer_impl(buffer, x, y, char, opts) do
    cell = Raxol.Terminal.Cell.new(char, Keyword.get(opts, :style))
    Raxol.Terminal.Buffer.Manager.BufferImpl.set_cell(buffer, x, y, cell)
  end

  defp write_string_to_buffer_impl(buffer, x, y, string, opts) do
    Enum.reduce(
      Enum.with_index(String.graphemes(string)),
      buffer,
      &write_char_at_position(&1, &2, x, y, opts)
    )
  end

  defp write_char_at_position({char, index}, acc_buffer, x, y, opts) do
    cell = Raxol.Terminal.Cell.new(char, Keyword.get(opts, :style))

    Raxol.Terminal.Buffer.Manager.BufferImpl.set_cell(
      acc_buffer,
      x + index,
      y,
      cell
    )
  end

  defp handle_unknown_data(buffer, data) do
    case is_binary(data) do
      true ->
        Raxol.Terminal.Buffer.Manager.BufferImpl.add(buffer, data)

      false ->
        buffer
    end
  end

  @doc """
  Inserts the specified number of blank characters at the cursor position.
  """
  def insert_chars(buffer, count)
      when is_list(buffer) and is_integer(count) and count > 0 do
    # Insert blank characters at cursor position
    buffer
    |> Enum.map(fn row ->
      row
      |> Enum.take(count)
      |> Enum.concat(List.duplicate(Cell.new(), count))
      |> Enum.concat(Enum.drop(row, count))
    end)
  end

  @doc """
  Deletes the specified number of characters at the cursor position.
  """
  def delete_chars(buffer, count)
      when is_list(buffer) and is_integer(count) and count > 0 do
    # Delete characters at cursor position
    buffer
    |> Enum.map(fn row ->
      row
      |> Enum.take(count)
      |> Enum.concat(Enum.drop(row, count + count))
    end)
  end
end
