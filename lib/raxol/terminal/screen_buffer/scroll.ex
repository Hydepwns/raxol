defmodule Raxol.Terminal.ScreenBuffer.Scroll do
  @moduledoc """
  Deprecated: This module is not used in the codebase.

  Originally intended to consolidate scrolling operations but never integrated.
  Scroll operations are handled by `Raxol.Terminal.Buffer.Scroller` instead.
  """

  alias Raxol.Terminal.Cell

  @doc """
  Sets the scroll region.
  """
  def set_scroll_region(buffer, nil, nil) do
    %{buffer | scroll_region: nil}
  end

  def set_scroll_region(buffer, top, bottom)
      when is_integer(top) and is_integer(bottom) do
    top = max(0, min(top, buffer.height - 1))
    bottom = max(top, min(bottom, buffer.height - 1))
    %{buffer | scroll_region: {top, bottom}}
  end

  @doc """
  Gets the effective scroll region.
  """
  def get_scroll_region(buffer) do
    case buffer.scroll_region do
      nil -> {0, buffer.height - 1}
      {top, bottom} -> {top, bottom}
    end
  end

  @doc """
  Scrolls the buffer or scroll region up by n lines.
  """
  def scroll_up(buffer, n \\ 1) when n > 0 do
    {top, bottom} = get_scroll_region(buffer)
    scroll_region_up(buffer, top, bottom, n)
  end

  @doc """
  Scrolls the buffer or scroll region down by n lines.
  """
  def scroll_down(buffer, n \\ 1) when n > 0 do
    {top, bottom} = get_scroll_region(buffer)
    scroll_region_down(buffer, top, bottom, n)
  end

  @doc """
  Scrolls the specified region up by n lines.
  """
  def scroll_up(buffer, top, bottom, lines) do
    scroll_region_up(buffer, top, bottom, lines)
  end

  @doc """
  Scrolls the specified region down by n lines.
  """
  def scroll_down(buffer, top, bottom, lines) do
    scroll_region_down(buffer, top, bottom, lines)
  end

  @doc """
  Scrolls up within a specific region.
  """
  def scroll_region_up(buffer, top, bottom, n) when n > 0 do
    n = min(n, bottom - top + 1)

    # Save lines that will be scrolled out to scrollback
    buffer =
      if top == 0 do
        save_to_scrollback(buffer, Enum.take(buffer.cells, n))
      else
        buffer
      end

    # Shift lines up within the region
    {before_region, region_and_after} = Enum.split(buffer.cells, top)
    {region, after_region} = Enum.split(region_and_after, bottom - top + 1)

    # Drop n lines from top of region and add n empty lines at bottom
    new_region = Enum.drop(region, n) ++ create_empty_lines(n, buffer.width)

    new_cells = before_region ++ new_region ++ after_region

    %{
      buffer
      | cells: new_cells,
        damage_regions: [{0, top, buffer.width - 1, bottom}]
    }
  end

  @doc """
  Scrolls down within a specific region.
  """
  def scroll_region_down(buffer, top, bottom, n) when n > 0 do
    n = min(n, bottom - top + 1)

    # Shift lines down within the region
    {before_region, region_and_after} = Enum.split(buffer.cells, top)
    {region, after_region} = Enum.split(region_and_after, bottom - top + 1)

    # Add n empty lines at top of region and drop n lines from bottom
    new_region =
      create_empty_lines(n, buffer.width) ++
        Enum.take(region, length(region) - n)

    new_cells = before_region ++ new_region ++ after_region

    %{
      buffer
      | cells: new_cells,
        damage_regions: [{0, top, buffer.width - 1, bottom}]
    }
  end

  @doc """
  Saves lines to scrollback buffer.
  """
  def save_to_scrollback(buffer, lines) do
    new_scrollback = lines ++ buffer.scrollback
    trimmed_scrollback = Enum.take(new_scrollback, buffer.scrollback_limit)
    %{buffer | scrollback: trimmed_scrollback}
  end

  @doc """
  Clears the scrollback buffer.
  """
  def clear_scrollback(buffer) do
    %{buffer | scrollback: []}
  end

  @doc """
  Gets scrollback lines.
  """
  def get_scrollback(buffer, limit \\ nil) do
    case limit do
      nil -> buffer.scrollback
      n when is_integer(n) -> Enum.take(buffer.scrollback, n)
    end
  end

  @doc """
  Adds a line to the scrollback buffer (alias for save_to_scrollback).
  """
  def add_to_scrollback(buffer, line) do
    save_to_scrollback(buffer, [line])
  end

  @doc """
  Gets a specific line from the scrollback buffer.
  """
  def get_scrollback_line(buffer, index) do
    Enum.at(buffer.scrollback, index)
  end

  @doc """
  Clears the scroll region (sets it to nil).
  """
  def clear_scroll_region(buffer) do
    %{buffer | scroll_region: nil}
  end

  @doc """
  Sets the scroll position for viewing scrollback.
  """
  def set_scroll_position(buffer, position) do
    max_position = length(buffer.scrollback)
    position = max(0, min(position, max_position))
    %{buffer | scroll_position: position}
  end

  @doc """
  Gets the current scroll position.
  """
  def get_scroll_position(buffer) do
    buffer.scroll_position
  end

  @doc """
  Scrolls to the bottom (most recent content).
  """
  def scroll_to_bottom(buffer) do
    %{buffer | scroll_position: 0}
  end

  @doc """
  Scrolls to the top (oldest scrollback).
  """
  def scroll_to_top(buffer) do
    %{buffer | scroll_position: length(buffer.scrollback)}
  end

  @doc """
  Gets visible lines including scrollback based on scroll position.
  """
  def get_visible_lines(buffer) do
    if buffer.scroll_position == 0 do
      # Normal view - just the current screen
      buffer.cells
    else
      # Showing scrollback
      scrollback_to_show = Enum.take(buffer.scrollback, buffer.scroll_position)
      visible_from_current = buffer.height - length(scrollback_to_show)

      if visible_from_current > 0 do
        # Show some scrollback and some current screen
        scrollback_to_show ++ Enum.take(buffer.cells, visible_from_current)
      else
        # Show only scrollback
        Enum.take(scrollback_to_show, buffer.height)
      end
    end
  end

  @doc """
  Performs a reverse index (scroll down if at top of scroll region).
  """
  def reverse_index(buffer) do
    {_x, y} = buffer.cursor_position
    {top, _bottom} = get_scroll_region(buffer)

    if y == top do
      scroll_down(buffer, 1)
    else
      buffer
    end
  end

  @doc """
  Performs an index (scroll up if at bottom of scroll region).
  """
  def index(buffer) do
    {_x, y} = buffer.cursor_position
    {_top, bottom} = get_scroll_region(buffer)

    if y == bottom do
      scroll_up(buffer, 1)
    else
      buffer
    end
  end

  # Private helper functions

  defp create_empty_lines(n, width) do
    for _ <- 1..n do
      List.duplicate(Cell.empty(), width)
    end
  end
end
