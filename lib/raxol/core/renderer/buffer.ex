defmodule Raxol.Core.Renderer.Buffer do
  @moduledoc """
  Manages terminal buffer rendering with double buffering and damage tracking.
  
  This module provides efficient terminal rendering by:
  * Using double buffering to prevent screen flicker
  * Tracking damaged regions to minimize updates
  * Supporting partial screen updates
  * Managing frame timing
  """

  alias Raxol.Core.Runtime.EventLoop

  @type position :: {non_neg_integer(), non_neg_integer()}
  @type size :: {non_neg_integer(), non_neg_integer()}
  @type cell :: %{
    char: String.t(),
    fg: term(),
    bg: term(),
    style: [atom()]
  }
  @type buffer :: %{
    size: size(),
    cells: %{position() => cell()},
    damage: MapSet.t(position())
  }

  defstruct [:front_buffer, :back_buffer, :fps, :last_frame_time]

  @doc """
  Creates a new buffer manager with the given size and FPS.
  """
  def new(width, height, fps \\ 60) do
    empty_buffer = %{
      size: {width, height},
      cells: %{},
      damage: MapSet.new()
    }

    %__MODULE__{
      front_buffer: empty_buffer,
      back_buffer: empty_buffer,
      fps: fps,
      last_frame_time: System.monotonic_time(:millisecond)
    }
  end

  @doc """
  Updates a cell in the back buffer and marks it as damaged.
  """
  def put_cell(buffer, {x, y} = pos, char, opts \\ []) do
    {width, height} = buffer.back_buffer.size
    
    if x >= 0 and x < width and y >= 0 and y < height do
      cell = %{
        char: char,
        fg: Keyword.get(opts, :fg),
        bg: Keyword.get(opts, :bg),
        style: Keyword.get(opts, :style, [])
      }
      
      back_buffer = buffer.back_buffer
      back_buffer = %{back_buffer |
        cells: Map.put(back_buffer.cells, pos, cell),
        damage: MapSet.put(back_buffer.damage, pos)
      }
      
      %{buffer | back_buffer: back_buffer}
    else
      buffer
    end
  end

  @doc """
  Clears the entire buffer and marks all cells as damaged.
  """
  def clear(buffer) do
    {width, height} = buffer.back_buffer.size
    damage = for x <- 0..(width-1),
                y <- 0..(height-1),
                into: MapSet.new(),
                do: {x, y}
                
    back_buffer = %{buffer.back_buffer |
      cells: %{},
      damage: damage
    }
    
    %{buffer | back_buffer: back_buffer}
  end

  @doc """
  Swaps the front and back buffers if enough time has passed since the last frame.
  Returns {buffer, should_render}, where should_render indicates if a new frame should be drawn.
  """
  def swap_buffers(buffer) do
    now = System.monotonic_time(:millisecond)
    frame_time = 1000 / buffer.fps
    
    if now - buffer.last_frame_time >= frame_time do
      # Swap buffers
      new_buffer = %{buffer |
        front_buffer: buffer.back_buffer,
        back_buffer: %{buffer.back_buffer | damage: MapSet.new()},
        last_frame_time: now
      }
      {new_buffer, true}
    else
      {buffer, false}
    end
  end

  @doc """
  Gets the damaged regions that need to be redrawn.
  Returns a list of {position, cell} tuples.
  """
  def get_damage(buffer) do
    Enum.map(buffer.front_buffer.damage, fn pos ->
      {pos, Map.get(buffer.front_buffer.cells, pos)}
    end)
  end

  @doc """
  Resizes the buffer to the new dimensions.
  Preserves content where possible and marks all changed cells as damaged.
  """
  def resize(buffer, new_width, new_height) do
    old_size = buffer.back_buffer.size
    new_size = {new_width, new_height}
    
    # Create new empty buffer
    new_back_buffer = %{
      size: new_size,
      cells: %{},
      damage: MapSet.new()
    }
    
    # Copy existing cells that are still in bounds
    {new_cells, damage} = copy_cells(buffer.back_buffer.cells, old_size, new_size)
    
    new_back_buffer = %{new_back_buffer |
      cells: new_cells,
      damage: damage
    }
    
    %{buffer |
      back_buffer: new_back_buffer,
      front_buffer: %{buffer.front_buffer | size: new_size}
    }
  end

  # Private Helpers

  defp copy_cells(cells, {old_w, old_h}, {new_w, new_h}) do
    # Find cells that need to be copied or marked as damaged
    Enum.reduce(cells, {%{}, MapSet.new()}, fn {{x, y}, cell}, {new_cells, damage} ->
      cond do
        x < new_w and y < new_h ->
          # Cell is still in bounds, copy it
          {Map.put(new_cells, {x, y}, cell), MapSet.put(damage, {x, y})}
        true ->
          # Cell is out of bounds, mark as damaged
          {new_cells, MapSet.put(damage, {x, y})}
      end
    end)
  end
end 