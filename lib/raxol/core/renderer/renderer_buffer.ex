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
    unless is_integer(width) and width > 0 do
      raise ArgumentError, "Buffer width must be positive"
    end

    unless is_integer(height) and height > 0 do
      raise ArgumentError, "Buffer height must be positive"
    end

    unless is_integer(fps) and fps > 0 do
      raise ArgumentError, "FPS must be positive"
    end

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
  def put_cell(buffer, pos, char, opts \\ []) do
    {x, y} = validate_position!(pos)
    _ = validate_char!(char)
    cell = create_cell(char, opts)
    update_back_buffer!(buffer, {x, y}, cell)
  end

  defp validate_position!(pos) do
    case pos do
      {x, y} when is_integer(x) and is_integer(y) ->
        {x, y}

      _ ->
        raise ArgumentError, "Cell coordinates must be a tuple of two integers"
    end
  end

  defp validate_char!(char) when is_binary(char) do
    case String.length(char) do
      1 -> char
      _ -> raise ArgumentError, "Cell content must be a string of length 1"
    end
  end

  defp validate_char!(_) do
    raise ArgumentError, "Cell content must be a string of length 1"
  end

  defp create_cell(char, opts) do
    %{
      char: char,
      fg: Keyword.get(opts, :fg),
      bg: Keyword.get(opts, :bg),
      style: Keyword.get(opts, :style, [])
    }
  end

  defp update_back_buffer!(buffer, {x, y}, cell) do
    {width, height} = buffer.back_buffer.size

    case {x >= 0 and x < width, y >= 0 and y < height} do
      {true, true} ->
        back_buffer = buffer.back_buffer

        updated_back_buffer = %{
          back_buffer
          | cells: Map.put(back_buffer.cells, {x, y}, cell),
            damage: MapSet.put(back_buffer.damage, {x, y})
        }

        %{buffer | back_buffer: updated_back_buffer}

      _ ->
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
    frame_time = trunc(1000 / buffer.fps)

    case now - buffer.last_frame_time >= frame_time do
      true ->
        new_empty_back_buffer = %{
          cells: %{},
          damage: MapSet.new([]),
          size: buffer.back_buffer.size
        }

        copied_back_buffer =
          :erlang.term_to_binary(buffer.back_buffer) |> :erlang.binary_to_term()

        new_buffer = %__MODULE__{
          front_buffer: copied_back_buffer,
          back_buffer: new_empty_back_buffer,
          fps: buffer.fps,
          last_frame_time: now
        }

        {new_buffer, true}

      false ->
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

    new_cells_map =
      create_resized_cells_map(buffer.back_buffer.cells, old_size, new_size)

    damage = create_full_damage_set(new_width, new_height)

    new_back_buffer = %{
      size: new_size,
      cells: new_cells_map,
      damage: damage
    }

    %{
      buffer
      | back_buffer: new_back_buffer,
        front_buffer: %{buffer.front_buffer | size: new_size}
    }
  end

  defp create_resized_cells_map(cells, old_size, new_size) do
    copy_cells(cells, old_size, new_size)
    |> grid_to_cell_map()
  end

  defp grid_to_cell_map(grid) do
    grid
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {row_cells, y}, acc_map ->
      row_cells
      |> Enum.with_index()
      |> Enum.reduce(acc_map, fn {cell, x}, inner_acc_map ->
        Map.put(inner_acc_map, {x, y}, cell)
      end)
    end)
  end

  defp create_full_damage_set(width, height) do
    for x <- 0..(width - 1),
        y <- 0..(height - 1),
        into: MapSet.new() do
      {x, y}
    end
  end

  @spec copy_cells(map(), {non_neg_integer(), non_neg_integer()}, {non_neg_integer(), non_neg_integer()}) :: [[Raxol.Terminal.Cell.t()]]
  defp copy_cells(cells, {old_w, old_h}, {new_w, new_h}) do
    for y <- 0..(new_h - 1) do
      for x <- 0..(new_w - 1) do
        case {x < old_w, y < old_h} do
          {true, true} ->
            Map.get(cells, {x, y}, Raxol.Terminal.Cell.new())

          _ ->
            Raxol.Terminal.Cell.new()
        end
      end
    end
  end
end
