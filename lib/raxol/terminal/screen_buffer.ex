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
    :width,
    :height,
    :cursor_position,
    :damage_regions,
    :default_style
  ]

  @type t :: %__MODULE__{
          cells: list(list(Cell.t())),
          scrollback: list(list(Cell.t())),
          scrollback_limit: non_neg_integer(),
          selection: {integer(), integer(), integer(), integer()} | nil,
          scroll_region: {integer(), integer()} | nil,
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

  @impl true
  defdelegate new(width, height, scrollback_limit \\ 1000), to: Initializer

  @impl true
  defdelegate resize(buffer, new_width, new_height), to: Operations

  # === Content Operations ===

  @impl true
  def write_char(buffer, x, y, char) do
    write_char(buffer, x, y, char, buffer.default_style)
  end

  @impl true
  defdelegate write_char(buffer, x, y, char, style), to: Content

  @impl true
  def write_string(buffer, x, y, string),
    do: write_string(buffer, x, y, string, nil)

  @impl true
  defdelegate write_string(buffer, x, y, string, style), to: Content

  @impl true
  defdelegate get_char(buffer, x, y), to: Content
  @impl true
  defdelegate get_cell(buffer, x, y), to: Content
  @impl true
  defdelegate get_content(buffer), to: Content
  @impl true
  defdelegate put_line(buffer, line, y), to: Content

  # === Eraser Operations ===

  @impl true
  defdelegate clear_line(buffer, line, style \\ nil), to: Eraser
  @impl true
  defdelegate erase_chars(buffer, count), to: Eraser
  @impl true
  defdelegate erase_display(buffer, mode), to: Eraser
  @impl true
  defdelegate erase_line(buffer, mode), to: Eraser

  # === Line Operations ===

  @impl true
  defdelegate insert_lines(buffer, count), to: LineOperations
  @impl true
  defdelegate delete_lines(buffer, count), to: LineOperations
  @impl true
  defdelegate insert_chars(buffer, count), to: LineOperations
  @impl true
  defdelegate delete_chars(buffer, count), to: LineOperations
  @impl true
  defdelegate prepend_lines(buffer, lines), to: LineOperations

  # === Scroll Operations ===

  @impl true
  def scroll_up(buffer, lines) do
    Raxol.Terminal.Commands.Scrolling.scroll_up(
      buffer,
      lines,
      buffer.scroll_region,
      %{}
    )
  end

  @impl true
  def scroll_down(buffer, lines) do
    Raxol.Terminal.Commands.Scrolling.scroll_down(
      buffer,
      lines,
      buffer.scroll_region,
      %{}
    )
  end

  @impl true
  defdelegate get_scroll_top(buffer), to: ScrollRegion
  @impl true
  defdelegate get_scroll_bottom(buffer), to: ScrollRegion
  @impl true
  defdelegate get_scroll_region(buffer), to: ScrollRegion
  @impl true
  defdelegate set_scroll_region(buffer, region), to: ScrollRegion

  # === Dimension Operations ===

  @impl true
  def get_dimensions(buffer) do
    {buffer.width, buffer.height}
  end

  @impl true
  def get_width(buffer) do
    buffer.width
  end

  @impl true
  def get_height(buffer) do
    buffer.height
  end

  # === Cursor Operations ===

  @impl true
  defdelegate set_cursor_position(buffer, x, y), to: Cursor
  @impl true
  defdelegate get_cursor_position(buffer), to: Cursor
  @impl true
  defdelegate set_cursor_visibility(buffer, visible),
    to: Cursor,
    as: :set_visibility

  @impl true
  defdelegate is_cursor_visible?(buffer), to: Cursor, as: :is_visible?
  @impl true
  defdelegate set_cursor_style(buffer, style), to: Cursor, as: :set_style
  @impl true
  defdelegate get_cursor_style(buffer), to: Cursor, as: :get_style
  @impl true
  defdelegate set_cursor_blink(buffer, blink), to: Cursor, as: :set_blink
  @impl true
  defdelegate is_cursor_blinking?(buffer), to: Cursor, as: :is_blinking?

  # === Charset Operations ===

  @impl true
  defdelegate designate_charset(buffer, slot, charset),
    to: Charset,
    as: :designate

  @impl true
  defdelegate get_designated_charset(buffer, slot),
    to: Charset,
    as: :get_designated

  @impl true
  defdelegate invoke_g_set(buffer, slot), to: Charset
  @impl true
  defdelegate get_current_g_set(buffer), to: Charset
  @impl true
  defdelegate apply_single_shift(buffer, slot), to: Charset
  @impl true
  defdelegate get_single_shift(buffer), to: Charset
  @impl true
  defdelegate reset_charset_state(buffer), to: Charset, as: :reset

  # === Formatting Operations ===

  @impl true
  defdelegate get_style(buffer), to: Formatting
  @impl true
  defdelegate update_style(buffer, style), to: Formatting
  @impl true
  defdelegate set_attribute(buffer, attribute), to: Formatting
  @impl true
  defdelegate reset_attribute(buffer, attribute), to: Formatting
  @impl true
  defdelegate set_foreground(buffer, color), to: Formatting
  @impl true
  defdelegate set_background(buffer, color), to: Formatting
  @impl true
  defdelegate reset_all_attributes(buffer), to: Formatting, as: :reset_all
  @impl true
  defdelegate get_foreground(buffer), to: Formatting
  @impl true
  defdelegate get_background(buffer), to: Formatting
  @impl true
  defdelegate attribute_set?(buffer, attribute), to: Formatting
  @impl true
  defdelegate get_set_attributes(buffer), to: Formatting

  # === Selection Operations ===

  @impl true
  defdelegate start_selection(buffer, x, y), to: Selection, as: :start
  @impl true
  defdelegate update_selection(buffer, x, y), to: Selection, as: :update
  @impl true
  defdelegate get_selection(buffer), to: Selection, as: :get_text
  @impl true
  defdelegate in_selection?(buffer, x, y), to: Selection, as: :contains?
  @impl true
  defdelegate get_selection_boundaries(buffer),
    to: Selection,
    as: :get_boundaries

  @impl true
  defdelegate get_text_in_region(buffer, start_x, start_y, end_x, end_y),
    to: Selection

  @impl true
  defdelegate clear_selection(buffer), to: Selection, as: :clear
  @impl true
  defdelegate selection_active?(buffer), to: Selection, as: :active?
  @impl true
  defdelegate get_selection_start(buffer),
    to: Selection,
    as: :get_start_position

  @impl true
  defdelegate get_selection_end(buffer), to: Selection, as: :get_end_position

  # === Scroll Region Operations ===

  @impl true
  defdelegate clear_scroll_region(buffer), to: ScrollRegion, as: :clear
  @impl true
  defdelegate get_scroll_region_boundaries(buffer),
    to: ScrollRegion,
    as: :get_boundaries

  # === Query Operations ===

  @impl true
  defdelegate get_line(buffer, line_index), to: Queries
  @impl true
  defdelegate get_cell_at(buffer, x, y), to: Queries
  @impl true
  defdelegate is_empty?(buffer), to: Queries

  # === Scrollback Operations ===

  @impl true
  defdelegate get_scroll_position(buffer), to: Scrollback, as: :size

  # === Cleanup ===

  @impl true
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

  @impl true
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

  @impl true
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

  @impl true
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
end
