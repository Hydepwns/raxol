defmodule Raxol.Terminal.Operations.ScrollOperations do
  @moduledoc """
  Implements scroll-related operations for the terminal emulator.
  """

  alias Raxol.Terminal.{ScreenManager, ScreenBuffer, Operations.TextOperations}

  def get_scroll_region(emulator) do
    buffer = ScreenManager.get_active_buffer(emulator)
    ScreenManager.get_scroll_region(buffer)
  end

  def set_scroll_region(emulator, region) do
    buffer = ScreenManager.get_active_buffer(emulator)
    new_buffer = ScreenManager.set_scroll_region(buffer, region)
    ScreenManager.update_active_buffer(emulator, new_buffer)
  end

  def set_scroll_region(emulator, start_line, end_line) do
    buffer = ScreenManager.get_active_buffer(emulator)
    new_buffer = ScreenManager.set_scroll_region(buffer, {start_line, end_line})
    ScreenManager.update_active_buffer(emulator, new_buffer)
  end

  def get_scroll_top(emulator) do
    buffer = ScreenManager.get_active_buffer(emulator)
    ScreenManager.get_scroll_top(buffer)
  end

  def get_scroll_bottom(emulator) do
    buffer = ScreenManager.get_active_buffer(emulator)
    ScreenManager.get_scroll_bottom(buffer)
  end

  def write_string(emulator, x, y, string, style) do
    TextOperations.write_string(emulator, x, y, string, style)
  end

  def scroll_up(emulator, lines) do
    buffer = ScreenManager.get_active_buffer(emulator)
    {top, bottom} = ScreenManager.get_scroll_region(buffer)
    new_buffer = ScreenBuffer.scroll_up(buffer, top, bottom, lines)
    ScreenManager.update_active_buffer(emulator, new_buffer)
  end

  def scroll_down(emulator, lines) do
    buffer = ScreenManager.get_active_buffer(emulator)
    {top, bottom} = ScreenManager.get_scroll_region(buffer)
    new_buffer = ScreenBuffer.scroll_down(buffer, top, bottom, lines)
    ScreenManager.update_active_buffer(emulator, new_buffer)
  end

  def scroll_to(emulator, line) do
    buffer = ScreenManager.get_active_buffer(emulator)
    {top, bottom} = ScreenManager.get_scroll_region(buffer)
    # Clamp line to scroll region bounds
    target_line = max(top, min(line, bottom))

    # Shift region so that target_line is at the top
    new_buffer =
      ScreenBuffer.shift_region_to_line(buffer, {top, bottom}, target_line)

    ScreenManager.update_active_buffer(emulator, new_buffer)
  end

  def get_scroll_position(emulator) do
    buffer = ScreenManager.get_active_buffer(emulator)
    ScreenBuffer.get_scroll_position(buffer)
  end

  def reset_scroll_region(emulator) do
    buffer = ScreenManager.get_active_buffer(emulator)
    new_buffer = ScreenBuffer.reset_scroll_region(buffer)
    ScreenManager.update_active_buffer(emulator, new_buffer)
  end

  def get_line(emulator, line) do
    TextOperations.get_line(emulator, line)
  end
end
