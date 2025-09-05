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

  alias Raxol.Terminal.ScreenBuffer.{
    EraseOperations,
    MemoryUtils,
    RegionOperations,
    BehaviourImpl
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
    validate_dimensions(new_width <= 0 or new_height <= 0, new_width, new_height)

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
      when is_integer(top) and is_integer(bottom) do
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

  defdelegate erase_from_cursor_to_end(buffer, x, y, top, bottom),
    to: EraseOperations

  defdelegate erase_from_start_to_cursor(buffer, x, y, top, bottom),
    to: EraseOperations

  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate erase_all(buffer), to: EraseOperations
  defdelegate clear_region(buffer, x, y, width, height), to: EraseOperations

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

  defdelegate shift_region_to_line(buffer, region, target_line),
    to: ScrollRegion

  @doc """
  Gets the estimated memory usage of the screen buffer.
  """
  @spec get_memory_usage(t()) :: non_neg_integer()
  defdelegate get_memory_usage(buffer), to: MemoryUtils

  defdelegate erase_in_line(buffer, position, type), to: EraseOperations
  defdelegate erase_in_display(buffer, position, type), to: EraseOperations
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate erase_from_cursor_to_end(buffer), to: EraseOperations

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
      when is_integer(lines) and is_integer(count) do
    Raxol.Terminal.Commands.Scrolling.scroll_down(
      buffer,
      lines,
      buffer.scroll_region,
      %{}
    )
  end

  # Handle case where lines parameter is a list (from tests)
  def scroll_down(buffer, _lines, count) when is_integer(count) do
    Raxol.Terminal.Commands.Scrolling.scroll_down(
      buffer,
      count,
      buffer.scroll_region,
      %{}
    )
  end

  # === Behaviour Callback Implementations ===

  # All behaviour implementations delegated to BehaviourImpl
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate cleanup_file_watching(buffer), to: BehaviourImpl
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate clear_output_buffer(buffer), to: BehaviourImpl
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate clear_saved_states(buffer), to: BehaviourImpl
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate clear_screen(buffer), to: BehaviourImpl
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate collect_metrics(buffer, type), to: BehaviourImpl
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate create_chart(buffer, type, options), to: BehaviourImpl
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate current_theme(), to: BehaviourImpl
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate enqueue_control_sequence(buffer, sequence), to: BehaviourImpl
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate erase_all_with_scrollback(buffer), to: BehaviourImpl
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate erase_from_cursor_to_end_of_line(buffer), to: BehaviourImpl
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate erase_from_start_of_line_to_cursor(buffer), to: BehaviourImpl
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate erase_from_start_to_cursor(buffer), to: BehaviourImpl
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate erase_line(buffer), to: BehaviourImpl
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate flush_output(buffer), to: BehaviourImpl
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate get_config(), to: BehaviourImpl
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate get_current_state(buffer), to: BehaviourImpl
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate get_metric(buffer, type, name), to: BehaviourImpl
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate get_metric_value(buffer, name), to: BehaviourImpl
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate get_metrics_by_type(buffer, type), to: BehaviourImpl
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate get_output_buffer(buffer), to: BehaviourImpl
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate get_preferences(), to: BehaviourImpl
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate get_saved_states_count(buffer), to: BehaviourImpl
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate get_size(buffer), to: BehaviourImpl
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate get_state_stack(buffer), to: BehaviourImpl
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate get_update_settings(), to: BehaviourImpl
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate handle_csi_sequence(buffer, command, params), to: BehaviourImpl
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate handle_debounced_events(buffer, events, delay), to: BehaviourImpl
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate handle_file_event(buffer, event), to: BehaviourImpl
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate handle_mode(buffer, mode, value), to: BehaviourImpl
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate has_saved_states?(buffer), to: BehaviourImpl
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate light_theme(), to: BehaviourImpl
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate mark_damaged(buffer, x, y, width, height), to: BehaviourImpl
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate record_metric(buffer, type, name, value), to: BehaviourImpl
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate record_operation(buffer, operation, duration), to: BehaviourImpl
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate record_performance(buffer, metric, value), to: BehaviourImpl
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate record_resource(buffer, type, value), to: BehaviourImpl
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate reset_state(buffer), to: BehaviourImpl
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate restore_state(buffer), to: BehaviourImpl
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate save_state(buffer), to: BehaviourImpl
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate set_config(config), to: BehaviourImpl
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate set_preferences(preferences), to: BehaviourImpl
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate update_current_state(buffer, updates), to: BehaviourImpl
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate update_state_stack(buffer, stack), to: BehaviourImpl
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate verify_metrics(buffer, type), to: BehaviourImpl
  @impl Raxol.Terminal.ScreenBufferBehaviour
  defdelegate write(buffer, data), to: BehaviourImpl

  # === Scroll Operations ===

  defdelegate fill_region(buffer, x, y, width, height, cell),
    to: RegionOperations

  def update(buffer, changes) do
    Raxol.Terminal.Buffer.Content.update(buffer, changes)
  end

  defdelegate handle_single_line_replacement(
                lines_list,
                row,
                start_col,
                end_col,
                replacement
              ),
              to: RegionOperations

  defp validate_dimensions(true, new_width, new_height) do
    raise ArgumentError,
          "ScreenBuffer dimensions must be positive integers, got: #{new_width}x#{new_height}"
  end

  defp validate_dimensions(false, _new_width, _new_height), do: :ok
end
