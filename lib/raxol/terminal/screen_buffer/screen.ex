defmodule Raxol.Terminal.ScreenBuffer.Screen do
  @moduledoc """
  Handles screen buffer operations for the terminal emulator.
  This module provides functions for managing the screen state, including
  clearing, erasing, and marking damaged regions.
  """

  alias Raxol.Terminal.ANSI.TextFormatting

  def init do
    %{
      damage_regions: [],
      default_style: TextFormatting.new()
    }
  end

  def clear(screen_state) do
    %{screen_state | damage_regions: [{0, 0, 80, 24}]}
  end

  def mark_damaged(screen_state, x, y, width, height) do
    damage_regions = [{x, y, width, height} | screen_state.damage_regions]
    %{screen_state | damage_regions: damage_regions}
  end

  def erase_from_cursor_to_end(screen_state) do
    %{screen_state | damage_regions: [{0, 0, 80, 24}]}
  end

  def erase_from_start_to_cursor(screen_state) do
    %{screen_state | damage_regions: [{0, 0, 80, 24}]}
  end

  def erase_all(screen_state) do
    %{screen_state | damage_regions: [{0, 0, 80, 24}]}
  end

  def erase_all_with_scrollback(screen_state) do
    %{screen_state | damage_regions: [{0, 0, 80, 24}]}
  end

  def erase_from_cursor_to_end_of_line(screen_state) do
    %{screen_state | damage_regions: [{0, 0, 80, 1}]}
  end

  def erase_from_start_of_line_to_cursor(screen_state) do
    %{screen_state | damage_regions: [{0, 0, 80, 1}]}
  end

  def erase_line(screen_state) do
    %{screen_state | damage_regions: [{0, 0, 80, 1}]}
  end

  def get_damaged_regions(screen_state) do
    screen_state.damage_regions
  end

  def clear_damaged_regions(screen_state) do
    %{screen_state | damage_regions: []}
  end
end
