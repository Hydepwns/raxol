defmodule Raxol.Terminal.Commands.Scrolling do
  @moduledoc """
  Handles scrolling operations for the terminal screen buffer.
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cell
  require Raxol.Core.Runtime.Log

  @spec scroll_up(
          ScreenBuffer.t(),
          non_neg_integer(),
          {integer(), integer()} | nil,
          Raxol.Terminal.ANSI.TextFormatting.text_style()
        ) :: ScreenBuffer.t()

  # Handles invalid region {top, bottom} where top > bottom
  def scroll_up(buffer, _count, {region_top, region_bottom}, _blank_style)
      when is_integer(region_top) and is_integer(region_bottom) and
             region_top > region_bottom do
    Raxol.Core.Runtime.Log.debug(
      "Scroll Up: Invalid region (top > bottom). Region: #{inspect({region_top, region_bottom})}. No scroll."
    )

    buffer
  end

  # Main scrolling logic for scroll_up
  def scroll_up(%{__struct__: _} = buffer, count, scroll_region, blank_style)
      when count > 0 do
    {top_limit, bottom_limit} =
      case scroll_region do
        # At this point, rt <= rb due to the clause above
        {rt, rb} -> {rt, rb}
        nil -> {0, buffer.height - 1}
      end

    effective_top = max(0, top_limit)
    effective_bottom = min(buffer.height - 1, bottom_limit)
    region_height = effective_bottom - effective_top + 1

    # If region is invalid, count is too large for the region, or region height is <= 0, no effective scroll
    if region_height <= 0 or count <= 0 or count > region_height do
      Raxol.Core.Runtime.Log.debug(
        "Scroll Up: No effective scroll. Top: #{effective_top}, Bottom: #{effective_bottom}, Count: #{count}, Region Height: #{region_height}"
      )

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
          cells = ScreenBuffer.get_line(acc_buffer, source_row)

          if is_list(cells) do
            ScreenBuffer.put_line(acc_buffer, target_row, cells)
          else
            acc_buffer
          end
        end)
      else
        # No lines to preserve and shift if actual_scroll_count == region_height
        new_buffer
      end

    # Fill bottom lines with blank lines
    # This is also effective_bottom - actual_scroll_count + 1
    blank_line_start_row = effective_top + preserved_lines_count
    blank_line_cells = List.duplicate(Cell.new(" ", blank_style), buffer.width)

    new_buffer =
      Enum.reduce(0..(actual_scroll_count - 1), new_buffer, fn i, acc_buffer ->
        ScreenBuffer.put_line(
          acc_buffer,
          blank_line_start_row + i,
          blank_line_cells
        )
      end)

    new_buffer
  end

  def scroll_up(buffer, _count, _scroll_region, _blank_style)
      when is_tuple(buffer) do
    raise ArgumentError,
          "Expected buffer struct, got tuple (did you pass result of get_dimensions/1?)"
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

  # Handles invalid region {top, bottom} where top > bottom
  def scroll_down(buffer, _count, {region_top, region_bottom}, _blank_style)
      when is_integer(region_top) and is_integer(region_bottom) and
             region_top > region_bottom do
    Raxol.Core.Runtime.Log.debug(
      "Scroll Down: Invalid region (top > bottom). Region: #{inspect({region_top, region_bottom})}. No scroll."
    )

    buffer
  end

  # Main scrolling logic for scroll_down
  def scroll_down(%{__struct__: _} = buffer, count, scroll_region, blank_style)
      when count > 0 do
    {top_limit, bottom_limit} =
      case scroll_region do
        # At this point, rt <= rb due to the clause above
        {rt, rb} ->
          {rt, rb}

        nil ->
          {0, buffer.height - 1}

          # NOTE: If scroll_region is an invalid format other than {t,b} or nil, it will cause a CaseClauseError here.
          # This could be made more robust if needed, e.g. by adding a default `_ -> {0, buffer.height - 1}` and logging a warning.
      end

    effective_top = max(0, top_limit)
    effective_bottom = min(buffer.height - 1, bottom_limit)
    region_height = effective_bottom - effective_top + 1

    if region_height <= 0 or count <= 0 or count > region_height do
      Raxol.Core.Runtime.Log.debug(
        "Scroll Down: No effective scroll. Top: #{effective_top}, Bottom: #{effective_bottom}, Count: #{count}, Region Height: #{region_height}"
      )

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
        0..(preserved_lines_count - 1)
        |> Enum.reverse()
        |> Enum.reduce(new_buffer, fn i, acc_buffer ->
          source_row = effective_top + i
          target_row = effective_top + actual_scroll_count + i
          cells = ScreenBuffer.get_line(acc_buffer, source_row)

          if is_list(cells) do
            ScreenBuffer.put_line(acc_buffer, target_row, cells)
          else
            acc_buffer
          end
        end)
      else
        # No lines to preserve if actual_scroll_count == region_height
        new_buffer
      end

    # Fill top lines with blank lines
    blank_line_cells = List.duplicate(Cell.new(" ", blank_style), buffer.width)

    new_buffer =
      Enum.reduce(0..(actual_scroll_count - 1), new_buffer, fn i, acc_buffer ->
        ScreenBuffer.put_line(acc_buffer, effective_top + i, blank_line_cells)
      end)

    new_buffer
  end

  def scroll_down(buffer, _count, _scroll_region, _blank_style)
      when is_tuple(buffer) do
    raise ArgumentError,
          "Expected buffer struct, got tuple (did you pass result of get_dimensions/1?)"
  end

  # No scroll or invalid count (this might be redundant if the invalid region clause is comprehensive)
  def scroll_down(buffer, count, _scroll_region, _blank_style) when count <= 0,
    do: buffer
end
