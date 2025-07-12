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
    cursor_position: {0, 0},
    alternate_screen: false,
    cursor_visible: false
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

  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate new(width, height, scrollback_limit \\ 1000), to: Initializer

  def resize(buffer, new_width, new_height) do
    # Validate input dimensions
    if new_width <= 0 or new_height <= 0 do
      raise ArgumentError,
            "ScreenBuffer dimensions must be positive integers, got: #{new_width}x#{new_height}"
    end

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
    # Handle case where buffer.cells might be nil or corrupted
    cells = buffer.cells || []

    new_cells =
      Enum.reduce(0..min(buffer.height - 1, new_height - 1), new_cells, fn row,
                                                                           acc ->
        row_data = Enum.at(cells, row, [])

        Enum.reduce(0..min(buffer.width - 1, new_width - 1), acc, fn col,
                                                                     row_acc ->
          existing_cell =
            Enum.at(row_data, col) || default_cell

          current_row =
            Enum.at(row_acc, row, List.duplicate(default_cell, new_width))

          updated_row = List.replace_at(current_row, col, existing_cell)

          List.replace_at(row_acc, row, updated_row)
        end)
      end)

    # Clear selection and scroll region after resize
    %{
      buffer
      | width: new_width,
        height: new_height,
        cells: new_cells,
        selection: nil,
        scroll_region: nil
    }
  end

  # === Content Operations ===

  def write_char(buffer, x, y, char) do
    write_char(buffer, x, y, char, buffer.default_style)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate write_char(buffer, x, y, char, style), to: Content

  def write_string(buffer, x, y, string),
    do: write_string(buffer, x, y, string, nil)

  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate write_string(buffer, x, y, string, style), to: Content

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_char(buffer, x, y) do
    Raxol.Terminal.ScreenBuffer.Core.get_char(buffer, x, y)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate get_cell(buffer, x, y), to: Content
  defdelegate get_content(buffer), to: Content
  defdelegate put_line(buffer, line, y), to: Content

  # === Eraser Operations ===

  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate clear_line(buffer, line, style \\ nil), to: Eraser
  defdelegate erase_chars(buffer, count), to: Eraser
  defdelegate erase_chars(buffer, x, y, count), to: Eraser
  defdelegate erase_display(buffer, mode), to: Eraser
  defdelegate erase_line(buffer, mode), to: Eraser
  defdelegate erase_line(buffer, line, mode), to: Eraser

  # === Line Operations ===

  defdelegate insert_lines(buffer, count), to: LineOperations
  defdelegate delete_lines(buffer, count), to: LineOperations

  defdelegate delete_lines_in_region(buffer, lines, y, top, bottom),
    to: LineOperations

  defdelegate insert_chars(buffer, count), to: LineOperations
  defdelegate delete_chars(buffer, count), to: LineOperations
  defdelegate prepend_lines(buffer, lines), to: LineOperations

  # === Scroll Operations ===

  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate scroll_up(buffer, lines), to: ScrollRegion

  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate scroll_down(buffer, lines), to: ScrollRegion

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
  @impl Raxol.Terminal.ScreenBufferBehaviour
  def set_scroll_region(buffer, top, bottom)
      when integer?(top) and integer?(bottom) do
    Raxol.Terminal.Buffer.ScrollRegion.set_region(buffer, top, bottom)
  end

  # === Dimension Operations ===

  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate get_dimensions(buffer), to: ScrollRegion

  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate get_width(buffer), to: ScrollRegion

  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate get_height(buffer), to: ScrollRegion

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

  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate designate_charset(buffer, slot, charset),
    to: Charset,
    as: :designate

  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate get_designated_charset(buffer, slot),
    to: Charset,
    as: :get_designated

  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate invoke_g_set(buffer, slot), to: Charset
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate get_current_g_set(buffer), to: Charset
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate apply_single_shift(buffer, slot), to: Charset
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate get_single_shift(buffer), to: Charset
  defdelegate reset_charset_state(buffer), to: Charset, as: :reset

  # === Formatting Operations ===

  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate get_style(buffer), to: Formatting
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate update_style(buffer, style), to: Formatting
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate set_attribute(buffer, attribute), to: Formatting
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate reset_attribute(buffer, attribute), to: Formatting
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate set_foreground(buffer, color), to: Formatting
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate set_background(buffer, color), to: Formatting
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate reset_all_attributes(buffer), to: Formatting, as: :reset_all
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate get_foreground(buffer), to: Formatting
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate get_background(buffer), to: Formatting
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate attribute_set?(buffer, attribute), to: Formatting
  @impl Raxol.Terminal.ScreenBufferBehaviour
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

  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate clear_scroll_region(buffer), to: ScrollRegion, as: :clear

  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate get_scroll_region_boundaries(buffer),
    to: ScrollRegion,
    as: :get_boundaries

  # === Query Operations ===

  defdelegate get_line(buffer, line_index), to: Queries
  defdelegate get_cell_at(buffer, x, y), to: Queries
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate empty?(buffer), to: Queries

  # === Scrollback Operations ===

  @impl Raxol.Terminal.ScreenBufferBehaviour
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

  def erase_from_cursor_to_end(buffer, x, y, _top, bottom) do
    # Clear from cursor to end of line
    line = Enum.at(buffer.cells, y, [])
    empty_cell = Raxol.Terminal.Cell.new()

    # Preserve existing cells before cursor, clear from cursor onwards
    preserved_cells = Enum.take(line, x)
    cleared_cells = List.duplicate(empty_cell, buffer.width - x)
    cleared_line = preserved_cells ++ cleared_cells

    new_cells = List.replace_at(buffer.cells, y, cleared_line)

    # Clear remaining lines
    new_cells =
      Enum.reduce((y + 1)..bottom, new_cells, fn line_num, acc ->
        List.replace_at(acc, line_num, List.duplicate(empty_cell, buffer.width))
      end)

    %{buffer | cells: new_cells}
  end

  def erase_from_start_to_cursor(buffer, x, y, top, bottom) do
    IO.puts(
      "DEBUG: erase_from_start_to_cursor called with x=#{x}, y=#{y}, top=#{top}, bottom=#{bottom}"
    )

    # Clear from start of line to cursor (inclusive)
    line = Enum.at(buffer.cells, y, [])
    empty_cell = Raxol.Terminal.Cell.new()
    # Clear from start of line to cursor position (inclusive)
    cleared_line = List.duplicate(empty_cell, x + 1) ++ Enum.drop(line, x + 1)
    new_cells = List.replace_at(buffer.cells, y, cleared_line)

    # Clear all previous lines completely
    IO.puts("DEBUG: Clearing lines from #{top} to #{y - 1}")

    new_cells =
      Enum.reduce(top..(y - 1), new_cells, fn line_num, acc ->
        IO.puts("DEBUG: Clearing line #{line_num}")
        List.replace_at(acc, line_num, List.duplicate(empty_cell, buffer.width))
      end)

    IO.puts("DEBUG: Final buffer has #{length(new_cells)} lines")
    %{buffer | cells: new_cells}
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def erase_all(buffer) do
    empty_cell = Raxol.Terminal.Cell.new()

    %{
      buffer
      | cells:
          List.duplicate(
            List.duplicate(empty_cell, buffer.width),
            buffer.height
          ),
        scrollback: []
    }
  end

  def clear_region(buffer, x, y, width, height) do
    # Clear the specified region by filling it with empty cells
    empty_cell = Raxol.Terminal.Cell.new()

    new_cells =
      Enum.reduce(y..(y + height - 1), buffer.cells, fn row_y, acc_cells ->
        clear_row_if_valid(acc_cells, row_y, x, width, buffer, empty_cell)
      end)

    %{buffer | cells: new_cells}
  end

  defp clear_row_if_valid(cells, row_y, x, width, buffer, empty_cell) do
    if row_y < buffer.height do
      List.update_at(cells, row_y, fn row ->
        clear_row_columns(row, x, width, buffer.width, empty_cell)
      end)
    else
      cells
    end
  end

  defp clear_row_columns(row, x, width, buffer_width, empty_cell) do
    Enum.reduce(x..(x + width - 1), row, fn col_x, acc_row ->
      if col_x < buffer_width do
        List.replace_at(acc_row, col_x, empty_cell)
      else
        acc_row
      end
    end)
  end

  def mark_damaged(buffer, x, y, width, height, _reason) do
    # Add the new damage region to the existing list
    new_region = {x, y, width, height}
    updated_damage_regions = [new_region | buffer.damage_regions || []]
    %{buffer | damage_regions: updated_damage_regions}
  end

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
    _line = Enum.at(buffer.cells, y, [])
    empty_cell = Raxol.Terminal.Cell.new()

    cleared_line =
      List.duplicate(empty_cell, x) ++
        List.duplicate(empty_cell, buffer.width - x)

    new_cells = List.replace_at(buffer.cells, y, cleared_line)
    %{buffer | cells: new_cells}
  end

  defp erase_line_to_beginning(buffer, x, y) do
    line = Enum.at(buffer.cells, y, [])
    empty_cell = Raxol.Terminal.Cell.new()
    cleared_line = List.duplicate(empty_cell, x + 1) ++ Enum.drop(line, x + 1)
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
  @impl Raxol.Terminal.ScreenBufferBehaviour
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

  # Handle case where lines parameter is a list (from tests)
  def scroll_down(buffer, _lines, count) when integer?(count) do
    Raxol.Terminal.Commands.Scrolling.scroll_down(
      buffer,
      count,
      buffer.scroll_region,
      %{}
    )
  end

  # === Behaviour Callback Implementations ===

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def cleanup_file_watching(buffer), do: buffer

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def clear_output_buffer(buffer), do: %{buffer | output_buffer: ""}

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def clear_saved_states(buffer), do: %{buffer | saved_states: []}

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def clear_screen(buffer), do: Eraser.clear(buffer)

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def collect_metrics(_buffer, _type), do: %{}

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def create_chart(buffer, _type, _options), do: buffer

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def current_theme, do: %{}

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def enqueue_control_sequence(buffer, _sequence), do: buffer

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def erase_all_with_scrollback(buffer), do: Eraser.clear(buffer)

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def erase_from_cursor_to_end_of_line(buffer),
    do: Eraser.erase_from_cursor_to_end_of_line(buffer)

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def erase_from_start_of_line_to_cursor(buffer),
    do: Eraser.erase_from_start_of_line_to_cursor(buffer)

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def erase_from_start_to_cursor(buffer),
    do: Eraser.erase_from_start_to_cursor(buffer)

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def erase_line(buffer), do: Eraser.erase_line(buffer, 0)

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def flush_output(buffer), do: buffer

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_config, do: %{}

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_current_state(buffer), do: buffer.current_state || %{}

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_metric(_buffer, _type, _name), do: 0

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_metric_value(_buffer, _name), do: 0

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_metrics_by_type(_buffer, _type), do: []

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_output_buffer(buffer), do: buffer.output_buffer || ""

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_preferences, do: %{}

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_saved_states_count(buffer), do: length(buffer.saved_states || [])

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_size(buffer), do: {buffer.width, buffer.height}

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_state_stack(buffer), do: buffer.state_stack || []

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def get_update_settings, do: %{}

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def handle_csi_sequence(buffer, _command, _params), do: buffer

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def handle_debounced_events(buffer, _events, _delay), do: buffer

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def handle_file_event(buffer, _event), do: buffer

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def handle_mode(buffer, _mode, _value), do: buffer

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def has_saved_states?(buffer), do: length(buffer.saved_states || []) > 0

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def light_theme, do: %{}

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def mark_damaged(buffer, _x, _y, _width, _height), do: buffer

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def record_metric(buffer, _type, _name, _value), do: buffer

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def record_operation(buffer, _operation, _duration), do: buffer

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def record_performance(buffer, _metric, _value), do: buffer

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def record_resource(buffer, _type, _value), do: buffer

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def reset_state(buffer), do: %{buffer | current_state: %{}}

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def restore_state(buffer), do: buffer

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def save_state(buffer), do: buffer

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def set_config(_config), do: :ok

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def set_preferences(_preferences), do: :ok

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def update_current_state(buffer, _updates), do: buffer

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def update_state_stack(buffer, _stack), do: buffer

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def verify_metrics(_buffer, _type), do: true

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def write(buffer, _data), do: buffer

  # === Scroll Operations ===

  @doc """
  Fills a region of the buffer with a specified cell.
  """
  @spec fill_region(
          t(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          Cell.t()
        ) :: t()
  def fill_region(buffer, x, y, width, height, cell) do
    # Validate coordinates
    if x < 0 or y < 0 or width <= 0 or height <= 0 do
      raise ArgumentError,
            "Invalid region parameters: x=#{x}, y=#{y}, width=#{width}, height=#{height}"
    end

    if x + width > buffer.width or y + height > buffer.height do
      raise ArgumentError, "Region extends beyond buffer bounds"
    end

    # Fill the region with the specified cell
    new_cells =
      Enum.reduce(y..(y + height - 1), buffer.cells, fn row_y, acc_cells ->
        List.update_at(acc_cells, row_y, &fill_row(&1, x, width, cell))
      end)

    %{buffer | cells: new_cells}
  end

  defp fill_row(row, x, width, cell) do
    Enum.reduce(x..(x + width - 1), row, fn col_x, acc_row ->
      List.replace_at(acc_row, col_x, cell)
    end)
  end

  @impl Raxol.Terminal.ScreenBufferBehaviour
  def update(buffer, changes) do
    Raxol.Terminal.Buffer.Content.update(buffer, changes)
  end
end
