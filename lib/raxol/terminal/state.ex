defmodule Raxol.Terminal.State do
  @moduledoc '''
  Provides state management for the terminal emulator.
  This module handles operations like creating new states, saving and restoring states,
  and managing state transitions.
  '''

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.ANSI.TextFormatting

  @doc '''
  Creates a new terminal state with the specified dimensions and limits.
  '''
  @spec new(
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: map()
  def new(width, height, scrollback_limit, memory_limit) do
    %{
      width: width,
      height: height,
      scrollback_limit: scrollback_limit,
      memory_limit: memory_limit,
      screen_buffer: ScreenBuffer.new(width, height, scrollback_limit),
      cursor: %{
        position: {0, 0},
        visible: true,
        style: :block,
        blink_state: true
      },
      style: TextFormatting.new(),
      scroll_region: nil,
      saved_states: []
    }
  end

  @doc '''
  Saves the current state.
  '''
  @spec save_state(map()) :: map()
  def save_state(state) do
    saved_state = %{
      cursor: state.cursor,
      style: state.style,
      scroll_region: state.scroll_region
    }

    %{state | saved_states: [saved_state | state.saved_states]}
  end

  @doc '''
  Restores the most recently saved state.
  '''
  @spec restore_state(map()) :: map()
  def restore_state(state) do
    case state.saved_states do
      [saved_state | rest] ->
        new_state = %{
          state
          | cursor: saved_state.cursor,
            style: saved_state.style,
            scroll_region: saved_state.scroll_region,
            saved_states: rest
        }

        {:ok, new_state}

      [] ->
        {:error, :no_saved_state}
    end
  end

  @doc '''
  Gets the current cursor position.
  '''
  @spec get_cursor_position(map()) :: {non_neg_integer(), non_neg_integer()}
  def get_cursor_position(state) do
    state.cursor.position
  end

  @doc '''
  Sets the cursor position.
  '''
  @spec set_cursor_position(map(), non_neg_integer(), non_neg_integer()) ::
          map()
  def set_cursor_position(state, x, y) do
    new_cursor = %{state.cursor | position: {x, y}}
    %{state | cursor: new_cursor}
  end

  @doc '''
  Gets the current screen buffer.
  '''
  @spec get_screen_buffer(map()) :: ScreenBuffer.t()
  def get_screen_buffer(state) do
    state.screen_buffer
  end

  @doc '''
  Sets the screen buffer.
  '''
  @spec set_screen_buffer(map(), ScreenBuffer.t()) :: map()
  def set_screen_buffer(state, buffer) do
    %{state | screen_buffer: buffer}
  end
end
