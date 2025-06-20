defmodule Raxol.Terminal.Buffer.Manager.State do
  @moduledoc """
  Defines the state structure and operations for the buffer manager.
  This module handles the core state management for the terminal buffer,
  including active buffer, back buffer, scrollback, damage tracking, and memory management.
  """

  alias Raxol.Terminal.ScreenBuffer
  alias Raxol.Terminal.Buffer.Scrollback
  alias Raxol.Terminal.Buffer.DamageTracker
  alias Raxol.Terminal.Buffer.MemoryManager

  defstruct [
    :active_buffer,
    :back_buffer,
    :scrollback,
    :damage_tracker,
    :memory_usage,
    :memory_limit,
    :metrics
  ]

  @type t :: %__MODULE__{
          active_buffer: ScreenBuffer.t(),
          back_buffer: ScreenBuffer.t(),
          scrollback: Scrollback.t(),
          damage_tracker: DamageTracker.t(),
          memory_usage: non_neg_integer(),
          memory_limit: non_neg_integer(),
          metrics: map()
        }

  @doc """
  Creates a new state with the specified dimensions.
  """
  def new(width, height) do
    %__MODULE__{
      active_buffer: ScreenBuffer.new(width, height),
      back_buffer: ScreenBuffer.new(width, height),
      scrollback: Scrollback.new(),
      damage_tracker: DamageTracker.new(),
      memory_usage: 0,
      memory_limit: 10_000_000,
      metrics: %{
        writes: 0,
        reads: 0,
        scrolls: 0,
        memory_usage: 0
      }
    }
  end

  @doc """
  Gets the dimensions of the active buffer.
  """
  def get_dimensions(%__MODULE__{} = state) do
    {state.active_buffer.width, state.active_buffer.height}
  end

  @doc """
  Gets the width of the active buffer.
  """
  def get_width(%__MODULE__{} = state) do
    state.active_buffer.width
  end

  @doc """
  Gets the height of the active buffer.
  """
  def get_height(%__MODULE__{} = state) do
    state.active_buffer.height
  end

  @doc """
  Gets a line from the active buffer.
  """
  def get_line(%__MODULE__{} = state, line_index) do
    ScreenBuffer.get_line(state.active_buffer, line_index)
  end

  @doc """
  Gets a cell from the active buffer.
  """
  def get_cell(%__MODULE__{} = state, x, y) do
    ScreenBuffer.get_cell(state.active_buffer, x, y)
  end

  @doc """
  Gets the content of the active buffer.
  """
  def get_content(%__MODULE__{} = state) do
    ScreenBuffer.get_content(state.active_buffer)
  end

  @doc """
  Gets a cell from the active buffer at the specified coordinates.
  """
  def get_cell_at(%__MODULE__{} = state, x, y) do
    ScreenBuffer.get_cell_at(state.active_buffer, x, y)
  end

  @doc """
  Updates a line in the active buffer.
  """
  def put_line(%__MODULE__{} = state, line_index, new_cells) do
    new_active_buffer =
      ScreenBuffer.put_line(state.active_buffer, line_index, new_cells)

    %{state | active_buffer: new_active_buffer}
  end

  @doc """
  Gets the memory usage of the state.
  """
  def get_memory_usage(%__MODULE__{} = state) do
    active_usage = ScreenBuffer.get_memory_usage(state.active_buffer)
    back_usage = ScreenBuffer.get_memory_usage(state.back_buffer)
    scrollback_usage = Scrollback.get_memory_usage(state.scrollback)

    active_usage + back_usage + scrollback_usage
  end

  @doc """
  Cleans up the state and its components.
  """
  def cleanup(%__MODULE__{} = state) do
    ScreenBuffer.cleanup(state.active_buffer)
    ScreenBuffer.cleanup(state.back_buffer)
    Scrollback.cleanup(state.scrollback)
    DamageTracker.cleanup(state.damage_tracker)

    state
  end
end
