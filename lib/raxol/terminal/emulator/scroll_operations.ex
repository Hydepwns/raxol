defmodule Raxol.Terminal.Emulator.ScrollOperations do
  @moduledoc """
  Scroll operation functions extracted from the main emulator module.
  Handles scroll region management and scroll positioning.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Terminal.Operations.ScrollOperations, as: ScrollOps

  @type emulator :: Emulator.t()

  @doc """
  Updates the scroll region with new top and bottom bounds.
  """
  @spec update_scroll_region(emulator(), {non_neg_integer(), non_neg_integer()}) :: emulator()
  def update_scroll_region(emulator, {top, bottom}) do
    ScrollOps.set_scroll_region(emulator, {top, bottom})
  end

  @doc """
  Gets the bottom scroll position.
  """
  @spec get_scroll_bottom(emulator()) :: non_neg_integer()
  def get_scroll_bottom(emulator) do
    case emulator.scroll_region do
      {_top, bottom} -> bottom
      nil -> emulator.height - 1
    end
  end

  @doc """
  Gets the top scroll position.
  """
  @spec get_scroll_top(emulator()) :: non_neg_integer()
  def get_scroll_top(emulator) do
    case emulator.scroll_region do
      {top, _bottom} -> top
      nil -> 0
    end
  end

  @doc """
  Gets the scrollback buffer from the emulator.
  """
  @spec get_scrollback(emulator()) :: list()
  def get_scrollback(emulator) do
    emulator.scrollback_buffer || []
  end

  @doc """
  Gets the scroll region from the emulator.
  """
  @spec get_scroll_region(emulator()) :: {non_neg_integer(), non_neg_integer()} | nil
  def get_scroll_region(emulator) do
    emulator.scroll_region
  end

  @doc """
  Checks if the cursor needs to scroll and performs scrolling if necessary.
  """
  @spec maybe_scroll(emulator()) :: emulator()
  def maybe_scroll(%Emulator{} = emulator) do
    cursor_position = Raxol.Terminal.Emulator.Helpers.get_cursor_position(emulator)
    
    case cursor_position do
      {_x, y} when y >= emulator.height ->
        # Cursor is below the screen, scroll up
        ScrollOps.scroll_up(emulator, 1)
      {_x, y} when y < 0 ->
        # Cursor is above the screen, scroll down
        ScrollOps.scroll_down(emulator, 1)
      _ ->
        # No scrolling needed
        emulator
    end
  end
end