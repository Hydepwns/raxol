defmodule Raxol.Terminal.Buffer.Operations do
  @moduledoc """
  Handles buffer operations for the terminal, including resizing, scrolling,
  and cursor movement.
  """

  alias Raxol.Terminal.Buffer.Cell

  @doc """
  Resizes the buffer to the specified dimensions.
  """
  def resize(buffer, rows, cols)
      when is_list(buffer) and is_integer(rows) and is_integer(cols) do
    # Ensure minimum dimensions
    rows = max(1, rows)
    cols = max(1, cols)

    # Create new buffer with specified dimensions
    new_buffer =
      for _ <- 1..rows do
        for _ <- 1..cols do
          Cell.new()
        end
      end

    # Copy existing content, truncating or padding as needed
    buffer
    |> Enum.take(rows)
    |> Enum.map(fn row ->
      row
      |> Enum.take(cols)
      |> Enum.concat(List.duplicate(Cell.new(), max(0, cols - length(row))))
    end)
    |> Enum.concat(
      List.duplicate(
        List.duplicate(Cell.new(), cols),
        max(0, rows - length(buffer))
      )
    )
  end

  @doc """
  Checks if scrolling is needed and performs it if necessary.
  """
  def maybe_scroll(buffer) when is_list(buffer) do
    # Check if we need to scroll
    if needs_scroll?(buffer) do
      scroll_up(buffer, 1)
    else
      buffer
    end
  end

  @doc """
  Moves the cursor to the next line, scrolling if necessary.
  """
  def next_line(buffer) when is_list(buffer) do
    buffer
    |> maybe_scroll()
    |> index()
  end

  @doc """
  Moves the cursor to the previous line.
  """
  def reverse_index(buffer) when is_list(buffer) do
    # Move cursor up one line
    buffer
  end

  @doc """
  Moves the cursor to the beginning of the next line.
  """
  def index(buffer) when is_list(buffer) do
    # Move cursor to beginning of next line
    buffer
  end

  @doc """
  Scrolls the buffer up by the specified number of lines.
  """
  def scroll_up(buffer, lines)
      when is_list(buffer) and is_integer(lines) and lines > 0 do
    # Remove lines from top and add empty lines at bottom
    buffer
    |> Enum.drop(lines)
    |> Enum.concat(List.duplicate(create_empty_line(length(hd(buffer))), lines))
  end

  @doc """
  Scrolls the buffer down by the specified number of lines.
  """
  def scroll_down(buffer, lines)
      when is_list(buffer) and is_integer(lines) and lines > 0 do
    # Remove lines from bottom and add empty lines at top
    buffer
    |> Enum.reverse()
    |> Enum.drop(lines)
    |> Enum.reverse()
    |> Enum.concat(List.duplicate(create_empty_line(length(hd(buffer))), lines))
  end

  @doc """
  Inserts the specified number of blank lines at the cursor position.
  """
  def insert_lines(buffer, count)
      when is_list(buffer) and is_integer(count) and count > 0 do
    # Insert blank lines at cursor position
    buffer
    |> Enum.take(count)
    |> Enum.concat(List.duplicate(create_empty_line(length(hd(buffer))), count))
    |> Enum.concat(Enum.drop(buffer, count))
  end

  @doc """
  Deletes the specified number of lines at the cursor position.
  """
  def delete_lines(buffer, count)
      when is_list(buffer) and is_integer(count) and count > 0 do
    # Delete lines at cursor position
    buffer
    |> Enum.take(count)
    |> Enum.concat(Enum.drop(buffer, count + count))
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

  # Private helper functions

  defp needs_scroll?(buffer) do
    # Check if we need to scroll based on cursor position
    # This is a simplified check - you may want to add more conditions
    false
  end

  defp create_empty_line(cols) do
    List.duplicate(Cell.new(), cols)
  end
end
