defmodule Raxol.Terminal.ScreenBuffer do
  @moduledoc """
  Manages the terminal's screen buffer state (grid, scrollback, selection).
  This module serves as the main interface for terminal buffer operations,
  delegating specific operations to specialized modules in Raxol.Terminal.Buffer.*.

  ## Structure

  The buffer consists of:
  * A main grid of cells (the visible screen)
  * A scrollback buffer for history
  * Selection state
  * Scroll region settings
  * Dimensions (width and height)

  ## Operations

  The module delegates operations to specialized modules:
  * `Content` - Writing and content management
  * `ScrollRegion` - Scroll region and scrolling operations
  * `LineOperations` - Line manipulation
  * `CharEditor` - Character editing
  * `LineEditor` - Line editing
  * `Eraser` - Clearing operations
  * `Selection` - Text selection
  * `Scrollback` - History management
  * `Queries` - State querying
  * `Initializer` - Buffer creation and validation
  * `Cursor` - Cursor state management
  * `Charset` - Character set management
  * `Formatting` - Text formatting and styling
  """

  @behaviour Raxol.Terminal.ScreenBufferBehaviour
  import Raxol.Guards

  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.ANSI.TextFormatting

  alias Raxol.Terminal.Buffer.{
    Selection,
    Scrollback,
    Operations,
    LineEditor,
    CharEditor,
    Eraser,
    LineOperations,
    Initializer,
    Queries,
    Content,
    ScrollRegion,
    Cursor,
    Charset,
    Formatting
  }

  defstruct [
    :cells,
    :scrollback,
    :scrollback_limit,
    :selection,
    :scroll_region,
    :scroll_position,
    :width,
    :height,
    :damage_regions,
    :default_style,
    cursor_position: {0, 0}
  ]

  @type t :: %__MODULE__{
          cells: list(list(Cell.t())),
          scrollback: list(list(Cell.t())),
          scrollback_limit: non_neg_integer(),
          selection: {integer(), integer(), integer(), integer()} | nil,
          scroll_region: {integer(), integer()} | nil,
          scroll_position: non_neg_integer(),
          width: non_neg_integer(),
          height: non_neg_integer(),
          cursor_position: {non_neg_integer(), non_neg_integer()},
          damage_regions: [
            {non_neg_integer(), non_neg_integer(), non_neg_integer(),
             non_neg_integer()}
          ],
          default_style: TextFormatting.text_style()
        }

  # === Core Operations ===

  defdelegate new(width, height, scrollback_limit \\ 1000), to: Initializer

  def resize(buffer, new_width, new_height) do
    # Create a new ScreenBuffer with the new dimensions
    default_cell = %Raxol.Terminal.Cell{
      char: " ",
      style: nil,
      dirty: nil,
      wide_placeholder: false
    }

    # Create new cells array with the new dimensions
    new_cells =
      List.duplicate(List.duplicate(default_cell, new_width), new_height)

    # Copy existing content, truncating or padding as needed
    new_cells =
      Enum.reduce(0..min(buffer.height - 1, new_height - 1), new_cells, fn row,
                                                                           acc ->
        Enum.reduce(0..min(buffer.width - 1, new_width - 1), acc, fn col,
                                                                     row_acc ->
          existing_cell =
            Enum.at(Enum.at(buffer.cells, row, []), col) || default_cell

          List.replace_at(
            row_acc,
            row,
            List.replace_at(Enum.at(row_acc, row), col, existing_cell)
          )
        end)
      end)

    %{buffer | width: new_width, height: new_height, cells: new_cells}
  end

  # === Content Operations ===

  def write_char(buffer, x, y, char) do
    write_char(buffer, x, y, char, buffer.default_style)
  end

  defdelegate write_char(buffer, x, y, char, style), to: Content

  def write_string(buffer, x, y, string),
    do: write_string(buffer, x, y, string, nil)

  defdelegate write_string(buffer, x, y, string, style), to: Content

  defdelegate get_char(buffer, x, y), to: Content
  defdelegate get_cell(buffer, x, y), to: Content
  defdelegate get_content(buffer), to: Content
  defdelegate put_line(buffer, line, y), to: Content

  # === Eraser Operations ===

  defdelegate clear_line(buffer, line, style \\ nil), to: Eraser
  defdelegate erase_chars(buffer, count), to: Eraser
  defdelegate erase_display(buffer, mode), to: Eraser
  defdelegate erase_line(buffer, mode), to: Eraser

  # === Line Operations ===

  defdelegate insert_lines(buffer, count), to: LineOperations
  defdelegate delete_lines(buffer, count), to: LineOperations
  defdelegate insert_chars(buffer, count), to: LineOperations
  defdelegate delete_chars(buffer, count), to: LineOperations
  defdelegate prepend_lines(buffer, lines), to: LineOperations

  # === Scroll Operations ===

  def scroll_up(buffer, lines) do
    Raxol.Terminal.Commands.Scrolling.scroll_up(
      buffer,
      lines,
      buffer.scroll_region,
      %{}
    )
  end

  def scroll_down(buffer, lines) do
    Raxol.Terminal.Commands.Scrolling.scroll_down(
      buffer,
      lines,
      buffer.scroll_region,
      %{}
    )
  end

  # Additional scroll functions for ScrollOperations
  def scroll_up(buffer, top, bottom, lines) do
    Raxol.Terminal.Commands.Scrolling.scroll_up(
      buffer,
      lines,
      {top, bottom},
      %{}
    )
  end

  def scroll_down(buffer, top, bottom, lines) do
    Raxol.Terminal.Commands.Scrolling.scroll_down(
      buffer,
      lines,
      {top, bottom},
      %{}
    )
  end

  def scroll_to(buffer, top, bottom, line) do
    ScrollRegion.scroll_to(buffer, top, bottom, line)
  end

  def reset_scroll_region(buffer) do
    Raxol.Terminal.Buffer.ScrollRegion.clear(buffer)
  end

  defdelegate get_scroll_top(buffer), to: ScrollRegion
  defdelegate get_scroll_bottom(buffer), to: ScrollRegion

  def set_scroll_region(buffer, {top, bottom}) do
    Raxol.Terminal.Buffer.ScrollRegion.set_region(buffer, top, bottom)
  end

  @doc """
  Sets the scroll region with individual top and bottom parameters.
  """
  def set_scroll_region(buffer, top, bottom)
      when integer?(top) and integer?(bottom) do
    Raxol.Terminal.Buffer.ScrollRegion.set_region(buffer, top, bottom)
  end

  # === Dimension Operations ===

  def get_dimensions(buffer) do
    {buffer.width, buffer.height}
  end

  def get_width(buffer) do
    buffer.width
  end

  def get_height(buffer) do
    buffer.height
  end

  # === Cursor Operations ===

  defdelegate set_cursor_position(buffer, x, y), to: Cursor
  defdelegate get_cursor_position(buffer), to: Cursor

  defdelegate set_cursor_visibility(buffer, visible),
    to: Cursor,
    as: :set_visibility

  defdelegate cursor_visible?(buffer), to: Cursor, as: :visible?
  defdelegate set_cursor_style(buffer, style), to: Cursor, as: :set_style
  defdelegate get_cursor_style(buffer), to: Cursor, as: :get_style
  defdelegate set_cursor_blink(buffer, blink), to: Cursor, as: :set_blink
  defdelegate cursor_blinking?(buffer), to: Cursor, as: :blinking?

  # === Charset Operations ===

  defdelegate designate_charset(buffer, slot, charset),
    to: Charset,
    as: :designate

  defdelegate get_designated_charset(buffer, slot),
    to: Charset,
    as: :get_designated

  defdelegate invoke_g_set(buffer, slot), to: Charset
  defdelegate get_current_g_set(buffer), to: Charset
  defdelegate apply_single_shift(buffer, slot), to: Charset
  defdelegate get_single_shift(buffer), to: Charset
  defdelegate reset_charset_state(buffer), to: Charset, as: :reset

  # === Formatting Operations ===

  defdelegate get_style(buffer), to: Formatting
  defdelegate update_style(buffer, style), to: Formatting
  defdelegate set_attribute(buffer, attribute), to: Formatting
  defdelegate reset_attribute(buffer, attribute), to: Formatting
  defdelegate set_foreground(buffer, color), to: Formatting
  defdelegate set_background(buffer, color), to: Formatting
  defdelegate reset_all_attributes(buffer), to: Formatting, as: :reset_all
  defdelegate get_foreground(buffer), to: Formatting
  defdelegate get_background(buffer), to: Formatting
  defdelegate attribute_set?(buffer, attribute), to: Formatting
  defdelegate get_set_attributes(buffer), to: Formatting

  # === Selection Operations ===

  defdelegate start_selection(buffer, x, y), to: Selection, as: :start
  defdelegate update_selection(buffer, x, y), to: Selection, as: :update
  defdelegate get_selection(buffer), to: Selection, as: :get_text
  defdelegate in_selection?(buffer, x, y), to: Selection, as: :contains?

  defdelegate get_selection_boundaries(buffer),
    to: Selection,
    as: :get_boundaries

  defdelegate get_text_in_region(buffer, start_x, start_y, end_x, end_y),
    to: Selection

  defdelegate clear_selection(buffer), to: Selection, as: :clear
  defdelegate selection_active?(buffer), to: Selection, as: :active?

  defdelegate get_selection_start(buffer),
    to: Selection,
    as: :get_start_position

  defdelegate get_selection_end(buffer), to: Selection, as: :get_end_position

  # === Scroll Region Operations ===

  defdelegate clear_scroll_region(buffer), to: ScrollRegion, as: :clear

  defdelegate get_scroll_region_boundaries(buffer),
    to: ScrollRegion,
    as: :get_boundaries

  # === Query Operations ===

  defdelegate get_line(buffer, line_index), to: Queries
  defdelegate get_cell_at(buffer, x, y), to: Queries
  defdelegate empty?(buffer), to: Queries

  # === Scrollback Operations ===

  defdelegate get_scroll_position(buffer), to: ScrollRegion

  # === Cleanup ===

  def cleanup(_buffer), do: :ok

  # Higher-arity insert_lines for command handlers
  @doc """
  Inserts blank lines at a specific position with style.
  """
  def insert_lines(buffer, y, count, style) do
    Raxol.Terminal.Buffer.Operations.insert_lines(buffer, y, count, style)
  end

  # Higher-arity insert_lines for region
  @doc """
  Inserts blank lines at a specific position within a region.
  """
  def insert_lines(buffer, lines, y, top, bottom) do
    Raxol.Terminal.Buffer.Operations.insert_lines(buffer, lines, y, top, bottom)
  end

  # Higher-arity delete_lines for command handlers
  @doc """
  Deletes lines at a specific position.

  ## Parameters
  - For command handlers: y, count, style, and region boundaries
  - For region operations: lines, y, top, and bottom positions
  """
  def delete_lines(buffer, y, count, style, {top, bottom}) do
    Raxol.Terminal.Buffer.Operations.delete_lines(
      buffer,
      y,
      count,
      style,
      {top, bottom}
    )
  end

  # Higher-arity delete_lines for region
  def delete_lines(buffer, lines, y, top, bottom) do
    Raxol.Terminal.Buffer.Operations.delete_lines(buffer, lines, y, top, bottom)
  end

  # === Screen Operations ===

  def clear(buffer, style \\ nil)

  def clear(buffer, style),
    do: Raxol.Terminal.ScreenBuffer.Core.clear(buffer, style)

  def erase_from_cursor_to_end(buffer, x, y, top, bottom) do
    # Clear from cursor to end of line
    line = Enum.at(buffer.cells, y, [])

    cleared_line =
      List.duplicate(%{}, x) ++ List.duplicate(%{}, buffer.width - x)

    new_cells = List.replace_at(buffer.cells, y, cleared_line)

    # Clear remaining lines
    new_cells =
      Enum.reduce((y + 1)..(bottom - 1), new_cells, fn line_num, acc ->
        List.replace_at(acc, line_num, List.duplicate(%{}, buffer.width))
      end)

    %{buffer | cells: new_cells}
  end

  def erase_from_start_to_cursor(buffer, x, y, top, bottom) do
    # Clear from start of line to cursor
    line = Enum.at(buffer.cells, y, [])
    cleared_line = List.duplicate(%{}, x + 1) ++ Enum.drop(line, x + 1)
    new_cells = List.replace_at(buffer.cells, y, cleared_line)

    # Clear previous lines
    new_cells =
      Enum.reduce(top..(y - 1), new_cells, fn line_num, acc ->
        List.replace_at(acc, line_num, List.duplicate(%{}, buffer.width))
      end)

    %{buffer | cells: new_cells}
  end

  def erase_all(buffer) do
    %{
      buffer
      | cells: List.duplicate(List.duplicate(%{}, buffer.width), buffer.height),
        scrollback: []
    }
  end

  defdelegate clear_region(buffer, x, y, width, height),
    to: Raxol.Terminal.ScreenBuffer.Core

  defdelegate mark_damaged(buffer, x, y, width, height, reason),
    to: Raxol.Terminal.ScreenBuffer.Core

  defdelegate pop_bottom_lines(buffer, count),
    to: Raxol.Terminal.ScreenBuffer.Core

  def erase_display(buffer, mode, cursor, min_row, max_row) do
    Raxol.Terminal.ScreenBuffer.Core.erase_display(
      buffer,
      mode,
      cursor,
      min_row,
      max_row
    )
  end

  def erase_line(buffer, mode, cursor, min_col, max_col) do
    Raxol.Terminal.ScreenBuffer.Core.erase_line(
      buffer,
      mode,
      cursor,
      min_col,
      max_col
    )
  end

  def delete_chars(buffer, count, cursor, max_col) do
    Raxol.Terminal.ScreenBuffer.Core.delete_chars(
      buffer,
      count,
      cursor,
      max_col
    )
  end

  def insert_chars(buffer, count, cursor, max_col) do
    Raxol.Terminal.ScreenBuffer.Core.insert_chars(
      buffer,
      count,
      cursor,
      max_col
    )
  end

  def get_char(buffer, x, y) do
    Raxol.Terminal.ScreenBuffer.Core.get_char(buffer, x, y)
  end

  def write_char(buffer, x, y, char, style \\ nil) do
    Raxol.Terminal.ScreenBuffer.Core.write_char(buffer, x, y, char, style)
  end

  def insert_lines(buffer, count) do
    Raxol.Terminal.ScreenBuffer.Core.insert_lines(buffer, count)
  end

  def delete_lines(buffer, count) do
    Raxol.Terminal.ScreenBuffer.Core.delete_lines(buffer, count)
  end

  def get_dimensions(buffer) do
    Raxol.Terminal.ScreenBuffer.Core.get_dimensions(buffer)
  end

  def set_dimensions(buffer, width, height) do
    Raxol.Terminal.ScreenBuffer.Core.set_dimensions(buffer, width, height)
  end

  def get_scrollback(buffer) do
    Raxol.Terminal.ScreenBuffer.Core.get_scrollback(buffer)
  end

  def set_scrollback(buffer, scrollback) do
    Raxol.Terminal.ScreenBuffer.Core.set_scrollback(buffer, scrollback)
  end

  def get_damaged_regions(buffer) do
    Raxol.Terminal.ScreenBuffer.Core.get_damaged_regions(buffer)
  end

  def clear_damaged_regions(buffer) do
    Raxol.Terminal.ScreenBuffer.Core.clear_damaged_regions(buffer)
  end

  def mark_damaged(buffer, x, y, width, height, reason) do
    Raxol.Terminal.ScreenBuffer.Core.mark_damaged(
      buffer,
      x,
      y,
      width,
      height,
      reason
    )
  end

  def get_scroll_region(buffer) do
    Raxol.Terminal.Buffer.ScrollRegion.get_region(buffer)
  end

  def get_scroll_position(buffer) do
    ScrollRegion.get_scroll_position(buffer)
  end

  defdelegate shift_region_to_line(buffer, region, target_line),
    to: ScrollRegion

  @doc """
  Gets the estimated memory usage of the screen buffer.
  """
  @spec get_memory_usage(t()) :: non_neg_integer()
  def get_memory_usage(%__MODULE__{} = buffer) do
    # Calculate memory usage for main cells grid
    cells_usage = calculate_cells_memory_usage(buffer.cells)

    # Calculate memory usage for scrollback
    scrollback_usage = calculate_cells_memory_usage(buffer.scrollback)

    # Calculate memory usage for other components
    # 4 integers * 8 bytes
    selection_usage = if buffer.selection, do: 32, else: 0
    # 2 integers * 8 bytes
    scroll_region_usage = if buffer.scroll_region, do: 16, else: 0
    # 4 integers * 8 bytes per region
    damage_regions_usage = length(buffer.damage_regions) * 32

    # Base struct overhead and other fields
    # Rough estimate for struct overhead and other fields
    base_usage = 256

    cells_usage + scrollback_usage + selection_usage + scroll_region_usage +
      damage_regions_usage + base_usage
  end

  # Private helper to calculate memory usage for a grid of cells
  defp calculate_cells_memory_usage(cells) when list?(cells) do
    total_cells =
      Enum.reduce(cells, 0, fn row, acc ->
        acc + length(row)
      end)

    # Rough estimate: each cell is about 64 bytes (including overhead)
    total_cells * 64
  end

  defp calculate_cells_memory_usage(_), do: 0

  @doc """
  Erases part or all of the current line based on the cursor position and type.
  Type can be :to_end, :to_beginning, or :all.
  """
  @spec erase_in_line(t(), {non_neg_integer(), non_neg_integer()}, atom()) ::
          t()
  def erase_in_line(buffer, {x, y}, type) do
    case type do
      :to_end -> erase_line_to_end(buffer, x, y)
      :to_beginning -> erase_line_to_beginning(buffer, x, y)
      :all -> erase_entire_line(buffer, y)
      _ -> erase_line_to_end(buffer, x, y)
    end
  end

  defp erase_line_to_end(buffer, x, y) do
    line = Enum.at(buffer.cells, y, [])

    cleared_line =
      List.duplicate(%{}, x) ++ List.duplicate(%{}, buffer.width - x)

    new_cells = List.replace_at(buffer.cells, y, cleared_line)
    %{buffer | cells: new_cells}
  end

  defp erase_line_to_beginning(buffer, x, y) do
    line = Enum.at(buffer.cells, y, [])
    cleared_line = List.duplicate(%{}, x + 1) ++ Enum.drop(line, x + 1)
    new_cells = List.replace_at(buffer.cells, y, cleared_line)
    %{buffer | cells: new_cells}
  end

  defp erase_entire_line(buffer, y) do
    new_cells =
      List.replace_at(buffer.cells, y, List.duplicate(%{}, buffer.width))

    %{buffer | cells: new_cells}
  end

  @doc """
  Erases part or all of the display based on the cursor position and type.
  Type can be :to_end, :to_beginning, or :all.
  """
  @spec erase_in_display(t(), {non_neg_integer(), non_neg_integer()}, atom()) ::
          t()
  def erase_in_display(buffer, {x, y}, type) do
    case type do
      :to_end ->
        # Erase from cursor to end of display
        erase_from_cursor_to_end(buffer, x, y, 0, buffer.height)

      :to_beginning ->
        # Erase from start of display to cursor
        erase_from_start_to_cursor(buffer, x, y, 0, buffer.height)

      :all ->
        # Erase entire display
        erase_all(buffer)

      _ ->
        # Default to :to_end
        erase_in_display(buffer, {x, y}, :to_end)
    end
  end

  @doc """
  Erases from the cursor to the end of the screen using the current cursor position.
  """
  @spec erase_from_cursor_to_end(t()) :: t()
  def erase_from_cursor_to_end(buffer) do
    {x, y} = buffer.cursor_position || {0, 0}
    height = buffer.height || 24
    erase_from_cursor_to_end(buffer, x, y, 0, height)
  end

  # Higher-arity delete_characters for command handlers
  @doc """
  Deletes a specified number of characters starting from the given position in the buffer.
  Delegates to CharEditor.delete_characters/5.
  """
  def delete_characters(buffer, row, col, count, default_style) do
    CharEditor.delete_characters(buffer, row, col, count, default_style)
  end

  @doc """
  Scrolls the buffer down by the specified number of lines with additional parameters.
  """
  def scroll_down(buffer, lines, count)
      when integer?(lines) and integer?(count) do
    Raxol.Terminal.Commands.Scrolling.scroll_down(
      buffer,
      lines,
      buffer.scroll_region,
      %{}
    )
  end
end
