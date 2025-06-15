defmodule Raxol.Terminal.Buffer.Scroller do
  @moduledoc """
  Handles scrolling operations for the terminal buffer.
  """

  require Raxol.Core.Runtime.Log

  alias Raxol.Terminal.ScreenBuffer

  @doc """
  Scrolls the buffer up by the specified number of lines.
  """
  def scroll_up(buffer, count) do
    do_scroll_up(buffer, count)
  end

  @doc """
  Scrolls the buffer down by the specified number of lines.
  """
  def scroll_down(buffer, count) do
    do_scroll_down(buffer, count)
  end

  @doc """
  Gets the scroll top position.
  """
  def get_scroll_top(_buffer, scroll_margins) do
    scroll_margins.top
  end

  @doc """
  Gets the scroll bottom position.
  """
  def get_scroll_bottom(_buffer, scroll_margins) do
    scroll_margins.bottom
  end

  # Private helper functions

  defp do_scroll_up(buffer, count) do
    case buffer.scroll_region do
      nil ->
        scroll_entire_buffer_up(buffer, count)
      region ->
        scroll_region_up(buffer, count, region.top, region.bottom)
    end
  end

  defp do_scroll_down(buffer, count) do
    case buffer.scroll_region do
      nil ->
        scroll_entire_buffer_down(buffer, count)
      region ->
        scroll_region_down(buffer, count, region.top, region.bottom)
    end
  end

  defp scroll_region_up(buffer, count, top, bottom) do
    region_lines = Enum.slice(buffer.content, top..bottom)
    {_to_scroll, remaining} = Enum.split(region_lines, count)
    empty_lines = List.duplicate(List.duplicate(%{}, buffer.width), count)
    new_region = remaining ++ empty_lines
    new_content = List.replace_at(buffer.content, top, new_region)
    {:ok, %{buffer | content: new_content}}
  end

  defp scroll_region_down(buffer, count, top, bottom) do
    region_lines = Enum.slice(buffer.content, top..bottom)
    {remaining, _to_scroll} = Enum.split(region_lines, -count)
    empty_lines = List.duplicate(List.duplicate(%{}, buffer.width), count)
    new_region = empty_lines ++ remaining
    new_content = List.replace_at(buffer.content, top, new_region)
    {:ok, %{buffer | content: new_content}}
  end

  defp scroll_entire_buffer_up(buffer, count) do
    {_to_scrollback, new_buffer} = ScreenBuffer.pop_bottom_lines(buffer, count)
    empty_lines = List.duplicate(List.duplicate(%{}, buffer.width), count)
    new_content = empty_lines ++ new_buffer.content
    {:ok, %{new_buffer | content: new_content}}
  end

  defp scroll_entire_buffer_down(buffer, count) do
    {_to_scrollback, new_buffer} = ScreenBuffer.pop_bottom_lines(buffer, count)
    empty_lines = List.duplicate(List.duplicate(%{}, buffer.width), count)
    new_content = new_buffer.content ++ empty_lines
    {:ok, %{new_buffer | content: new_content}}
  end
end
