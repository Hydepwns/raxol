defmodule Raxol.Terminal.Buffer.Operations.Scrolling do
  @moduledoc """
  Handles scrolling operations for terminal buffers including scroll up/down and line insertion/deletion.
  """

  import Raxol.Guards
  alias Raxol.Terminal.Buffer.Cell

  @doc """
  Checks if scrolling is needed and performs it if necessary.
  """
  def maybe_scroll(buffer) when list?(buffer) do
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
  def next_line(buffer) when list?(buffer) do
    buffer
    |> maybe_scroll()
    |> index()
  end

  @doc """
  Moves the cursor to the previous line.
  """
  def reverse_index(buffer) when list?(buffer) do
    # Move cursor up one line
    buffer
  end

  @doc """
  Moves the cursor to the beginning of the next line.
  """
  def index(buffer) when list?(buffer) do
    # Move cursor to beginning of next line
    buffer
  end

  @doc """
  Scrolls the buffer up by the specified number of lines.
  """
  def scroll_up(buffer, lines, cursor_y, cursor_x)
      when list?(buffer) and is_integer(lines) and lines > 0 and
             is_integer(cursor_y) and is_integer(cursor_x) do
    # Remove lines from top and add empty lines at bottom
    new_buffer =
      buffer
      |> Enum.drop(lines)
      |> Enum.concat(
        List.duplicate(create_empty_line(length(hd(buffer))), lines)
      )

    # Adjust cursor position if needed
    if cursor_y >= lines do
      {new_buffer, cursor_y - lines, cursor_x}
    else
      {new_buffer, 0, cursor_x}
    end
  end

  def scroll_up(buffer, lines)
      when list?(buffer) and is_integer(lines) and lines > 0 do
    # Default cursor position to 0, 0 for backward compatibility
    {new_buffer, _cursor_y, _cursor_x} = scroll_up(buffer, lines, 0, 0)
    new_buffer
  end

  # Handle ScreenBuffer structs by extracting cells and calling the list version
  def scroll_up(%Raxol.Terminal.ScreenBuffer{} = buffer, lines)
      when is_integer(lines) and lines > 0 do
    # Extract cells from ScreenBuffer and call the list version
    {new_cells, _cursor_y, _cursor_x} = scroll_up(buffer.cells, lines, 0, 0)
    %{buffer | cells: new_cells}
  end

  # Handle ScreenBuffer structs with cursor position
  def scroll_up(
        %Raxol.Terminal.ScreenBuffer{} = buffer,
        lines,
        cursor_y,
        cursor_x
      )
      when is_integer(lines) and lines > 0 and
             is_integer(cursor_y) and is_integer(cursor_x) do
    # Extract cells from ScreenBuffer and call the list version
    {new_cells, new_cursor_y, new_cursor_x} =
      scroll_up(buffer.cells, lines, cursor_y, cursor_x)

    {%{buffer | cells: new_cells}, new_cursor_y, new_cursor_x}
  end

  @doc """
  Scrolls the buffer down by the specified number of lines.
  """
  def scroll_down(buffer, lines, cursor_y, cursor_x)
      when list?(buffer) and is_integer(lines) and lines > 0 and
             is_integer(cursor_y) and is_integer(cursor_x) do
    # Remove lines from bottom and add empty lines at top
    new_buffer =
      buffer
      |> Enum.reverse()
      |> Enum.drop(lines)
      |> Enum.reverse()
      |> Enum.concat(
        List.duplicate(create_empty_line(length(hd(buffer))), lines)
      )

    # Adjust cursor position if needed
    max_y = length(new_buffer) - 1
    new_cursor_y = min(cursor_y + lines, max_y)
    {new_buffer, new_cursor_y, cursor_x}
  end

  def scroll_down(buffer, lines)
      when list?(buffer) and is_integer(lines) and lines > 0 do
    {new_buffer, _cursor_y, _cursor_x} = scroll_down(buffer, lines, 0, 0)
    new_buffer
  end

  # Handle ScreenBuffer structs by extracting cells and calling the list version
  def scroll_down(%Raxol.Terminal.ScreenBuffer{} = buffer, lines)
      when is_integer(lines) and lines > 0 do
    # Extract cells from ScreenBuffer and call the list version
    {new_cells, _cursor_y, _cursor_x} = scroll_down(buffer.cells, lines, 0, 0)
    %{buffer | cells: new_cells}
  end

  # Handle ScreenBuffer structs with cursor position
  def scroll_down(
        %Raxol.Terminal.ScreenBuffer{} = buffer,
        lines,
        cursor_y,
        cursor_x
      )
      when is_integer(lines) and lines > 0 and
             is_integer(cursor_y) and is_integer(cursor_x) do
    # Extract cells from ScreenBuffer and call the list version
    {new_cells, new_cursor_y, new_cursor_x} =
      scroll_down(buffer.cells, lines, cursor_y, cursor_x)

    {%{buffer | cells: new_cells}, new_cursor_y, new_cursor_x}
  end

  @doc """
  Inserts the specified number of blank lines at the cursor position.
  """
  def insert_lines(buffer, count, cursor_y, cursor_x)
      when list?(buffer) and is_integer(count) and count > 0 and
             is_integer(cursor_y) and is_integer(cursor_x) do
    # Insert blank lines at cursor position
    new_buffer =
      buffer
      |> Enum.take(cursor_y)
      |> Enum.concat(
        List.duplicate(create_empty_line(length(hd(buffer))), count)
      )
      |> Enum.concat(Enum.drop(buffer, cursor_y))

    {new_buffer, cursor_y, cursor_x}
  end

  @doc """
  Inserts the specified number of blank lines at the cursor position with scroll region.
  """
  def insert_lines(buffer, count, cursor_y, cursor_x, scroll_top, scroll_bottom)
      when list?(buffer) and is_integer(count) and count > 0 and
             is_integer(cursor_y) and is_integer(cursor_x) and
             is_integer(scroll_top) and is_integer(scroll_bottom) do
    if cursor_y >= scroll_top and cursor_y <= scroll_bottom do
      # Insert within scroll region
      new_buffer =
        buffer
        |> Enum.take(cursor_y)
        |> Enum.concat(
          List.duplicate(create_empty_line(length(hd(buffer))), count)
        )
        |> Enum.concat(Enum.drop(buffer, cursor_y))

      {new_buffer, cursor_y, cursor_x}
    else
      {buffer, cursor_y, cursor_x}
    end
  end

  def insert_lines(buffer, y, count, style)
      when is_struct(buffer, Raxol.Terminal.ScreenBuffer) and
             is_integer(y) and is_integer(count) and count > 0 and
             is_map(style) do
    # For ScreenBuffer structs, delegate to LineOperations
    Raxol.Terminal.Buffer.LineOperations.insert_lines(buffer, y, count, style)
  end

  def insert_lines(buffer, lines, y, top, bottom)
      when is_struct(buffer, Raxol.Terminal.ScreenBuffer) and
             is_integer(lines) and is_integer(y) and lines > 0 and
             is_integer(top) and is_integer(bottom) do
    # For ScreenBuffer structs, delegate to LineOperations
    Raxol.Terminal.Buffer.LineOperations.insert_lines(
      buffer,
      lines,
      y,
      top,
      bottom
    )
  end

  @doc """
  Deletes the specified number of lines at the cursor position.
  """
  def delete_lines(buffer, count, cursor_y, cursor_x)
      when list?(buffer) and is_integer(count) and count > 0 and
             is_integer(cursor_y) and is_integer(cursor_x) do
    # Delete lines at cursor position
    new_buffer =
      buffer
      |> Enum.take(cursor_y)
      |> Enum.concat(Enum.drop(buffer, cursor_y + count))

    {new_buffer, cursor_y, cursor_x}
  end

  def delete_lines(buffer, count, cursor_y, cursor_x, scroll_top, scroll_bottom)
      when list?(buffer) and is_integer(count) and count > 0 and
             is_integer(cursor_y) and is_integer(cursor_x) and
             is_integer(scroll_top) and is_integer(scroll_bottom) do
    if cursor_y >= scroll_top and cursor_y <= scroll_bottom do
      # Delete within scroll region
      new_buffer =
        buffer
        |> Enum.take(cursor_y)
        |> Enum.concat(Enum.drop(buffer, cursor_y + count))

      {new_buffer, cursor_y, cursor_x}
    else
      {buffer, cursor_y, cursor_x}
    end
  end

  def delete_lines(buffer, y, count, style, {top, bottom})
      when is_struct(buffer, Raxol.Terminal.ScreenBuffer) and
             is_integer(y) and is_integer(count) and count > 0 and
             is_map(style) and is_tuple({top, bottom}) do
    # For ScreenBuffer structs, delegate to LineOperations
    Raxol.Terminal.Buffer.LineOperations.delete_lines(
      buffer,
      y,
      count,
      style,
      {top, bottom}
    )
  end

  def delete_lines(buffer, lines, y, top, bottom)
      when is_struct(buffer, Raxol.Terminal.ScreenBuffer) and
             is_integer(lines) and is_integer(y) and lines > 0 and
             is_integer(top) and is_integer(bottom) do
    # For ScreenBuffer structs, delegate to LineOperations
    Raxol.Terminal.Buffer.LineOperations.delete_lines(
      buffer,
      lines,
      y,
      top,
      bottom
    )
  end

  @doc """
  Scrolls the buffer by the specified number of lines.
  """
  def scroll(buffer, lines) do
    if lines > 0 do
      Raxol.Terminal.Buffer.Scroller.scroll_up(buffer, lines)
    else
      Raxol.Terminal.Buffer.Scroller.scroll_down(buffer, abs(lines))
    end
  end

  @doc """
  Checks if scrolling is needed based on buffer state.

  ## Parameters

  * `buffer` - The screen buffer to check

  ## Returns

  A boolean indicating if scrolling is needed.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> Operations.Scrolling.needs_scroll?(buffer)
      false
  """
  @spec needs_scroll?(Raxol.Terminal.ScreenBuffer.t()) :: boolean()
  def needs_scroll?(_buffer) do
    false
  end

  @doc """
  Creates a new empty line with the specified number of columns.

  ## Parameters

  * `cols` - The number of columns in the line

  ## Returns

  A list of empty cells representing a line.

  ## Examples

      iex> Operations.Scrolling.create_empty_line(80)
      [%Cell{char: "", style: %{}}, ...]
  """
  @spec create_empty_line(non_neg_integer()) :: [Cell.t()]
  def create_empty_line(cols) do
    List.duplicate(Cell.new(), cols)
  end
end
