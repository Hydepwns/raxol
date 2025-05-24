defmodule Raxol.Terminal.Commands.Scrolling do
  @moduledoc """
  Handles scrolling operations for the terminal screen buffer.
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cell
  # require Logger # Uncomment if using Logger.debug statements

  @spec scroll_up(
          ScreenBuffer.t(),
          non_neg_integer(),
          {integer(), integer()} | nil,
          Raxol.Terminal.ANSI.TextFormatting.text_style()
        ) :: ScreenBuffer.t()
  def scroll_up(buffer, count, scroll_region, blank_style) when count > 0 do
    {top_limit, bottom_limit} =
      case scroll_region do
        {region_top, region_bottom} when region_top <= region_bottom ->
          {region_top, region_bottom}

        _ ->
          # Full buffer if region is nil or invalid
          {0, buffer.height - 1}
      end

    # Ensure scroll limits are within buffer dimensions
    effective_top = max(0, top_limit)
    effective_bottom = min(buffer.height - 1, bottom_limit)
    region_height = effective_bottom - effective_top + 1

    # If region is invalid, count is too large for the region, or region height is <= 0, no effective scroll
    if region_height <= 0 or count <= 0 or count > region_height do
      # Logger.debug("Scroll Up: No effective scroll. Top: #{effective_top}, Bottom: #{effective_bottom}, Count: #{count}, Region Height: #{region_height}")
      buffer
    end

    actual_scroll_count = min(count, region_height)

    # Lines that remain and shift up
    preserved_lines_source_start = effective_top + actual_scroll_count
    preserved_lines_count = region_height - actual_scroll_count

    new_buffer = buffer

    # Shift existing lines up
    new_buffer =
      if preserved_lines_count > 0 do
        Enum.reduce(0..(preserved_lines_count - 1), new_buffer, fn i,
                                                                   acc_buffer ->
          source_row = preserved_lines_source_start + i
          target_row = effective_top + i
          {_cont, _attr, cells} = ScreenBuffer.get_line(acc_buffer, source_row)
          ScreenBuffer.put_line(acc_buffer, target_row, cells)
        end)
      else
        # No lines to preserve and shift if actual_scroll_count == region_height
        new_buffer
      end

    # Fill bottom lines with blank lines
    # This is also effective_bottom - actual_scroll_count + 1
    blank_line_start_row = effective_top + preserved_lines_count
    blank_line_cells = List.duplicate(Cell.new(" ", blank_style), buffer.width)

    Enum.reduce(0..(actual_scroll_count - 1), new_buffer, fn i, acc_buffer ->
      ScreenBuffer.put_line(
        acc_buffer,
        blank_line_start_row + i,
        blank_line_cells
      )
    end)

    buffer
  end

  # No scroll or invalid count
  def scroll_up(buffer, count, _scroll_region, _blank_style) when count <= 0,
    do: buffer

  @spec scroll_down(
          ScreenBuffer.t(),
          non_neg_integer(),
          {integer(), integer()} | nil,
          Raxol.Terminal.ANSI.TextFormatting.text_style()
        ) :: ScreenBuffer.t()
  def scroll_down(buffer, count, scroll_region, blank_style) when count > 0 do
    {top_limit, bottom_limit} =
      case scroll_region do
        {region_top, region_bottom} when region_top <= region_bottom ->
          {region_top, region_bottom}

        _ ->
          # Full buffer if region is nil or invalid
          {0, buffer.height - 1}
      end

    effective_top = max(0, top_limit)
    effective_bottom = min(buffer.height - 1, bottom_limit)
    region_height = effective_bottom - effective_top + 1

    if region_height <= 0 or count <= 0 or count > region_height do
      # Logger.debug("Scroll Down: No effective scroll. Top: #{effective_top}, Bottom: #{effective_bottom}, Count: #{count}, Region Height: #{region_height}")
      buffer
    end

    actual_scroll_count = min(count, region_height)

    # Lines that remain and shift down
    _preserved_lines_source_end = effective_bottom - actual_scroll_count
    preserved_lines_count = region_height - actual_scroll_count

    new_buffer = buffer

    # Shift existing lines down (iterate backwards to avoid overwriting)
    new_buffer =
      if preserved_lines_count > 0 do
        Enum.reduce_right(0..(preserved_lines_count - 1), new_buffer, fn i,
                                                                         acc_buffer ->
          source_row = effective_top + i
          target_row = effective_top + actual_scroll_count + i
          {_cont, _attr, cells} = ScreenBuffer.get_line(acc_buffer, source_row)
          ScreenBuffer.put_line(acc_buffer, target_row, cells)
        end)
      else
        # No lines to preserve if actual_scroll_count == region_height
        new_buffer
      end

    # Fill top lines with blank lines
    blank_line_cells = List.duplicate(Cell.new(" ", blank_style), buffer.width)

    Enum.reduce(0..(actual_scroll_count - 1), new_buffer, fn i, acc_buffer ->
      ScreenBuffer.put_line(acc_buffer, effective_top + i, blank_line_cells)
    end)

    buffer
  end

  # No scroll or invalid count
  def scroll_down(buffer, count, _scroll_region, _blank_style) when count <= 0,
    do: buffer
end
