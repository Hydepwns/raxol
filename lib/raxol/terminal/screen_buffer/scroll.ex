defmodule Raxol.Terminal.ScreenBuffer.Scroll do
  @moduledoc '''
  Handles scroll state management for the terminal screen buffer.
  '''

  defstruct [:position, :region_start, :region_end]

  @type t :: %__MODULE__{
          position: non_neg_integer(),
          region_start: non_neg_integer(),
          region_end: non_neg_integer()
        }

  @doc '''
  Initializes a new scroll state.
  '''
  def init do
    %__MODULE__{
      position: 0,
      region_start: 0,
      region_end: 24
    }
  end

  @doc '''
  Gets the current scroll size.
  '''
  def get_size(%__MODULE__{region_start: start, region_end: end_pos}) do
    end_pos - start
  end

  @doc '''
  Moves the scroll position up by the specified number of lines.
  '''
  def up(%__MODULE__{} = state, lines) do
    %{state | position: max(0, state.position - lines)}
  end

  @doc '''
  Moves the scroll position down by the specified number of lines.
  '''
  def down(%__MODULE__{} = state, lines) do
    %{state | position: state.position + lines}
  end

  @doc '''
  Sets the scroll region boundaries.
  '''
  def set_region(%__MODULE__{} = state, start_line, end_line) do
    %{state | region_start: start_line, region_end: end_line}
  end

  @doc '''
  Clears the scroll region, resetting to full screen.
  '''
  def clear_region(%__MODULE__{} = state) do
    %{state | region_start: 0, region_end: 24}
  end

  @doc '''
  Gets the current scroll region boundaries.
  '''
  def get_boundaries(%__MODULE__{region_start: start, region_end: end_pos}) do
    {start, end_pos}
  end

  @doc '''
  Gets the current scroll position.
  '''
  def get_position(%__MODULE__{position: pos}) do
    pos
  end
end
