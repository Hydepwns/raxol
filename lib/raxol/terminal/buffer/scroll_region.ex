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
      {5, 15}
  """
  @spec set_region(ScreenBuffer.t(), non_neg_integer(), non_neg_integer()) ::
          ScreenBuffer.t()
  def set_region(buffer, top, bottom) do
    # Check for invalid regions
    cond do
      # Negative values
      top < 0 or bottom < 0 ->
        %{buffer | scroll_region: nil, scroll_position: 0}

      # Top > bottom
      top > bottom ->
        %{buffer | scroll_region: nil, scroll_position: 0}

      # Bottom >= height (out of bounds)
      bottom >= buffer.height ->
        %{buffer | scroll_region: nil, scroll_position: 0}

      # Valid region
      true ->
        %{buffer | scroll_region: {top, bottom}, scroll_position: top}
    end
  end

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
  @impl Raxol.Terminal.ScreenBufferBehaviour
  @spec clear(ScreenBuffer.t()) :: ScreenBuffer.t()
  def clear(buffer) do
    %{buffer | scroll_region: nil}
  end

  @doc """
  Clears the scroll region, resetting to full screen.
  Alias for clear/1 for backward compatibility.
  """
  @spec clear_region(ScreenBuffer.t()) :: ScreenBuffer.t()
  def clear_region(buffer) do
    clear(buffer)
  end

  @doc """
  Gets the current scroll region boundaries.

  ## Parameters

  * `buffer` - The screen buffer to query

  ## Returns

  A tuple {top, bottom} representing the scroll region boundaries.
  Returns nil if no region is set.

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
  def get_region(%ScreenBuffer{scroll_region: nil}) do
    nil
  end

  def get_region(%ScreenBuffer{scroll_region: {top, bottom}}) do
    {top, bottom}
  end

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
  @impl Raxol.Terminal.ScreenBufferBehaviour
  @spec scroll_up(
          ScreenBuffer.t(),
          non_neg_integer(),
          {non_neg_integer(), non_neg_integer()} | nil
        ) :: {ScreenBuffer.t(), list(list(Cell.t()))}
  def scroll_up(buffer, lines, scroll_region_arg \\ nil) when lines > 0 do
    {scroll_start, scroll_end} = get_effective_region(buffer, scroll_region_arg)
    visible_lines = scroll_end - scroll_start + 1

    if lines >= visible_lines do
      scrolled_lines =
        extract_lines_from_region(buffer, scroll_start, scroll_end)

      {clear_region(buffer, scroll_start, scroll_end), scrolled_lines}
    else
      scroll_region_up_with_lines(buffer, scroll_start, scroll_end, lines)
    end
  end

  def scroll_up(buffer, lines, _scroll_region_arg) when lines <= 0 do
    buffer
  end

  defp clear_region(buffer, start, ending) do
    visible_lines = ending - start + 1

    empty_region_cells =
      List.duplicate(List.duplicate(Cell.new(), buffer.width), visible_lines)

    updated_cells =
      replace_region_content(buffer.cells, start, ending, empty_region_cells)

    %{buffer | cells: updated_cells}
  end

  defp scroll_region_up_with_lines(buffer, scroll_start, scroll_end, lines) do
    # Extract the lines that will be scrolled out
    scrolled_lines =
      extract_lines_from_region(buffer, scroll_start, scroll_start + lines - 1)

    # Pre-create a single empty line to reuse
    empty_line = List.duplicate(Cell.new(), buffer.width)

    # Transform cells using helper function
    new_cells =
      transform_cells_for_scroll_up(
        buffer.cells,
        scroll_start,
        scroll_end,
        lines,
        empty_line
      )

    {%{buffer | cells: new_cells}, scrolled_lines}
  end

  defp transform_cells_for_scroll_up(
         cells,
         scroll_start,
         scroll_end,
         lines,
         empty_line
       ) do
    cells
    |> Enum.with_index()
    |> Enum.map(fn {line, idx} ->
      transform_line_for_scroll_up(
        line,
        idx,
        cells,
        scroll_start,
        scroll_end,
        lines,
        empty_line
      )
    end)
  end

  defp transform_line_for_scroll_up(
         line,
         idx,
         cells,
         scroll_start,
         scroll_end,
         lines,
         empty_line
       ) do
    cond do
      idx < scroll_start ->
        line

      idx >= scroll_start and idx <= scroll_end - lines ->
        Enum.at(cells, idx + lines, empty_line)

      idx > scroll_end - lines and idx <= scroll_end ->
        empty_line

      true ->
        line
    end
  end

  defp scroll_region_up(buffer, scroll_start, scroll_end, lines) do
    scroll_region_direction(buffer, scroll_start, scroll_end, lines, :up)
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
  @impl Raxol.Terminal.ScreenBufferBehaviour
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

  def scroll_down(buffer, lines, _scroll_region_arg) when lines <= 0 do
    buffer
  end

  defp scroll_region_down(buffer, scroll_start, scroll_end, lines) do
    scroll_region_direction(buffer, scroll_start, scroll_end, lines, :down)
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

  defp extract_lines_from_region(buffer, start_line, end_line) do
    Enum.map(start_line..end_line, fn i ->
      if i < length(buffer.cells) do
        Enum.at(buffer.cells, i, [])
      else
        []
      end
    end)
    |> Enum.filter(fn line -> line != [] end)
  end

  # Unified helper for scrolling in both directions
  defp scroll_region_direction(
         buffer,
         scroll_start,
         scroll_end,
         lines,
         direction
       ) do
    # Pre-create a single empty line to reuse
    empty_line = List.duplicate(Cell.new(), buffer.width)

    # Transform cells using helper function
    new_cells =
      transform_cells_for_direction(
        buffer.cells,
        scroll_start,
        scroll_end,
        lines,
        direction,
        empty_line
      )

    %{buffer | cells: new_cells}
  end

  defp transform_cells_for_direction(
         cells,
         scroll_start,
         scroll_end,
         lines,
         direction,
         empty_line
       ) do
    cells
    |> Enum.with_index()
    |> Enum.map(fn {line, idx} ->
      transform_line_for_direction(
        line,
        idx,
        cells,
        scroll_start,
        scroll_end,
        lines,
        direction,
        empty_line
      )
    end)
  end

  defp transform_line_for_direction(
         line,
         idx,
         cells,
         scroll_start,
         scroll_end,
         lines,
         direction,
         empty_line
       ) do
    if idx < scroll_start do
      line
    else
      transform_line_in_region(
        idx,
        cells,
        scroll_start,
        scroll_end,
        lines,
        direction,
        empty_line
      )
    end
  end

  defp transform_line_in_region(
         idx,
         cells,
         scroll_start,
         scroll_end,
         lines,
         direction,
         empty_line
       ) do
    case direction do
      :up ->
        transform_line_for_up_scroll(
          idx,
          cells,
          scroll_start,
          scroll_end,
          lines,
          empty_line
        )

      :down ->
        transform_line_for_down_scroll(
          idx,
          cells,
          scroll_start,
          scroll_end,
          lines,
          empty_line
        )
    end
  end

  defp transform_line_for_up_scroll(
         idx,
         cells,
         scroll_start,
         scroll_end,
         lines,
         empty_line
       ) do
    cond do
      idx <= scroll_end - lines ->
        get_moved_line(cells, idx, lines, :up, empty_line)

      idx <= scroll_end ->
        empty_line

      true ->
        Enum.at(cells, idx, empty_line)
    end
  end

  defp transform_line_for_down_scroll(
         idx,
         cells,
         scroll_start,
         scroll_end,
         lines,
         empty_line
       ) do
    cond do
      idx < scroll_start + lines -> empty_line
      idx <= scroll_end -> get_moved_line(cells, idx, lines, :down, empty_line)
      true -> Enum.at(cells, idx, empty_line)
    end
  end

  defp get_moved_line(cells, idx, lines, direction, empty_line) do
    case direction do
      :up -> Enum.at(cells, idx + lines, empty_line)
      :down -> Enum.at(cells, idx - lines, empty_line)
    end
  end

  defp get_effective_region(buffer, scroll_region_arg) do
    case scroll_region_arg do
      {start, ending}
      when is_integer(start) and start >= 0 and is_integer(ending) and
             ending >= start ->
        clamp_region({start, ending}, buffer.height)

      _ ->
        get_buffer_region(buffer)
    end
  end

  defp clamp_region({start, ending}, height),
    do: {start, min(height - 1, ending)}

  defp get_buffer_region(%ScreenBuffer{scroll_region: region, height: height}) do
    case region do
      {start, ending}
      when is_integer(start) and start >= 0 and is_integer(ending) and
             ending >= start ->
        clamp_region({start, ending}, height)

      _ ->
        {0, height - 1}
    end
  end

  def scroll_to(buffer, top, bottom, line) do
    {top, bottom} = clamp_region({top, bottom}, buffer.height)
    line = max(top, min(line, bottom))
    %{buffer | scroll_position: line}
  end

  @doc """
  Gets the current scroll position within the scroll region.
  """
  @impl Raxol.Terminal.ScreenBufferBehaviour
  @spec get_scroll_position(ScreenBuffer.t()) :: non_neg_integer()
  def get_scroll_position(%ScreenBuffer{scroll_position: position}) do
    position
  end

  @doc """
  Gets the dimensions of the buffer.
  """
  @spec get_dimensions(ScreenBuffer.t()) ::
          {non_neg_integer(), non_neg_integer()}
  def get_dimensions(%ScreenBuffer{width: width, height: height}) do
    {width, height}
  end

  @doc """
  Gets the height of the buffer.
  """
  @spec get_height(ScreenBuffer.t()) :: non_neg_integer()
  def get_height(%ScreenBuffer{height: height}) do
    height
  end

  @doc """
  Gets the width of the buffer.
  """
  @spec get_width(ScreenBuffer.t()) :: non_neg_integer()
  def get_width(%ScreenBuffer{width: width}) do
    width
  end

  @doc """
  Gets the scroll bottom boundary.
  """
  @spec get_scroll_bottom(ScreenBuffer.t()) :: non_neg_integer()
  def get_scroll_bottom(%ScreenBuffer{scroll_region: nil, height: height}) do
    height - 1
  end

  def get_scroll_bottom(%ScreenBuffer{scroll_region: {_top, bottom}}) do
    bottom
  end

  @doc """
  Gets the scroll top boundary.
  """
  @spec get_scroll_top(ScreenBuffer.t()) :: non_neg_integer()
  def get_scroll_top(%ScreenBuffer{scroll_region: nil}) do
    0
  end

  def get_scroll_top(%ScreenBuffer{scroll_region: {top, _bottom}}) do
    top
  end

  @doc """
  Shifts the content in the scroll region so that the content of the given target line appears at the top of the region.
  Fills with blank lines as needed if the shift would go out of bounds.
  """
  @spec shift_region_to_line(
          ScreenBuffer.t(),
          {non_neg_integer(), non_neg_integer()},
          non_neg_integer()
        ) :: ScreenBuffer.t()
  def shift_region_to_line(buffer, {top, bottom}, target_line) do
    {top, bottom} = clamp_region({top, bottom}, buffer.height)
    target_line = max(top, min(target_line, bottom))
    shift = target_line - top

    new_cells = shift_region_content(buffer.cells, top, bottom, shift)
    %{buffer | cells: new_cells, scroll_position: target_line}
  end

  defp shift_region_content(cells, top, bottom, shift) do
    region_height = bottom - top + 1
    {before, region} = Enum.split(cells, top)
    {region, after_part} = Enum.split(region, region_height)

    {to_shift, remaining} = Enum.split(region, shift)
    empty_line = List.duplicate(Cell.new(), length(hd(cells)))
    new_region = remaining ++ List.duplicate(empty_line, length(to_shift))

    before ++ new_region ++ after_part
  end
end
