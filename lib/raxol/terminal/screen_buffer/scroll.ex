defmodule Raxol.Terminal.ScreenBuffer.Scroll do
  @moduledoc """
  Scroll operations for the screen buffer.

  Handles scrolling content, scroll regions, scrollback buffer management,
  and cursor index operations.
  """

  alias Raxol.Terminal.Cell

  # ==========================================================================
  # Scroll Region Management
  # ==========================================================================

  @doc """
  Sets the scroll region boundaries.

  The scroll region defines which portion of the screen participates in
  scrolling operations. Lines outside the region remain fixed.
  """
  @spec set_scroll_region(map(), non_neg_integer(), non_neg_integer()) :: map()
  def set_scroll_region(buffer, top, bottom)
      when is_integer(top) and is_integer(bottom) do
    top = max(0, top)
    bottom = min(bottom, buffer.height - 1)

    if top < bottom do
      %{buffer | scroll_region: {top, bottom}}
    else
      buffer
    end
  end

  @doc """
  Gets the current scroll region.

  Returns `nil` if no region is set (full screen scrolling).
  """
  @spec get_scroll_region(map()) :: {non_neg_integer(), non_neg_integer()} | nil
  def get_scroll_region(%{scroll_region: region}), do: region

  # ==========================================================================
  # Basic Scroll Operations
  # ==========================================================================

  @doc """
  Scrolls the buffer up by one line.
  """
  @spec scroll_up(map()) :: map()
  def scroll_up(buffer), do: scroll_up(buffer, 1)

  @doc """
  Scrolls the buffer up by n lines within the scroll region.

  Lines scrolled out the top are optionally saved to scrollback.
  New blank lines appear at the bottom of the scroll region.
  """
  @spec scroll_up(map(), non_neg_integer()) :: map()
  def scroll_up(buffer, n) when is_integer(n) and n > 0 do
    {top, bottom} = get_effective_scroll_region(buffer)
    do_scroll_up(buffer, n, top, bottom)
  end

  def scroll_up(buffer, _), do: buffer

  @doc """
  Scrolls the buffer down by one line.
  """
  @spec scroll_down(map()) :: map()
  def scroll_down(buffer), do: scroll_down(buffer, 1)

  @doc """
  Scrolls the buffer down by n lines within the scroll region.

  Lines scrolled out the bottom are discarded.
  New blank lines appear at the top of the scroll region.
  """
  @spec scroll_down(map(), non_neg_integer()) :: map()
  def scroll_down(buffer, n) when is_integer(n) and n > 0 do
    {top, bottom} = get_effective_scroll_region(buffer)
    do_scroll_down(buffer, n, top, bottom)
  end

  def scroll_down(buffer, _), do: buffer

  @doc """
  Scrolls up within a specific region.
  """
  @spec scroll_region_up(
          map(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: map()
  def scroll_region_up(buffer, top, bottom, n) when n > 0 do
    do_scroll_up(buffer, n, top, bottom)
  end

  def scroll_region_up(buffer, _, _, _), do: buffer

  @doc """
  Scrolls down within a specific region.
  """
  @spec scroll_region_down(
          map(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) ::
          map()
  def scroll_region_down(buffer, top, bottom, n) when n > 0 do
    do_scroll_down(buffer, n, top, bottom)
  end

  def scroll_region_down(buffer, _, _, _), do: buffer

  # ==========================================================================
  # Scrollback Buffer Management
  # ==========================================================================

  @doc """
  Saves lines to the scrollback buffer.

  Lines are prepended to scrollback, with oldest lines trimmed if
  scrollback_limit is exceeded.
  """
  @spec save_to_scrollback(map(), list()) :: map()
  def save_to_scrollback(buffer, lines) when is_list(lines) do
    scrollback = buffer.scrollback || []
    limit = buffer.scrollback_limit || 1000

    new_scrollback =
      (lines ++ scrollback)
      |> Enum.take(limit)

    %{buffer | scrollback: new_scrollback}
  end

  @doc """
  Adds a single line to the scrollback buffer.

  Unlike save_to_scrollback/2 which accepts multiple lines,
  this function adds exactly one line.
  """
  @spec add_to_scrollback(map(), list()) :: map()
  def add_to_scrollback(buffer, line) when is_list(line) do
    save_to_scrollback(buffer, [line])
  end

  @doc """
  Clears the scrollback buffer.
  """
  @spec clear_scrollback(map()) :: map()
  def clear_scrollback(buffer) do
    %{buffer | scrollback: [], scroll_position: 0}
  end

  @doc """
  Gets the entire scrollback buffer.
  """
  @spec get_scrollback(map()) :: list()
  def get_scrollback(buffer), do: buffer.scrollback || []

  @doc """
  Gets the scrollback buffer, limited to n lines.
  """
  @spec get_scrollback(map(), non_neg_integer()) :: list()
  def get_scrollback(buffer, limit) when is_integer(limit) and limit >= 0 do
    (buffer.scrollback || [])
    |> Enum.take(limit)
  end

  # ==========================================================================
  # Scroll Position Management
  # ==========================================================================

  @doc """
  Sets the scroll position (for viewing scrollback).

  Position 0 means viewing the current screen (no scrollback visible).
  Higher values scroll back through history.
  """
  @spec set_scroll_position(map(), non_neg_integer()) :: map()
  def set_scroll_position(buffer, position)
      when is_integer(position) and position >= 0 do
    scrollback_length = length(buffer.scrollback || [])
    clamped_position = min(position, scrollback_length)
    %{buffer | scroll_position: clamped_position}
  end

  @doc """
  Gets the current scroll position.
  """
  @spec get_scroll_position(map()) :: non_neg_integer()
  def get_scroll_position(buffer), do: buffer.scroll_position || 0

  @doc """
  Scrolls to the bottom (current screen, no scrollback visible).
  """
  @spec scroll_to_bottom(map()) :: map()
  def scroll_to_bottom(buffer) do
    %{buffer | scroll_position: 0}
  end

  @doc """
  Scrolls to the top of the scrollback buffer.
  """
  @spec scroll_to_top(map()) :: map()
  def scroll_to_top(buffer) do
    scrollback_length = length(buffer.scrollback || [])
    %{buffer | scroll_position: scrollback_length}
  end

  @doc """
  Gets the visible lines based on current scroll position.

  When scroll_position is 0, returns the current screen.
  When scrolled back, mixes scrollback lines with screen lines.
  """
  @spec get_visible_lines(map()) :: list()
  def get_visible_lines(buffer) do
    scroll_pos = buffer.scroll_position || 0

    if scroll_pos == 0 do
      buffer.cells || []
    else
      scrollback = buffer.scrollback || []
      cells = buffer.cells || []
      height = buffer.height

      # Take lines from scrollback and current buffer
      scrollback_lines = Enum.slice(scrollback, 0, scroll_pos)
      screen_lines = Enum.take(cells, height - scroll_pos)

      scrollback_lines ++ screen_lines
    end
  end

  # ==========================================================================
  # Index Operations (VT100 IND/RI)
  # ==========================================================================

  @doc """
  Index operation (IND) - moves cursor down, scrolling if at bottom margin.

  If cursor is at the bottom margin of the scroll region, scrolls content up.
  Otherwise, moves cursor down one line.
  """
  @spec index(map()) :: map()
  def index(buffer) do
    {cursor_x, cursor_y} = buffer.cursor_position
    {_top, bottom} = get_effective_scroll_region(buffer)

    if cursor_y >= bottom do
      scroll_up(buffer, 1)
    else
      %{buffer | cursor_position: {cursor_x, cursor_y + 1}}
    end
  end

  @doc """
  Reverse index operation (RI) - moves cursor up, scrolling if at top margin.

  If cursor is at the top margin of the scroll region, scrolls content down.
  Otherwise, moves cursor up one line.
  """
  @spec reverse_index(map()) :: map()
  def reverse_index(buffer) do
    {cursor_x, cursor_y} = buffer.cursor_position
    {top, _bottom} = get_effective_scroll_region(buffer)

    if cursor_y <= top do
      scroll_down(buffer, 1)
    else
      %{buffer | cursor_position: {cursor_x, cursor_y - 1}}
    end
  end

  # ==========================================================================
  # Private Helpers
  # ==========================================================================

  defp get_effective_scroll_region(buffer) do
    case buffer.scroll_region do
      nil -> {0, buffer.height - 1}
      {top, bottom} -> {max(0, top), min(bottom, buffer.height - 1)}
    end
  end

  defp do_scroll_up(buffer, n, top, bottom) when top < bottom do
    cells = buffer.cells || []
    region_height = bottom - top + 1
    lines_to_scroll = min(n, region_height)

    # Split buffer into three parts
    {before_region, region_and_after} = Enum.split(cells, top)
    {region, after_region} = Enum.split(region_and_after, region_height)

    # Lines that will be scrolled out (for potential scrollback)
    scrolled_out = Enum.take(region, lines_to_scroll)

    # Remove top lines, add empty lines at bottom
    remaining_region = Enum.drop(region, lines_to_scroll)
    empty_lines = create_empty_lines(buffer.width, lines_to_scroll)
    new_region = remaining_region ++ empty_lines

    # Reconstruct buffer
    new_cells = before_region ++ new_region ++ after_region

    # Save to scrollback if scrolling from the top of the screen
    buffer =
      if top == 0 do
        save_to_scrollback(buffer, scrolled_out)
      else
        buffer
      end

    %{buffer | cells: new_cells}
  end

  defp do_scroll_up(buffer, _, _, _), do: buffer

  defp do_scroll_down(buffer, n, top, bottom) when top < bottom do
    cells = buffer.cells || []
    region_height = bottom - top + 1
    lines_to_scroll = min(n, region_height)

    # Split buffer into three parts
    {before_region, region_and_after} = Enum.split(cells, top)
    {region, after_region} = Enum.split(region_and_after, region_height)

    # Add empty lines at top, remove bottom lines
    empty_lines = create_empty_lines(buffer.width, lines_to_scroll)
    remaining_region = Enum.take(region, region_height - lines_to_scroll)
    new_region = empty_lines ++ remaining_region

    # Reconstruct buffer
    new_cells = before_region ++ new_region ++ after_region

    %{buffer | cells: new_cells}
  end

  defp do_scroll_down(buffer, _, _, _), do: buffer

  defp create_empty_lines(width, count) when count > 0 do
    empty_line = List.duplicate(Cell.empty(), width)
    List.duplicate(empty_line, count)
  end

  defp create_empty_lines(_, _), do: []
end
