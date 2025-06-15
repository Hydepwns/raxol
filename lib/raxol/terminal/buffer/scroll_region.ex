defmodule Raxol.Terminal.Buffer.ScrollRegion do
  @moduledoc """
  Handles scroll region operations for the screen buffer.
  This module manages the scroll region boundaries and provides functions
  for scrolling content within the defined region.

  ## Scroll Region

  A scroll region defines a subset of the screen buffer where scrolling operations
  are confined. The region is defined by its top and bottom boundaries, and all
  scrolling operations (up/down) will only affect the content within these boundaries.

  ## Operations

  * Setting and clearing scroll regions
  * Scrolling content up and down within the region
  * Getting region boundaries
  * Validating region boundaries
  * Managing content within the region
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Cell
  require Raxol.Core.Runtime.Log

  @doc """
  Sets the scroll region boundaries.
  The region must be valid (top < bottom) and within screen bounds.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `top` - The top boundary of the scroll region
  * `bottom` - The bottom boundary of the scroll region

  ## Returns

  The updated screen buffer with new scroll region boundaries.
  If the region is invalid, the scroll region is cleared.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScrollRegion.set_region(buffer, 5, 15)
      iex> ScrollRegion.get_region(buffer)
      {5, 15}

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScrollRegion.set_region(buffer, 15, 5)  # Invalid region
      iex> ScrollRegion.get_region(buffer)
      nil
  """
  @spec set_region(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) ::
          ScreenBuffer.t()
  def set_region(buffer, top, bottom)
      when top >= 0 and bottom < buffer.height and top < bottom do
    %{buffer | scroll_region: {top, bottom}}
  end

  def set_region(buffer, _top, _bottom), do: %{buffer | scroll_region: nil}

  @doc """
  Clears the scroll region, resetting to full screen.

  ## Parameters

  * `buffer` - The screen buffer to modify

  ## Returns

  The updated screen buffer with scroll region cleared.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScrollRegion.set_region(buffer, 5, 15)
      iex> buffer = ScrollRegion.clear(buffer)
      iex> ScrollRegion.get_region(buffer)
      nil
  """
  @spec clear(ScreenBuffer.t()) :: ScreenBuffer.t()
  def clear(buffer) do
    %{buffer | scroll_region: nil}
  end

  @doc """
  Gets the current scroll region boundaries.

  ## Parameters

  * `buffer` - The screen buffer to query

  ## Returns

  A tuple {top, bottom} representing the scroll region boundaries,
  or nil if no region is set.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> ScrollRegion.get_region(buffer)
      nil

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScrollRegion.set_region(buffer, 5, 15)
      iex> ScrollRegion.get_region(buffer)
      {5, 15}
  """
  @spec get_region(ScreenBuffer.t()) ::
          {non_neg_integer(), non_neg_integer()} | nil
  def get_region(%ScreenBuffer{scroll_region: region}), do: region

  @doc """
  Gets the current scroll region boundaries.
  Returns {0, height-1} if no region is set.

  ## Parameters

  * `buffer` - The screen buffer to query

  ## Returns

  A tuple {top, bottom} representing the effective scroll region boundaries.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> ScrollRegion.get_boundaries(buffer)
      {0, 23}

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScrollRegion.set_region(buffer, 5, 15)
      iex> ScrollRegion.get_boundaries(buffer)
      {5, 15}
  """
  @spec get_boundaries(ScreenBuffer.t()) ::
          {non_neg_integer(), non_neg_integer()}
  def get_boundaries(%ScreenBuffer{scroll_region: nil, height: height}) do
    {0, height - 1}
  end

  def get_boundaries(%ScreenBuffer{scroll_region: {top, bottom}}),
    do: {top, bottom}

  @doc """
  Scrolls the content up within the scroll region.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `lines` - The number of lines to scroll up
  * `scroll_region_arg` - Optional scroll region override

  ## Returns

  The updated screen buffer with content scrolled up.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScrollRegion.set_region(buffer, 5, 15)
      iex> buffer = ScrollRegion.scroll_up(buffer, 1)
      iex> # Content is scrolled up within region 5-15
  """
  @spec scroll_up(
          ScreenBuffer.t(),
          non_neg_integer(),
          {non_neg_integer(), non_neg_integer()} | nil
        ) :: ScreenBuffer.t()
  def scroll_up(buffer, lines, scroll_region_arg \\ nil) when lines > 0 do
    {scroll_start, scroll_end} = get_effective_region(buffer, scroll_region_arg)
    visible_lines = scroll_end - scroll_start + 1

    if lines >= visible_lines do
      clear_region(buffer, scroll_start, scroll_end)
    else
      scroll_region_up(buffer, scroll_start, scroll_end, lines)
    end
  end

  defp clear_region(buffer, start, ending) do
    visible_lines = ending - start + 1
    empty_region_cells = List.duplicate(List.duplicate(Cell.new(), buffer.width), visible_lines)
    updated_cells = replace_region_content(buffer.cells, start, ending, empty_region_cells)
    %{buffer | cells: updated_cells}
  end

  defp scroll_region_up(buffer, scroll_start, scroll_end, lines) do
    {before, region} = Enum.split(buffer.cells, scroll_start)
    {region, after_part} = Enum.split(region, scroll_end - scroll_start + 1)
    {scroll_lines, remaining} = Enum.split(region, lines)
    empty_line = List.duplicate(Cell.new(), buffer.width)
    new_region = remaining ++ List.duplicate(empty_line, length(scroll_lines))
    updated_cells = before ++ new_region ++ after_part
    %{buffer | cells: updated_cells}
  end

  @doc """
  Scrolls the content down within the scroll region.

  ## Parameters

  * `buffer` - The screen buffer to modify
  * `lines` - The number of lines to scroll down
  * `scroll_region_arg` - Optional scroll region override

  ## Returns

  The updated screen buffer with content scrolled down.

  ## Examples

      iex> buffer = ScreenBuffer.new(80, 24)
      iex> buffer = ScrollRegion.set_region(buffer, 5, 15)
      iex> buffer = ScrollRegion.scroll_down(buffer, 1)
      iex> # Content is scrolled down within region 5-15
  """
  @spec scroll_down(
          ScreenBuffer.t(),
          non_neg_integer(),
          {non_neg_integer(), non_neg_integer()} | nil
        ) :: ScreenBuffer.t()
  def scroll_down(buffer, lines, scroll_region_arg \\ nil) when lines > 0 do
    {scroll_start, scroll_end} = get_effective_region(buffer, scroll_region_arg)
    visible_lines = scroll_end - scroll_start + 1

    if lines >= visible_lines do
      clear_region(buffer, scroll_start, scroll_end)
    else
      scroll_region_down(buffer, scroll_start, scroll_end, lines)
    end
  end

  defp scroll_region_down(buffer, scroll_start, scroll_end, lines) do
    {before, region} = Enum.split(buffer.cells, scroll_start)
    {region, after_part} = Enum.split(region, scroll_end - scroll_start + 1)
    {remaining, scroll_lines} = Enum.split(region, length(region) - lines)
    empty_line = List.duplicate(Cell.new(), buffer.width)
    new_region = List.duplicate(empty_line, length(scroll_lines)) ++ remaining
    updated_cells = before ++ new_region ++ after_part
    %{buffer | cells: updated_cells}
  end

  @doc """
  Replaces the content of a region in the buffer with new content.

  ## Parameters

  * `cells` - The current cells in the buffer
  * `start_line` - The starting line of the region to replace
  * `end_line` - The ending line of the region to replace
  * `new_content` - The new content to insert in the region

  ## Returns

  The updated cells with the region replaced.

  ## Examples

      iex> cells = [[%Cell{char: "A"}, %Cell{char: "B"}], [%Cell{char: "C"}, %Cell{char: "D"}]]
      iex> new_content = [[%Cell{char: "X"}, %Cell{char: "Y"}], [%Cell{char: "Z"}, %Cell{char: "W"}]]
      iex> ScrollRegion.replace_region_content(cells, 0, 1, new_content)
      [[%Cell{char: "X"}, %Cell{char: "Y"}], [%Cell{char: "Z"}, %Cell{char: "W"}]]
  """
  @spec replace_region_content(
          list(list(Cell.t())),
          non_neg_integer(),
          non_neg_integer(),
          list(list(Cell.t()))
        ) :: list(list(Cell.t()))
  def replace_region_content(cells, start_line, end_line, new_content) do
    {before, after_part} = Enum.split(cells, start_line)
    {_, after_part} = Enum.split(after_part, end_line - start_line + 1)
    before ++ new_content ++ after_part
  end

  defp get_effective_region(buffer, scroll_region_arg) do
    case scroll_region_arg do
      {start, ending} when is_integer(start) and start >= 0 and is_integer(ending) and ending >= start ->
        clamp_region({start, ending}, buffer.height)
      _ ->
        get_buffer_region(buffer)
    end
  end

  defp clamp_region({start, ending}, height), do: {start, min(height - 1, ending)}

  defp get_buffer_region(%ScreenBuffer{scroll_region: region, height: height}) do
    case region do
      {start, ending} when is_integer(start) and start >= 0 and is_integer(ending) and ending >= start ->
        clamp_region({start, ending}, height)
      _ ->
        {0, height - 1}
    end
  end
end
