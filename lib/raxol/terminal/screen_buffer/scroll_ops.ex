defmodule Raxol.Terminal.ScreenBuffer.ScrollOps do
  @moduledoc false

  alias Raxol.Terminal.ScreenBuffer.Operations

  def scroll_to(buffer, top, bottom, line) do
    Operations.scroll_to(buffer, top, bottom, line)
  end

  def reset_scroll_region(buffer) do
    clear_scroll_region(buffer)
  end

  def get_scroll_top(buffer) do
    case buffer.scroll_region do
      nil -> 0
      {top, _} -> top
    end
  end

  def get_scroll_bottom(buffer) do
    case buffer.scroll_region do
      nil -> buffer.height - 1
      {_, bottom} -> bottom
    end
  end

  def set_scroll_region(buffer, {top, bottom}) do
    Operations.set_region(buffer, top, bottom)
  end

  def set_scroll_region(buffer, top, bottom)
      when is_integer(top) and is_integer(bottom) do
    Operations.set_region(buffer, top, bottom)
  end

  def clear_scroll_region(buffer) do
    %{buffer | scroll_region: nil}
  end

  def get_scroll_region_boundaries(buffer) do
    case buffer.scroll_region do
      nil -> {0, buffer.height - 1}
      {top, bottom} -> {top, bottom}
    end
  end

  def get_scroll_position(buffer) do
    buffer.scroll_position || 0
  end

  def get_scroll_region(buffer), do: Operations.get_region(buffer)

  def shift_region_to_line(buffer, region, target_line) do
    Operations.shift_region_to_line(buffer, region, target_line)
  end

  def scroll_down_with_count(buffer, lines, count)
      when is_integer(lines) and is_integer(count) do
    Raxol.Terminal.Commands.Scrolling.scroll_down(
      buffer,
      lines,
      buffer.scroll_region,
      %{}
    )
  end

  def scroll_down_with_count(buffer, _lines, count) when is_integer(count) do
    Raxol.Terminal.ScreenBuffer.Scrolling.scroll_down(buffer, count)
  end
end
