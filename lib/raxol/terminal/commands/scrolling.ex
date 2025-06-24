defmodule Raxol.Terminal.Commands.Scrolling do
  @moduledoc """
  Handles scrolling operations for the terminal screen buffer.
  """

  import Raxol.Guards
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
      preserved_lines_count = region_height - actual_scroll_count

      new_buffer =
        buffer
        |> shift_lines_up(
          effective_top,
          preserved_lines_source_start,
          preserved_lines_count
        )
        |> fill_blank_lines(effective_top, region_height, blank_style)

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
        buffer
        |> shift_lines_down(
          effective_top + actual_scroll_count,
          effective_top,
          region_height
        )
        |> fill_blank_lines(effective_top, region_height, blank_style)

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
        Raxol.Terminal.Buffer.ScrollRegion.get_region(buffer)
    end
  end

  defp shift_lines_up(buffer, region_start, region_start_plus_n, count) do
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
    cells = buffer.cells
    region_height = count
    n = region_start_plus_n - region_start
    region_end = region_start + region_height - 1

    new_cells =
      Enum.with_index(cells)
      |> Enum.map(fn {line, idx} ->
        cond do
          idx >= region_start + n and idx <= region_end ->
            source_idx = idx - n
            Enum.at(cells, source_idx)

          idx >= region_start and idx < region_start + n ->
            nil

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
