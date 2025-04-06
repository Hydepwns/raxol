defmodule Raxol.Terminal.ScreenBuffer do
  @moduledoc """
  Manages the terminal's screen buffer, including operations for resizing, scrolling, and selection handling.
  """

  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.CharacterHandling

  defstruct [:cells, :scrollback, :scrollback_limit, :selection, :scroll_region, :width, :height]

  @type t :: %__MODULE__{
    cells: list(list(Cell.t())),
    scrollback: list(list(Cell.t())),
    scrollback_limit: non_neg_integer(),
    selection: {integer(), integer(), integer(), integer()} | nil,
    scroll_region: {integer(), integer()} | nil,
    width: non_neg_integer(),
    height: non_neg_integer()
  }

  @doc """
  Creates a new screen buffer with the specified dimensions.
  """
  @spec new(non_neg_integer(), non_neg_integer(), non_neg_integer()) :: t()
  def new(width, height, scrollback_limit \\ 1000) do
    %__MODULE__{
      cells: List.duplicate(List.duplicate(Cell.new(), width), height),
      scrollback: [],
      scrollback_limit: scrollback_limit,
      selection: nil,
      scroll_region: nil,
      width: width,
      height: height
    }
  end

  @doc """
  Writes a character to the buffer at the specified position.
  Handles wide characters by taking up two cells when necessary.
  """
  @spec write_char(t(), non_neg_integer(), non_neg_integer(), char()) :: t()
  def write_char(%__MODULE__{} = buffer, x, y, char) when x >= 0 and y >= 0 do
    if y < buffer.height and x < buffer.width do
      width = CharacterHandling.get_char_width(char)
      cells = List.update_at(buffer.cells, y, fn row ->
        if width == 2 and x + 1 < buffer.width do
          # For wide characters, we need to ensure the next cell is empty
          row
          |> List.update_at(x, fn _ -> Cell.new(char) end)
          |> List.update_at(x + 1, fn _ -> Cell.new(" ") end)
        else
          List.update_at(row, x, fn _ -> Cell.new(char) end)
        end
      end)

      %{buffer | cells: cells}
    else
      buffer
    end
  end

  @doc """
  Writes a string to the buffer at the specified position.
  Handles wide characters and bidirectional text.
  """
  @spec write_string(t(), non_neg_integer(), non_neg_integer(), String.t()) :: t()
  def write_string(%__MODULE__{} = buffer, x, y, string) when x >= 0 and y >= 0 do
    segments = CharacterHandling.process_bidi_text(string)
    Enum.reduce(segments, {buffer, x}, fn {_type, segment}, {acc_buffer, acc_x} ->
      {new_buffer, new_x} = write_segment(acc_buffer, acc_x, y, segment)
      {new_buffer, new_x}
    end)
    |> elem(0)
  end

  defp write_segment(buffer, x, y, segment) do
    Enum.reduce(String.graphemes(segment), {buffer, x}, fn char, {acc_buffer, acc_x} ->
      width = CharacterHandling.get_char_width(char)
      if acc_x + width <= acc_buffer.width do
        {write_char(acc_buffer, acc_x, y, char), acc_x + width}
      else
        {acc_buffer, acc_x}
      end
    end)
  end

  @doc """
  Scrolls the buffer up by the specified number of lines.
  """
  @spec scroll_up(t(), non_neg_integer()) :: t()
  def scroll_up(%__MODULE__{} = buffer, lines) when lines > 0 do
    {scroll_start, scroll_end} = get_scroll_region_boundaries(buffer)
    visible_lines = scroll_end - scroll_start + 1

    if lines >= visible_lines do
      # If scrolling more than the visible region, clear it
      new_cells = List.update_slice(buffer.cells, scroll_start, visible_lines,
        List.duplicate(List.duplicate(Cell.new(), buffer.width), visible_lines))
      %{buffer | cells: new_cells}
    else
      # Get the lines within the scroll region
      scroll_region_lines = Enum.slice(buffer.cells, scroll_start..scroll_end)
      # Split into scrolled and remaining lines
      {scrolled_lines, remaining_lines} = Enum.split(scroll_region_lines, lines)

      # Add scrolled lines to scrollback buffer
      new_scrollback = (scrolled_lines ++ buffer.scrollback)
        |> Enum.take(buffer.scrollback_limit)

      # Create new empty lines for the bottom
      empty_lines = List.duplicate(List.duplicate(Cell.new(), buffer.width), lines)

      # Construct the new cells array by replacing the scroll region
      new_cells = List.update_slice(buffer.cells, scroll_start, visible_lines,
        remaining_lines ++ empty_lines)

      %{buffer | cells: new_cells, scrollback: new_scrollback}
    end
  end

  @doc """
  Scrolls the buffer down by the specified number of lines.
  """
  @spec scroll_down(t(), non_neg_integer()) :: t()
  def scroll_down(%__MODULE__{} = buffer, lines) when lines > 0 do
    {scroll_start, scroll_end} = get_scroll_region_boundaries(buffer)
    visible_lines = scroll_end - scroll_start + 1

    if lines >= visible_lines do
      # If scrolling more than the visible region, clear it
      new_cells = List.update_slice(buffer.cells, scroll_start, visible_lines,
        List.duplicate(List.duplicate(Cell.new(), buffer.width), visible_lines))
      %{buffer | cells: new_cells}
    else
      if length(buffer.scrollback) >= lines do
        # Get lines from scrollback
        {scroll_lines, new_scrollback} = Enum.split(buffer.scrollback, lines)

        # Get the lines within the scroll region
        scroll_region_lines = Enum.slice(buffer.cells, scroll_start..scroll_end)
        # Drop lines from the bottom
        shifted_lines = Enum.drop(scroll_region_lines, -lines)

        # Construct the new cells array by replacing the scroll region
        new_cells = List.update_slice(buffer.cells, scroll_start, visible_lines,
          scroll_lines ++ shifted_lines)

        %{buffer | cells: new_cells, scrollback: new_scrollback}
      else
        buffer
      end
    end
  end

  @doc """
  Sets a scroll region in the buffer.
  """
  @spec set_scroll_region(t(), non_neg_integer(), non_neg_integer()) :: t()
  def set_scroll_region(%__MODULE__{} = buffer, start_line, end_line)
      when start_line >= 0 and end_line >= start_line do
    %{buffer | scroll_region: {start_line, end_line}}
  end

  @doc """
  Clears the scroll region.
  """
  @spec clear_scroll_region(t()) :: t()
  def clear_scroll_region(%__MODULE__{} = buffer) do
    %{buffer | scroll_region: nil}
  end

  @doc """
  Gets the current scroll position.
  """
  @spec get_scroll_position(t()) :: non_neg_integer()
  def get_scroll_position(%__MODULE__{} = buffer) do
    length(buffer.scrollback)
  end

  @doc """
  Gets the boundaries of the current scroll region.
  """
  @spec get_scroll_region_boundaries(t()) :: {non_neg_integer(), non_neg_integer()}
  def get_scroll_region_boundaries(%__MODULE__{} = buffer) do
    case buffer.scroll_region do
      {start, ending} -> {start, ending}
      nil -> {0, buffer.height - 1}
    end
  end

  @doc """
  Starts a selection at the specified coordinates.
  """
  @spec start_selection(t(), non_neg_integer(), non_neg_integer()) :: t()
  def start_selection(%__MODULE__{} = buffer, x, y) when x >= 0 and y >= 0 do
    %{buffer | selection: {x, y, x, y}}
  end

  @doc """
  Updates the endpoint of the current selection.
  """
  @spec update_selection(t(), non_neg_integer(), non_neg_integer()) :: t()
  def update_selection(%__MODULE__{} = buffer, x, y) when x >= 0 and y >= 0 do
    case buffer.selection do
      {start_x, start_y, _end_x, _end_y} ->
        %{buffer | selection: {start_x, start_y, x, y}}
      nil ->
        buffer
    end
  end

  @doc """
  Gets the text within the current selection.
  """
  @spec get_selection(t()) :: String.t()
  def get_selection(%__MODULE__{} = buffer) do
    case buffer.selection do
      {start_x, start_y, end_x, end_y} ->
        get_text_in_region(buffer, start_x, start_y, end_x, end_y)
      nil ->
        ""
    end
  end

  @doc """
  Checks if a position is within the current selection.
  """
  @spec is_in_selection?(t(), non_neg_integer(), non_neg_integer()) :: boolean()
  def is_in_selection?(%__MODULE__{} = buffer, x, y) do
    case buffer.selection do
      {start_x, start_y, end_x, end_y} ->
        min_x = min(start_x, end_x)
        max_x = max(start_x, end_x)
        min_y = min(start_y, end_y)
        max_y = max(start_y, end_y)
        x >= min_x and x <= max_x and y >= min_y and y <= max_y
      nil ->
        false
    end
  end

  @doc """
  Gets the boundaries of the current selection.
  """
  @spec get_selection_boundaries(t()) :: {non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()} | nil
  def get_selection_boundaries(%__MODULE__{} = buffer) do
    buffer.selection
  end

  @doc """
  Gets the text within a specified region of the buffer.
  """
  @spec get_text_in_region(t(), non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()) :: String.t()
  def get_text_in_region(%__MODULE__{} = buffer, start_x, start_y, end_x, end_y) do
    min_x = min(start_x, end_x)
    max_x = max(start_x, end_x)
    min_y = min(start_y, end_y)
    max_y = max(start_y, end_y)

    buffer.cells
    |> Enum.slice(min_y..max_y)
    |> Enum.map(fn row ->
      row
      |> Enum.slice(min_x..max_x)
      |> Enum.map(&Cell.get_char/1)
      |> Enum.join("")
    end)
    |> Enum.join("\n")
  end

  @doc """
  Resizes the screen buffer to the specified dimensions.
  Handles content preservation and truncation based on the new size.
  """
  @spec resize(t(), non_neg_integer(), non_neg_integer()) :: t()
  def resize(%__MODULE__{} = buffer, new_width, new_height) when new_width > 0 and new_height > 0 do
    # Create a new buffer with the new dimensions
    new_buffer = %{buffer |
      width: new_width,
      height: new_height,
      cells: List.duplicate(List.duplicate(Cell.new(), new_width), new_height)
    }

    # Copy content from the old buffer to the new buffer
    # Handle both expansion and shrinking
    old_cells = buffer.cells
    new_cells = Enum.with_index(new_buffer.cells)
      |> Enum.map(fn {row, y} ->
        if y < length(old_cells) do
          # Copy content from the old row
          old_row = Enum.at(old_cells, y)
          Enum.with_index(row)
            |> Enum.map(fn {cell, x} ->
              if x < length(old_row) do
                # Copy the cell from the old buffer
                Enum.at(old_row, x)
              else
                # Create a new empty cell for expanded width
                Cell.new()
              end
            end)
        else
          # Create a new empty row for expanded height
          row
        end
      end)

    # Update the buffer with the new cells
    %{new_buffer | cells: new_cells}
  end

  @doc """
  Gets the current width of the screen buffer.
  """
  @spec get_width(t()) :: non_neg_integer()
  def get_width(%__MODULE__{} = buffer) do
    buffer.width
  end

  @doc """
  Gets the current height of the screen buffer.
  """
  @spec get_height(t()) :: non_neg_integer()
  def get_height(%__MODULE__{} = buffer) do
    buffer.height
  end

  @doc """
  Gets the dimensions of the screen buffer.
  """
  @spec get_dimensions(t()) :: {non_neg_integer(), non_neg_integer()}
  def get_dimensions(%__MODULE__{} = buffer) do
    {buffer.width, buffer.height}
  end

  @doc """
  Gets the width of the screen buffer.
  """
  @spec width(t()) :: non_neg_integer()
  def width(%__MODULE__{width: width}), do: width

  @doc """
  Gets the height of the screen buffer.
  """
  @spec height(t()) :: non_neg_integer()
  def height(%__MODULE__{height: height}), do: height

  @doc """
  Clears a rectangular region of the buffer.
  """
  @spec clear_region(t(), non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()) :: t()
  def clear_region(%__MODULE__{} = buffer, start_x, start_y, end_x, end_y) do
    Enum.reduce(start_y..end_y, buffer, fn y, acc_buffer ->
      if y >= 0 and y < acc_buffer.height do
        row = Enum.at(acc_buffer.cells, y)
        new_row = Enum.reduce(start_x..end_x, row, fn x, acc_row ->
          if x >= 0 and x < acc_buffer.width do
            List.replace_at(acc_row, x, Cell.new())
          else
            acc_row
          end
        end)

        %{acc_buffer | cells: List.update_at(acc_buffer.cells, y, fn _ -> new_row end)}
      else
        acc_buffer
      end
    end)
  end
end
