defmodule Raxol.Terminal.ScreenBuffer.Scrolling do
  @moduledoc """
  Scroll operations for ScreenBuffer: scroll_up/down with region support.
  """

  alias Raxol.Terminal.Cell

  @doc """
  Scrolls the buffer content up by the specified number of lines within a region.
  Returns {buffer, scrolled_lines}.
  """
  def scroll_up(buffer, lines) when lines > 0 do
    {top, bottom} = get_effective_scroll_region(buffer)

    if top < bottom do
      cells = buffer.cells || []
      {before_region, region_and_after} = Enum.split(cells, top)
      {region, after_region} = Enum.split(region_and_after, bottom - top + 1)

      lines_to_scroll = min(lines, length(region))
      scrolled_out = Enum.take(region, lines_to_scroll)
      remaining_region = Enum.drop(region, lines_to_scroll)

      empty_lines =
        List.duplicate(create_empty_line(buffer.width), lines_to_scroll)

      scrolled_region = remaining_region ++ empty_lines
      new_cells = before_region ++ scrolled_region ++ after_region
      {%{buffer | cells: new_cells}, scrolled_out}
    else
      {buffer, []}
    end
  end

  def scroll_up(buffer, _), do: {buffer, []}

  @doc """
  Scrolls the buffer content down by the specified number of lines within a region.
  """
  def scroll_down(buffer, lines) when lines > 0 do
    {top, bottom} = get_effective_scroll_region(buffer)

    if top < bottom do
      cells = buffer.cells || []
      {before_region, region_and_after} = Enum.split(cells, top)
      {region, after_region} = Enum.split(region_and_after, bottom - top + 1)

      lines_to_scroll = min(lines, length(region))

      empty_lines =
        List.duplicate(create_empty_line(buffer.width), lines_to_scroll)

      kept_region = Enum.take(region, length(region) - lines_to_scroll)
      scrolled_region = empty_lines ++ kept_region
      new_cells = before_region ++ scrolled_region ++ after_region
      %{buffer | cells: new_cells}
    else
      buffer
    end
  end

  def scroll_down(buffer, _), do: buffer

  @doc """
  Scrolls up within an explicit top/bottom region.
  """
  def scroll_up(buffer, top, bottom, lines) do
    do_scroll_up(buffer, lines, top, bottom)
  end

  @doc """
  Scrolls down within an explicit top/bottom region.
  """
  def scroll_down(buffer, top, bottom, lines) do
    do_scroll_down(buffer, lines, top, bottom)
  end

  # Internal scroll implementations

  defp do_scroll_up(buffer, lines, top, bottom) do
    {effective_top, effective_bottom} =
      normalize_scroll_region(buffer, top, bottom)

    cells = buffer.cells || []

    if effective_top < effective_bottom and lines > 0 do
      {before_region, region_and_after} = Enum.split(cells, effective_top)

      {region, after_region} =
        Enum.split(region_and_after, effective_bottom - effective_top + 1)

      lines_to_scroll = min(lines, length(region))
      kept_region = Enum.drop(region, lines_to_scroll)

      empty_lines =
        List.duplicate(create_empty_line(buffer.width), lines_to_scroll)

      scrolled_region = kept_region ++ empty_lines
      new_cells = before_region ++ scrolled_region ++ after_region
      %{buffer | cells: new_cells}
    else
      buffer
    end
  end

  defp do_scroll_down(buffer, lines, top, bottom) do
    {effective_top, effective_bottom} =
      normalize_scroll_region(buffer, top, bottom)

    cells = buffer.cells || []

    if effective_top < effective_bottom and lines > 0 do
      {before_region, region_and_after} = Enum.split(cells, effective_top)

      {region, after_region} =
        Enum.split(region_and_after, effective_bottom - effective_top + 1)

      lines_to_scroll = min(lines, length(region))

      empty_lines =
        List.duplicate(create_empty_line(buffer.width), lines_to_scroll)

      kept_region = Enum.take(region, length(region) - lines_to_scroll)
      scrolled_region = empty_lines ++ kept_region
      new_cells = before_region ++ scrolled_region ++ after_region
      %{buffer | cells: new_cells}
    else
      buffer
    end
  end

  defp get_effective_scroll_region(buffer) do
    case buffer.scroll_region do
      nil -> {0, buffer.height - 1}
      {top, bottom} -> {top, min(bottom, buffer.height - 1)}
    end
  end

  defp normalize_scroll_region(buffer, top, bottom) do
    {max(0, top), min(buffer.height - 1, bottom)}
  end

  defp create_empty_line(width) when is_integer(width) and width > 0 do
    List.duplicate(Cell.new(), width)
  end

  defp create_empty_line(_width), do: []
end
