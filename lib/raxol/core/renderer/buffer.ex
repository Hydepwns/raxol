defmodule Raxol.Core.Renderer.Buffer do
  @moduledoc """
  Manages terminal buffer rendering with double buffering and damage tracking.

  This module provides efficient terminal rendering by:
  * Using double buffering to prevent screen flicker
  * Tracking damaged regions to minimize updates
  * Supporting partial screen updates
  * Managing frame timing
  """

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

      back_buffer = %{
        back_buffer
        | cells: Map.put(back_buffer.cells, pos, cell),
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

    damage =
      for x <- 0..(width - 1),
          y <- 0..(height - 1),
          into: MapSet.new(),
          do: {x, y}

    back_buffer = %{buffer.back_buffer | cells: %{}, damage: damage}

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
      new_buffer = %{
        buffer
        | front_buffer: buffer.back_buffer,
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

    # 1. Copy existing cells into a list-of-lists grid format
    new_cells_grid = copy_cells(buffer.back_buffer.cells, old_size, new_size)

    # 2. Convert the grid into the expected cell map format: %{{x, y} => cell}
    new_cells_map =
      new_cells_grid
      |> Enum.with_index()
      |> Enum.reduce(%{}, fn {row_cells, y}, acc_map ->
        row_cells
        |> Enum.with_index()
        |> Enum.reduce(acc_map, fn {cell, x}, inner_acc_map ->
          Map.put(inner_acc_map, {x, y}, cell)
        end)
      end)

    # 3. Calculate damage: all cells in the new dimensions are damaged
    damage =
      for x <- 0..(new_width - 1),
          y <- 0..(new_height - 1),
          into: MapSet.new() do
        {x, y}
      end

    # 4. Update the back buffer
    new_back_buffer = %{new_back_buffer | cells: new_cells_map, damage: damage}

    updated_buffer = %{
      buffer
      | back_buffer: new_back_buffer,
        front_buffer: %{buffer.front_buffer | size: new_size}
    }

    updated_buffer
  end

  # Private Helpers

  defp copy_cells(cells, {old_w, _old_h}, {new_w, new_h}) do
    # Copy cells from old dimensions to new dimensions
    for y <- 0..(new_h - 1) do
      for x <- 0..(new_w - 1) do
        if x < old_w and y < new_h do
          get_in(cells, [y, x]) || Raxol.Terminal.Cell.new()
        else
          Raxol.Terminal.Cell.new()
        end
      end
    end
  end
end
