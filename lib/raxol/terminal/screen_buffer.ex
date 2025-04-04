defmodule Raxol.Terminal.ScreenBuffer do
  @moduledoc """
  Terminal screen buffer management module.
  
  This module handles the management of the terminal screen buffer, including:
  - Buffer initialization and resizing
  - Character cell operations
  - Scrolling and viewport management
  - Buffer state persistence
  - History management
  - Selection handling
  """

  alias Raxol.Terminal.Cell

  @type t :: %__MODULE__{
    width: non_neg_integer(),
    height: non_neg_integer(),
    scrollback_height: non_neg_integer(),
    buffer: list(list(Cell.t())),
    scrollback: list(list(Cell.t())),
    cursor: {non_neg_integer(), non_neg_integer()},
    saved_cursor: {non_neg_integer(), non_neg_integer()} | nil,
    scroll_region: {non_neg_integer(), non_neg_integer()} | nil,
    selection: {non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()} | nil,
    attributes: map(),
    history: list(map()),
    history_index: non_neg_integer(),
    history_limit: non_neg_integer()
  }

  defstruct [
    :width,
    :height,
    :scrollback_height,
    :buffer,
    :scrollback,
    :cursor,
    :saved_cursor,
    :scroll_region,
    :selection,
    :attributes,
    :history,
    :history_index,
    :history_limit
  ]

  @doc """
  Creates a new screen buffer with the given dimensions.
  
  ## Examples
  
      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer.width
      80
      iex> buffer.height
      24
  """
  def new(width, height, scrollback_height \\ 1000) do
    %__MODULE__{
      width: width,
      height: height,
      scrollback_height: scrollback_height,
      buffer: create_empty_buffer(width, height),
      scrollback: [],
      cursor: {0, 0},
      saved_cursor: nil,
      scroll_region: nil,
      selection: nil,
      attributes: %{},
      history: [],
      history_index: 0,
      history_limit: 100
    }
  end

  @doc """
  Resizes the screen buffer to the given dimensions.
  
  ## Examples
  
      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.resize(buffer, 100, 30)
      iex> buffer.width
      100
      iex> buffer.height
      30
  """
  def resize(%__MODULE__{} = buffer, width, height) do
    new_buffer = create_empty_buffer(width, height)
    
    # Copy existing content, truncating if necessary
    new_buffer = Enum.with_index(buffer.buffer)
    |> Enum.reduce(new_buffer, fn {row, y}, acc ->
      if y < height do
        new_row = Enum.take(row, width)
        |> Enum.concat(List.duplicate(Cell.new(), width - length(new_row)))
        List.replace_at(acc, y, new_row)
      else
        acc
      end
    end)
    
    # Adjust cursor position if needed
    {cursor_x, cursor_y} = buffer.cursor
    new_cursor_x = min(cursor_x, width - 1)
    new_cursor_y = min(cursor_y, height - 1)
    
    %{buffer |
      width: width,
      height: height,
      buffer: new_buffer,
      cursor: {new_cursor_x, new_cursor_y}
    }
  end

  @doc """
  Writes a character at the current cursor position.
  
  ## Examples
  
      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.write_char(buffer, "A")
      iex> Cell.get_char(List.first(List.first(buffer.buffer)))
      "A"
  """
  def write_char(%__MODULE__{} = buffer, char) do
    {x, y} = buffer.cursor
    cell = Cell.new(char, buffer.attributes)
    
    new_buffer = buffer.buffer
    |> List.update_at(y, fn row ->
      List.replace_at(row, x, cell)
    end)
    
    %{buffer | buffer: new_buffer}
    |> move_cursor_right()
  end

  @doc """
  Moves the cursor to the specified position.
  
  ## Examples
  
      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.move_cursor(buffer, 10, 5)
      iex> buffer.cursor
      {10, 5}
  """
  def move_cursor(%__MODULE__{} = buffer, x, y) do
    x = max(0, min(x, buffer.width - 1))
    y = max(0, min(y, buffer.height - 1))
    
    %{buffer | cursor: {x, y}}
  end

  @doc """
  Moves the cursor right by the specified number of positions.
  
  ## Examples
  
      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.move_cursor_right(buffer, 5)
      iex> buffer.cursor
      {5, 0}
  """
  def move_cursor_right(%__MODULE__{} = buffer, n \\ 1) do
    {x, y} = buffer.cursor
    new_x = x + n
    
    if new_x >= buffer.width do
      %{buffer | cursor: {0, y + 1}}
      |> handle_line_wrap()
    else
      %{buffer | cursor: {new_x, y}}
    end
  end

  @doc """
  Moves the cursor left by the specified number of positions.
  
  ## Examples
  
      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.move_cursor(buffer, 10, 0)
      iex> buffer = ScreenBuffer.move_cursor_left(buffer, 5)
      iex> buffer.cursor
      {5, 0}
  """
  def move_cursor_left(%__MODULE__{} = buffer, n \\ 1) do
    {x, y} = buffer.cursor
    new_x = max(0, x - n)
    
    %{buffer | cursor: {new_x, y}}
  end

  @doc """
  Moves the cursor up by the specified number of positions.
  
  ## Examples
  
      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.move_cursor(buffer, 0, 5)
      iex> buffer = ScreenBuffer.move_cursor_up(buffer, 3)
      iex> buffer.cursor
      {0, 2}
  """
  def move_cursor_up(%__MODULE__{} = buffer, n \\ 1) do
    {x, y} = buffer.cursor
    new_y = max(0, y - n)
    
    %{buffer | cursor: {x, new_y}}
  end

  @doc """
  Moves the cursor down by the specified number of positions.
  
  ## Examples
  
      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.move_cursor_down(buffer, 5)
      iex> buffer.cursor
      {0, 5}
  """
  def move_cursor_down(%__MODULE__{} = buffer, n \\ 1) do
    {x, y} = buffer.cursor
    new_y = min(y + n, buffer.height - 1)
    
    %{buffer | cursor: {x, new_y}}
  end

  @doc """
  Saves the current cursor position.
  
  ## Examples
  
      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.move_cursor(buffer, 10, 5)
      iex> buffer = ScreenBuffer.save_cursor(buffer)
      iex> buffer.saved_cursor
      {10, 5}
  """
  def save_cursor(%__MODULE__{} = buffer) do
    %{buffer | saved_cursor: buffer.cursor}
  end

  @doc """
  Restores the saved cursor position.
  
  ## Examples
  
      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.move_cursor(buffer, 10, 5)
      iex> buffer = ScreenBuffer.save_cursor(buffer)
      iex> buffer = ScreenBuffer.move_cursor(buffer, 0, 0)
      iex> buffer = ScreenBuffer.restore_cursor(buffer)
      iex> buffer.cursor
      {10, 5}
  """
  def restore_cursor(%__MODULE__{} = buffer) do
    case buffer.saved_cursor do
      nil -> buffer
      pos -> %{buffer | cursor: pos}
    end
  end

  @doc """
  Clears the screen from the cursor to the end.
  
  ## Examples
  
      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.move_cursor(buffer, 10, 5)
      iex> buffer = ScreenBuffer.clear_screen(buffer, :from_cursor)
      iex> Enum.all?(Enum.flat_map(buffer.buffer, &(&1)), &Cell.is_empty?/1)
      false
  """
  def clear_screen(%__MODULE__{} = buffer, :from_cursor) do
    {x, y} = buffer.cursor
    
    new_buffer = buffer.buffer
    |> Enum.with_index()
    |> Enum.map(fn {row, row_y} ->
      cond do
        row_y < y -> row
        row_y == y -> clear_row_from_cursor(row, x)
        true -> List.duplicate(Cell.new(), buffer.width)
      end
    end)
    
    %{buffer | buffer: new_buffer}
  end

  @doc """
  Clears the screen from the beginning to the cursor.
  
  ## Examples
  
      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.move_cursor(buffer, 10, 5)
      iex> buffer = ScreenBuffer.clear_screen(buffer, :to_cursor)
      iex> Enum.all?(Enum.flat_map(buffer.buffer, &(&1)), &Cell.is_empty?/1)
      false
  """
  def clear_screen(%__MODULE__{} = buffer, :to_cursor) do
    {x, y} = buffer.cursor
    
    new_buffer = buffer.buffer
    |> Enum.with_index()
    |> Enum.map(fn {row, row_y} ->
      cond do
        row_y < y -> List.duplicate(Cell.new(), buffer.width)
        row_y == y -> clear_row_to_cursor(row, x)
        true -> row
      end
    end)
    
    %{buffer | buffer: new_buffer}
  end

  @doc """
  Clears the entire screen.
  
  ## Examples
  
      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.clear_screen(buffer, :all)
      iex> Enum.all?(Enum.flat_map(buffer.buffer, &(&1)), &Cell.is_empty?/1)
      true
  """
  def clear_screen(%__MODULE__{} = buffer, :all) do
    %{buffer | buffer: create_empty_buffer(buffer.width, buffer.height)}
  end

  @doc """
  Erases the current line from the cursor to the end.
  
  ## Examples
  
      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.move_cursor(buffer, 10, 5)
      iex> buffer = ScreenBuffer.erase_line(buffer, :from_cursor)
      iex> Enum.all?(Enum.at(buffer.buffer, 5), &Cell.is_empty?/1)
      false
  """
  def erase_line(%__MODULE__{} = buffer, :from_cursor) do
    {x, y} = buffer.cursor
    
    new_buffer = buffer.buffer
    |> List.update_at(y, fn row ->
      clear_row_from_cursor(row, x)
    end)
    
    %{buffer | buffer: new_buffer}
  end

  @doc """
  Erases the current line from the beginning to the cursor.
  
  ## Examples
  
      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.move_cursor(buffer, 10, 5)
      iex> buffer = ScreenBuffer.erase_line(buffer, :to_cursor)
      iex> Enum.all?(Enum.at(buffer.buffer, 5), &Cell.is_empty?/1)
      false
  """
  def erase_line(%__MODULE__{} = buffer, :to_cursor) do
    {x, y} = buffer.cursor
    
    new_buffer = buffer.buffer
    |> List.update_at(y, fn row ->
      clear_row_to_cursor(row, x)
    end)
    
    %{buffer | buffer: new_buffer}
  end

  @doc """
  Erases the entire current line.
  
  ## Examples
  
      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.move_cursor(buffer, 10, 5)
      iex> buffer = ScreenBuffer.erase_line(buffer, :all)
      iex> Enum.all?(Enum.at(buffer.buffer, 5), &Cell.is_empty?/1)
      true
  """
  def erase_line(%__MODULE__{} = buffer, :all) do
    {_, y} = buffer.cursor
    
    new_buffer = buffer.buffer
    |> List.update_at(y, fn _ ->
      List.duplicate(Cell.new(), buffer.width)
    end)
    
    %{buffer | buffer: new_buffer}
  end

  @doc """
  Inserts a line at the current cursor position.
  
  ## Examples
  
      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.move_cursor(buffer, 0, 5)
      iex> buffer = ScreenBuffer.insert_line(buffer, 1)
      iex> length(buffer.buffer)
      24
  """
  def insert_line(%__MODULE__{} = buffer, n \\ 1) do
    {_, y} = buffer.cursor
    
    new_buffer = buffer.buffer
    |> Enum.with_index()
    |> Enum.reduce(buffer.buffer, fn {row, row_y}, acc ->
      if row_y >= y do
        List.insert_at(acc, row_y, List.duplicate(Cell.new(), buffer.width))
      else
        acc
      end
    end)
    |> Enum.take(buffer.height)
    
    %{buffer | buffer: new_buffer}
  end

  @doc """
  Deletes a line at the current cursor position.
  
  ## Examples
  
      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.move_cursor(buffer, 0, 5)
      iex> buffer = ScreenBuffer.delete_line(buffer, 1)
      iex> length(buffer.buffer)
      24
  """
  def delete_line(%__MODULE__{} = buffer, n \\ 1) do
    {_, y} = buffer.cursor
    
    new_buffer = buffer.buffer
    |> Enum.with_index()
    |> Enum.reduce(buffer.buffer, fn {row, row_y}, acc ->
      if row_y >= y and row_y < y + n do
        List.delete_at(acc, row_y)
      else
        acc
      end
    end)
    |> Enum.concat(List.duplicate(List.duplicate(Cell.new(), buffer.width), n))
    |> Enum.take(buffer.height)
    
    %{buffer | buffer: new_buffer}
  end

  @doc """
  Sets the scroll region.
  
  ## Examples
  
      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.set_scroll_region(buffer, 5, 15)
      iex> buffer.scroll_region
      {5, 15}
  """
  def set_scroll_region(%__MODULE__{} = buffer, top, bottom) do
    %{buffer | scroll_region: {top, bottom}}
  end

  @doc """
  Scrolls the screen up by the specified number of lines.
  
  ## Examples
  
      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.scroll_up(buffer, 5)
      iex> length(buffer.scrollback)
      5
  """
  def scroll_up(%__MODULE__{} = buffer, n \\ 1) do
    {scrollback, new_buffer} = Enum.split(buffer.buffer, n)
    
    new_scrollback = (buffer.scrollback ++ scrollback)
    |> Enum.take(buffer.scrollback_height)
    
    new_buffer = new_buffer
    |> Enum.concat(List.duplicate(List.duplicate(Cell.new(), buffer.width), n))
    |> Enum.take(buffer.height)
    
    %{buffer |
      buffer: new_buffer,
      scrollback: new_scrollback
    }
  end

  @doc """
  Scrolls the screen down by the specified number of lines.
  
  ## Examples
  
      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.scroll_down(buffer, 5)
      iex> length(buffer.scrollback)
      0
  """
  def scroll_down(%__MODULE__{} = buffer, n \\ 1) do
    {new_scrollback, new_buffer} = Enum.split(buffer.scrollback, -n)
    
    new_buffer = new_buffer
    |> Enum.concat(List.duplicate(List.duplicate(Cell.new(), buffer.width), n))
    |> Enum.take(buffer.height)
    
    %{buffer |
      buffer: new_buffer,
      scrollback: new_scrollback
    }
  end

  @doc """
  Sets the selection region.
  
  ## Examples
  
      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.set_selection(buffer, 10, 5, 20, 10)
      iex> buffer.selection
      {10, 5, 20, 10}
  """
  def set_selection(%__MODULE__{} = buffer, start_x, start_y, end_x, end_y) do
    %{buffer | selection: {start_x, start_y, end_x, end_y}}
  end

  @doc """
  Clears the selection region.
  
  ## Examples
  
      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.set_selection(buffer, 10, 5, 20, 10)
      iex> buffer = ScreenBuffer.clear_selection(buffer)
      iex> buffer.selection
      nil
  """
  def clear_selection(%__MODULE__{} = buffer) do
    %{buffer | selection: nil}
  end

  @doc """
  Gets the selected text from the buffer.
  
  ## Examples
  
      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.write_char(buffer, "A")
      iex> buffer = ScreenBuffer.set_selection(buffer, 0, 0, 0, 0)
      iex> ScreenBuffer.get_selection(buffer)
      "A"
  """
  def get_selection(%__MODULE__{} = buffer) do
    case buffer.selection do
      nil -> ""
      {start_x, start_y, end_x, end_y} ->
        get_text_in_region(buffer, start_x, start_y, end_x, end_y)
    end
  end

  @doc """
  Saves the current buffer state to history.
  
  ## Examples
  
      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.save_history(buffer)
      iex> length(buffer.history)
      1
  """
  def save_history(%__MODULE__{} = buffer) do
    state = %{
      buffer: buffer.buffer,
      cursor: buffer.cursor,
      attributes: buffer.attributes
    }
    
    new_history = [state | buffer.history]
    |> Enum.take(buffer.history_limit)
    
    %{buffer |
      history: new_history,
      history_index: 0
    }
  end

  @doc """
  Restores a buffer state from history.
  
  ## Examples
  
      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.save_history(buffer)
      iex> buffer = ScreenBuffer.write_char(buffer, "A")
      iex> buffer = ScreenBuffer.restore_history(buffer)
      iex> Cell.get_char(List.first(List.first(buffer.buffer)))
      ""
  """
  def restore_history(%__MODULE__{} = buffer) do
    case Enum.at(buffer.history, buffer.history_index) do
      nil -> buffer
      state ->
        %{buffer |
          buffer: state.buffer,
          cursor: state.cursor,
          attributes: state.attributes
        }
    end
  end

  @doc """
  Gets the text content of the buffer.
  
  ## Examples
  
      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScreenBuffer.write_char(buffer, "A")
      iex> ScreenBuffer.get_text(buffer)
      "A"
  """
  def get_text(%__MODULE__{} = buffer) do
    buffer.buffer
    |> Enum.map(fn row ->
      row
      |> Enum.map(&Cell.get_char/1)
      |> Enum.join("")
    end)
    |> Enum.join("\n")
  end

  # Private functions

  defp create_empty_buffer(width, height) do
    List.duplicate(
      List.duplicate(Cell.new(), width),
      height
    )
  end

  defp clear_row_from_cursor(row, x) do
    Enum.with_index(row)
    |> Enum.map(fn {cell, i} ->
      if i >= x do
        Cell.new()
      else
        cell
      end
    end)
  end

  defp clear_row_to_cursor(row, x) do
    Enum.with_index(row)
    |> Enum.map(fn {cell, i} ->
      if i <= x do
        Cell.new()
      else
        cell
      end
    end)
  end

  defp handle_line_wrap(%__MODULE__{} = buffer) do
    {_, y} = buffer.cursor
    
    if y >= buffer.height do
      buffer
      |> scroll_up(1)
      |> Map.put(:cursor, {0, buffer.height - 1})
    else
      buffer
    end
  end

  defp get_text_in_region(buffer, start_x, start_y, end_x, end_y) do
    buffer.buffer
    |> Enum.with_index()
    |> Enum.filter(fn {_, y} -> y >= start_y and y <= end_y end)
    |> Enum.map(fn {row, y} ->
      row
      |> Enum.with_index()
      |> Enum.filter(fn {_, x} ->
        cond do
          y == start_y and y == end_y -> x >= start_x and x <= end_x
          y == start_y -> x >= start_x
          y == end_y -> x <= end_x
          true -> true
        end
      end)
      |> Enum.map(fn {cell, _} -> Cell.get_char(cell) end)
      |> Enum.join("")
    end)
    |> Enum.join("\n")
  end
end 