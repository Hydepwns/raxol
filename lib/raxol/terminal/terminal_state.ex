defmodule Raxol.Terminal.State do
  @moduledoc """
  Provides state management for the terminal emulator.
  This module handles operations like creating new states, saving and restoring states,
  and managing state transitions.
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.ANSI.TextFormatting

  @type cursor :: %{
          position: {non_neg_integer(), non_neg_integer()},
          visible: boolean(),
          style: atom(),
          blink_state: boolean()
        }

  @type t :: %{
          width: non_neg_integer(),
          height: non_neg_integer(),
          scrollback_limit: non_neg_integer(),
          memory_limit: non_neg_integer(),
          screen_buffer: ScreenBuffer.t(),
          cursor: cursor(),
          style: TextFormatting.t(),
          scroll_region: term() | nil,
          saved_states: list(map())
        }

  @doc """
  Creates a new terminal state with the specified dimensions and limits.
  """
  @spec new(
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: t()
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

  @doc """
  Saves the current state.
  """
  @spec save_state(t()) :: t()
  def save_state(state) do
    saved_state = %{
      cursor: state.cursor,
      style: state.style,
      scroll_region: state.scroll_region
    }

    %{state | saved_states: [saved_state | state.saved_states]}
  end

  @doc """
  Restores the most recently saved state.
  """
  @spec restore_state(t()) :: {:ok, t()} | {:error, atom()}
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

  @doc """
  Gets the current cursor position.
  """
  @spec get_cursor_position(t()) :: {non_neg_integer(), non_neg_integer()}
  def get_cursor_position(state) do
    state.cursor.position
  end

  @doc """
  Sets the cursor position.
  """
  @spec set_cursor_position(t(), non_neg_integer(), non_neg_integer()) ::
          t()
  def set_cursor_position(state, x, y) do
    new_cursor = %{state.cursor | position: {x, y}}
    %{state | cursor: new_cursor}
  end

  @doc """
  Gets the current screen buffer.
  """
  @spec get_screen_buffer(t()) :: ScreenBuffer.t()
  def get_screen_buffer(state) do
    state.screen_buffer
  end

  @doc """
  Sets the screen buffer.
  """
  @spec set_screen_buffer(t(), ScreenBuffer.t()) :: t()
  def set_screen_buffer(state, buffer) do
    %{state | screen_buffer: buffer}
  end
end
