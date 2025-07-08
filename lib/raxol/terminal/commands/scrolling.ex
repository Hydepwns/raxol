defmodule Raxol.Terminal.Commands.Scrolling do
  @moduledoc """
  Handles scrolling operations for the terminal screen buffer.
  """

  import Raxol.Guards
  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.ANSI.TextFormatting
  alias Raxol.Terminal.Buffer.Operations
  require Raxol.Core.Runtime.Log

  @spec scroll_up(
          ScreenBuffer.t(),
          non_neg_integer(),
          {integer(), integer()} | nil,
          Raxol.Terminal.ANSI.TextFormatting.text_style()
        ) :: ScreenBuffer.t()

  def scroll_up(buffer, _count, {region_top, region_bottom}, _blank_style)
      when integer?(region_top) and integer?(region_bottom) and
             region_top > region_bottom do
    Raxol.Core.Runtime.Log.debug(
      "Scroll Up: Invalid region (top > bottom). Region: #{inspect({region_top, region_bottom})}. No scroll."
    )

    buffer
  end

  def scroll_up(%{__struct__: _} = buffer, count, scroll_region, blank_style)
      when count > 0 do
    {effective_top, effective_bottom} = get_scroll_region(buffer, scroll_region)
    region_height = effective_bottom - effective_top + 1

    if count > 0 and region_height > 0 do
      actual_scroll_count = min(count, region_height)
      preserved_lines_source_start = effective_top + actual_scroll_count
      _preserved_lines_count = region_height - actual_scroll_count

      new_buffer =
        shift_lines_up(
          buffer,
          effective_top,
          preserved_lines_source_start,
          region_height,
          blank_style
        )

      %{
        new_buffer
        | scroll_position:
            min(
              (buffer.scroll_position || 0) + actual_scroll_count,
              effective_bottom
            )
      }
    else
      buffer
    end
  end

  def scroll_up(buffer, _count, _scroll_region, _blank_style)
      when tuple?(buffer) do
    raise ArgumentError,
          "Expected buffer struct, got tuple (did you pass result of get_dimensions/1?)"
  end

  def scroll_up(buffer, count, _scroll_region, _blank_style) when count <= 0,
    do: buffer

  @spec scroll_down(
          ScreenBuffer.t(),
          non_neg_integer(),
          {integer(), integer()} | nil,
          Raxol.Terminal.ANSI.TextFormatting.text_style()
        ) :: ScreenBuffer.t()

  def scroll_down(buffer, _count, {region_top, region_bottom}, _blank_style)
      when integer?(region_top) and integer?(region_bottom) and
             region_top > region_bottom do
    Raxol.Core.Runtime.Log.debug(
      "Scroll Down: Invalid region (top > bottom). Region: #{inspect({region_top, region_bottom})}. No scroll."
    )

    buffer
  end

  def scroll_down(%{__struct__: _} = buffer, count, scroll_region, blank_style)
      when count > 0 do
    {effective_top, effective_bottom} = get_scroll_region(buffer, scroll_region)
    region_height = effective_bottom - effective_top + 1

    if count > 0 and region_height > 0 do
      actual_scroll_count = min(count, region_height)

      new_buffer =
        shift_lines_down(
          buffer,
          effective_top + actual_scroll_count,
          effective_top,
          region_height,
          blank_style
        )

      %{
        new_buffer
        | scroll_position:
            max(
              (buffer.scroll_position || 0) - actual_scroll_count,
              effective_top
            )
      }
    else
      buffer
    end
  end

  def scroll_down(buffer, _count, _scroll_region, _blank_style)
      when tuple?(buffer) do
    raise ArgumentError,
          "Expected buffer struct, got tuple (did you pass result of get_dimensions/1?)"
  end

  def scroll_down(buffer, count, _scroll_region, _blank_style) when count <= 0,
    do: buffer

  defp get_scroll_region(buffer, scroll_region) do
    case scroll_region do
      {top, bottom}
      when integer?(top) and integer?(bottom) and top >= 0 and
             bottom <= buffer.height ->
        {top, bottom}

      _ ->
        case Raxol.Terminal.Buffer.ScrollRegion.get_region(buffer) do
          {top, bottom} -> {top, bottom}
          nil -> {0, buffer.height - 1}
        end
    end
  end

  defp shift_lines_up(
         buffer,
         region_start,
         region_start_plus_n,
         region_height,
         blank_style
       ) do
    cells = buffer.cells
    _region_end = region_start + region_height - 1
    n = region_start_plus_n - region_start

    new_cells =
      Enum.with_index(cells)
      |> Enum.map(fn {line, idx} ->
        map_line_for_shift_up(
          idx,
          cells,
          line,
          region_start,
          region_start + region_height - 1,
          n,
          buffer.width,
          blank_style
        )
      end)

    %{buffer | cells: new_cells}
  end

  defp map_line_for_shift_up(
         idx,
         cells,
         line,
         region_start,
         region_end,
         n,
         width,
         blank_style
       ) do
    cond do
      idx >= region_start and idx <= region_end - n ->
        get_source_line(cells, idx + n, line)

      idx > region_end - n and idx <= region_end ->
        # Create empty line for this position
        List.duplicate(Cell.new(" ", blank_style), width)

      true ->
        line
    end
  end

  defp shift_lines_down(
         buffer,
         region_start_plus_n,
         region_start,
         count,
         blank_style
       ) do
    cells = buffer.cells
    region_height = count
    n = region_start_plus_n - region_start
    region_end = region_start + region_height - 1

    new_cells =
      Enum.with_index(cells)
      |> Enum.map(fn {line, idx} ->
        map_line_for_shift_down(
          idx,
          cells,
          line,
          region_start,
          region_end,
          n,
          buffer.width,
          blank_style
        )
      end)

    %{buffer | cells: new_cells}
  end

  defp map_line_for_shift_down(
         idx,
         cells,
         line,
         region_start,
         region_end,
         n,
         width,
         blank_style
       ) do
    cond do
      idx >= region_start + n and idx <= region_end ->
        get_source_line(cells, idx - n, line)

      idx >= region_start and idx < region_start + n ->
        # Create empty line for this position
        List.duplicate(Cell.new(" ", blank_style), width)

      true ->
        line
    end
  end

  defp get_source_line(cells, source_idx, fallback_line) do
    if source_idx >= 0 and source_idx < length(cells) do
      Enum.at(cells, source_idx) || fallback_line
    else
      fallback_line
    end
  end

  defp fill_blank_lines(buffer, region_start, count, style, :up) do
    region_height = get_region_height(buffer, region_start)
    region_end = region_start + region_height - 1
    blank_start = region_end - count + 1
    blank_end = region_end
    empty_line = List.duplicate(Cell.new(" ", style), buffer.width)

    updated_cells =
      Enum.with_index(buffer.cells)
      |> Enum.map(fn {line, idx} ->
        if idx >= blank_start and idx <= blank_end do
          empty_line
        else
          line
        end
      end)

    %{buffer | cells: updated_cells}
  end

  defp fill_blank_lines(buffer, region_start, count, style, :down) do
    region_height = get_region_height(buffer, region_start)
    _region_end = region_start + region_height - 1
    blank_start = region_start
    blank_end = region_start + count - 1
    empty_line = List.duplicate(Cell.new(" ", style), buffer.width)

    updated_cells =
      Enum.with_index(buffer.cells)
      |> Enum.map(fn {line, idx} ->
        if idx >= blank_start and idx <= blank_end do
          empty_line
        else
          line
        end
      end)

    %{buffer | cells: updated_cells}
  end

  defp get_region_height(buffer, region_start) do
    # Try to infer region height from buffer.cells length and region_start
    buffer.height - region_start
  end
end
