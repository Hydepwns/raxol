defmodule Raxol.Terminal.Buffer.Manager.State do
  @moduledoc """
  Handles state management for the terminal buffer manager.
  Provides functionality for initializing and managing buffer state.
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Buffer.DamageTracker
  alias Raxol.Terminal.Buffer.Scrollback

  @type t :: %__MODULE__{
          active_buffer: ScreenBuffer.t(),
          back_buffer: ScreenBuffer.t(),
          damage_tracker: DamageTracker.t(),
          memory_limit: non_neg_integer(),
          memory_usage: non_neg_integer(),
          cursor_position: {non_neg_integer(), non_neg_integer()},
          scrollback: Scrollback.t()
        }

  defstruct [
    :active_buffer,
    :back_buffer,
    :damage_tracker,
    :memory_limit,
    :memory_usage,
    :cursor_position,
    :scrollback
  ]

  @doc """
  Creates a new buffer manager state with the given dimensions.

  ## Examples

      iex> {:ok, state} = State.new(80, 24)
      iex> state.active_buffer.width
      80
      iex> state.active_buffer.height
      24
  """
  def new(width, height, scrollback_height \\ 1000, memory_limit \\ 10_000_000) do
    active_buffer = ScreenBuffer.new(width, height, scrollback_height)
    back_buffer = ScreenBuffer.new(width, height, scrollback_height)

    {:ok,
     %__MODULE__{
       active_buffer: active_buffer,
       back_buffer: back_buffer,
       damage_tracker: DamageTracker.new(),
       memory_limit: memory_limit,
       memory_usage: 0,
       cursor_position: {0, 0},
       scrollback: Scrollback.new(scrollback_height)
     }}
  end

  @doc """
  Switches the active and back buffers.

  ## Examples

      iex> state = State.new(80, 24)
      iex> state = State.switch_buffers(state)
      iex> state.active_buffer == state.back_buffer
      false
  """
  def switch_buffers(%__MODULE__{} = state) do
    %{
      state
      | active_buffer: state.back_buffer,
        back_buffer: state.active_buffer,
        damage_tracker: DamageTracker.clear_regions(state.damage_tracker)
    }
  end

  @doc """
  Updates the active buffer in the state.
  """
  def update_active_buffer(%__MODULE__{} = state, new_buffer) do
    %{state | active_buffer: new_buffer}
  end

  @doc """
  Updates the back buffer in the state.
  """
  def update_back_buffer(%__MODULE__{} = state, new_buffer) do
    %{state | back_buffer: new_buffer}
  end

  @doc """
  Gets the current dimensions of the buffer.
  """
  def get_dimensions(%__MODULE__{} = state) do
    {state.active_buffer.width, state.active_buffer.height}
  end

  @doc """
  Gets the scrollback height.
  """
  def get_scrollback_height(%__MODULE__{} = state) do
    state.scrollback.height
  end
end
