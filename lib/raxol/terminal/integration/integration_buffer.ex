defmodule Raxol.Terminal.Integration.Buffer do
  @moduledoc """
  Handles buffer and cursor management for the terminal.
  """

  alias Raxol.Terminal.{
    ScreenBuffer.Manager,
    Scroll.UnifiedScroll,
    Integration.State
  }

  @doc """
  Writes text to the terminal buffer.
  """
  def write(%State{} = state, text) do
    # Update the buffer manager with the new text
    {:ok, buffer_manager} = Manager.write(state.buffer_manager, text)

    # Update the cursor position
    cursor_manager = Manager.update_position(state.cursor_manager, text)

    # Update the state
    State.update(state, %{
      buffer_manager: buffer_manager,
      cursor_manager: cursor_manager
    })
  end

  @doc """
  Clears the terminal buffer.
  """
  def clear(%State{} = state) do
    # Clear the buffer manager
    {:ok, buffer_manager} = Manager.clear(state.buffer_manager)

    # Reset the cursor position
    cursor_manager = Manager.reset_position(state.cursor_manager)

    # Update the state
    State.update(state, %{
      buffer_manager: buffer_manager,
      cursor_manager: cursor_manager
    })
  end

  @doc """
  Scrolls the terminal buffer.
  """
  def scroll(%State{} = state, direction, amount \\ 1) do
    # Update the scroll buffer
    scroll_buffer = UnifiedScroll.scroll(state.scroll_buffer, direction, amount)

    # Update the buffer manager's visible region
    {:ok, buffer_manager} =
      Manager.update_visible_region(
        state.buffer_manager,
        UnifiedScroll.get_visible_region(scroll_buffer)
      )

    # Update the state
    State.update(state, %{
      buffer_manager: buffer_manager,
      scroll_buffer: scroll_buffer
    })
  end

  @doc """
  Moves the cursor to a specific position.
  """
  def move_cursor(%State{} = state, x, y) do
    # Update the cursor position
    cursor_manager = Manager.move_to(state.cursor_manager, x, y)

    # Update the state
    State.update(state, cursor_manager: cursor_manager)
  end

  @doc """
  Gets the current cursor position.
  """
  def get_cursor_position(%State{} = state) do
    Manager.get_position(state.cursor_manager)
  end

  @doc """
  Gets the current visible content.
  """
  def get_visible_content(%State{} = state) do
    Manager.get_visible_content(state.buffer_manager)
  end

  @doc """
  Gets the current scroll position.
  """
  def get_scroll_position(%State{} = state) do
    UnifiedScroll.get_position(state.scroll_buffer)
  end

  @doc """
  Gets the total number of lines in the buffer.
  """
  def get_total_lines(%State{} = state) do
    Manager.get_total_lines(state.buffer_manager)
  end

  @doc """
  Gets the number of visible lines.
  """
  def get_visible_lines(%State{} = state) do
    Manager.get_visible_lines(state.buffer_manager)
  end

  @doc """
  Resizes the terminal buffer.
  """
  def resize(%State{} = state, width, height) do
    # Resize the buffer manager
    {:ok, buffer_manager} =
      Manager.resize(state.buffer_manager, width, height)

    # Update the scroll buffer
    scroll_buffer = UnifiedScroll.resize(state.scroll_buffer, height)

    # Update the cursor position if needed
    cursor_manager =
      Manager.constrain_position(
        state.cursor_manager,
        width,
        height
      )

    # Update the state
    State.update(state, %{
      buffer_manager: buffer_manager,
      scroll_buffer: scroll_buffer,
      cursor_manager: cursor_manager
    })
  end
end
