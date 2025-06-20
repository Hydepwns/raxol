defmodule Raxol.Terminal.Commands.Scrolling do
  @moduledoc """
  Handles scrolling operations for the terminal screen buffer.
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.Buffer.Operations
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
    {effective_top, effective_bottom} = get_scroll_region(buffer, scroll_region)
    region_height = effective_bottom - effective_top + 1

    if count > 0 and region_height > 0 do
      actual_scroll_count = min(count, region_height)
      preserved_lines_source_start = effective_top + actual_scroll_count
      preserved_lines_count = region_height - actual_scroll_count

      new_buffer =
        buffer
        |> shift_lines_up(
          effective_top,
          preserved_lines_source_start,
          preserved_lines_count
        )
        |> fill_blank_lines(effective_top, region_height, blank_style)

      # Update scroll position
      %{
        new_buffer
        | scroll_position:
            min(buffer.scroll_position + actual_scroll_count, effective_bottom)
      }
    else
      buffer
    end
  end

  def scroll_up(buffer, _count, _scroll_region, _blank_style)
      when is_tuple(buffer) do
    raise ArgumentError,
          "Expected buffer struct, got tuple (did you pass result of get_dimensions/1?)"
  end

  # No scroll or invalid count
  def scroll_up(buffer, count, _scroll_region, _blank_style) when count <= 0,
    do: buffer

  @doc """
  Scrolls the buffer down by the specified number of lines.

  ## Parameters
    * `buffer` - The screen buffer to modify
    * `count` - The number of lines to scroll down
    * `scroll_region` - Optional scroll region override {top, bottom}
    * `blank_style` - Style to apply to blank lines

  ## Returns
    Updated screen buffer
  """
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

  def scroll_down(%{__struct__: _} = buffer, count, scroll_region, blank_style)
      when count > 0 do
    {effective_top, effective_bottom} = get_scroll_region(buffer, scroll_region)
    region_height = effective_bottom - effective_top + 1

    if count > 0 and region_height > 0 do
      actual_scroll_count = min(count, region_height)

      new_buffer =
        buffer
        |> shift_lines_down(
          effective_top + actual_scroll_count,
          effective_top,
          region_height
        )
        |> fill_blank_lines(effective_top, region_height, blank_style)

      # Update scroll position
      %{
        new_buffer
        | scroll_position:
            max(buffer.scroll_position - actual_scroll_count, effective_top)
      }
    else
      buffer
    end
  end

  def scroll_down(buffer, _count, _scroll_region, _blank_style)
      when is_tuple(buffer) do
    raise ArgumentError,
          "Expected buffer struct, got tuple (did you pass result of get_dimensions/1?)"
  end

  # No scroll or invalid count
  def scroll_down(buffer, count, _scroll_region, _blank_style) when count <= 0,
    do: buffer

  # Private helper functions

  defp get_scroll_region(buffer, scroll_region) do
    case scroll_region do
      {top, bottom}
      when is_integer(top) and is_integer(bottom) and top >= 0 and
             bottom <= buffer.height ->
        {top, bottom}

      _ ->
        Raxol.Terminal.Buffer.ScrollRegion.get_region(buffer)
    end
  end

  defp shift_lines_up(buffer, region_start, region_start_plus_n, count) do
    # Shift lines in the region up by N (count):
    # lines at region_start+N..region_start+count-1 move to region_start..region_start+count-N-1
    cells = buffer.cells
    region_end = region_start + count - 1
    n = region_start_plus_n - region_start

    new_cells =
      Enum.with_index(cells)
      |> Enum.map(fn {line, idx} ->
        cond do
          idx >= region_start and idx <= region_end - n ->
            Enum.at(cells, idx + n)

          idx > region_end - n and idx <= region_end ->
            nil

          true ->
            line
        end
      end)

    %{buffer | cells: new_cells}
  end

  defp shift_lines_down(buffer, region_start_plus_n, region_start, count) do
    # Shift lines in the region down by N (count):
    # lines at region_start..region_end-n move to region_start+n..region_end
    cells = buffer.cells
    region_height = count
    n = region_start_plus_n - region_start
    region_end = region_start + region_height - 1

    new_cells =
      Enum.with_index(cells)
      |> Enum.map(fn {line, idx} ->
        cond do
          # Lines that should be shifted down (moved from earlier position)
          idx >= region_start + n and idx <= region_end ->
            # Get content from the line that was n positions earlier
            source_idx = idx - n
            Enum.at(cells, source_idx)

          # Lines at the top of the region that become blank
          idx >= region_start and idx < region_start + n ->
            nil

          # Lines outside the region remain unchanged
          true ->
            line
        end
      end)

    %{buffer | cells: new_cells}
  end

  defp fill_blank_lines(buffer, _start_line, _count, style) do
    empty_line = List.duplicate(Cell.new(" ", style), buffer.width)

    updated_cells =
      Enum.map(buffer.cells, fn
        nil -> empty_line
        line -> line
      end)

    %{buffer | cells: updated_cells}
  end
end
