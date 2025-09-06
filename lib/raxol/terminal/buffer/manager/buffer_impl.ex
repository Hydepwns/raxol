defmodule Raxol.Terminal.Buffer.Manager.BufferImpl do
  @moduledoc """
  Implementation of buffer operations for the terminal.
  This module contains the actual implementation of buffer operations
  that are used by the public Buffer interface.
  """

  alias Raxol.Terminal.Buffer.Cell

  defstruct width: 0,
            height: 0,
            cells: %{},
            cursor_position: {0, 0},
            attributes: %{},
            mode: :normal,
            title: "",
            icon_name: "",
            icon_title: ""

  @type t :: %__MODULE__{
          width: non_neg_integer(),
          height: non_neg_integer(),
          cells: %{non_neg_integer() => Cell.t()},
          cursor_position: {non_neg_integer(), non_neg_integer()},
          attributes: map(),
          mode: atom(),
          title: String.t(),
          icon_name: String.t(),
          icon_title: String.t()
        }

  def new(width, height) do
    %__MODULE__{width: width, height: height}
  end

  def get_cell(buffer, x, y) do
    key = cell_key(x, y)
    Map.get(buffer.cells, key, Cell.new())
  end

  def set_cell(buffer, x, y, cell) do
    key = cell_key(x, y)
    cells = Map.put(buffer.cells, key, cell)
    %{buffer | cells: cells}
  end

  def fill_region(buffer, x, y, width, height, cell) do
    cells = buffer.cells

    cells =
      for i <- x..(x + width - 1),
          j <- y..(y + height - 1),
          reduce: cells do
        acc ->
          key = cell_key(i, j)
          Map.put(acc, key, cell)
      end

    %{buffer | cells: cells}
  end

  def copy_region(buffer, src_x, src_y, dst_x, dst_y, width, height) do
    cells = buffer.cells

    cells =
      for i <- 0..(width - 1),
          j <- 0..(height - 1),
          reduce: cells do
        acc ->
          src_key = cell_key(src_x + i, src_y + j)
          dst_key = cell_key(dst_x + i, dst_y + j)
          cell = Map.get(acc, src_key, Cell.new())
          Map.put(acc, dst_key, cell)
      end

    %{buffer | cells: cells}
  end

  def scroll_region(buffer, x, y, width, height, lines) do
    case lines > 0 do
      true ->
        scroll_up(buffer, x, y, width, height, lines)
      false ->
        scroll_down(buffer, x, y, width, height, abs(lines))
    end
  end

  defp scroll_up(buffer, x, y, width, height, lines) do
    cells = move_cells(buffer.cells, x, y, width, height - lines, 0, lines)
    cells = clear_region(cells, x, y + height - lines, width, lines)
    %{buffer | cells: cells}
  end

  defp scroll_down(buffer, x, y, width, height, lines) do
    cells =
      move_cells(buffer.cells, x, y + lines, width, height - lines, 0, -lines)

    cells = clear_region(cells, x, y, width, lines)
    %{buffer | cells: cells}
  end

  defp move_cells(cells, x, y, width, height, x_offset, y_offset) do
    coords = for i <- x..(x + width - 1), j <- y..(y + height - 1), do: {i, j}
    Enum.reduce(coords, cells, &move_cell(&1, &2, x_offset, y_offset))
  end

  defp move_cell({i, j}, cells, x_offset, y_offset) do
    src_key = cell_key(i + x_offset, j + y_offset)
    dst_key = cell_key(i, j)
    cell = Map.get(cells, src_key, Cell.new())
    Map.put(cells, dst_key, cell)
  end

  defp clear_region(cells, x, y, width, height) do
    coords = for i <- x..(x + width - 1), j <- y..(y + height - 1), do: {i, j}
    Enum.reduce(coords, cells, &clear_cell(&1, &2))
  end

  defp clear_cell({i, j}, cells) do
    Map.put(cells, cell_key(i, j), Cell.new())
  end

  def copy(buffer) do
    %{buffer | cells: Map.new(buffer.cells)}
  end

  def get_differences(active_buffer, back_buffer) do
    active_buffer.cells
    |> Map.keys()
    |> Enum.reduce([], fn key, acc ->
      active_cell = Map.get(active_buffer.cells, key)
      back_cell = Map.get(back_buffer.cells, key)

      case active_cell != back_cell do
        true ->
          {x, y} = key_to_coords(key)
          [{x, y, active_cell} | acc]
        false ->
          acc
      end
    end)
    |> Enum.reverse()
  end

  def clear(buffer) do
    %{buffer | cells: %{}}
  end

  def resize(buffer, width, height) do
    cells =
      buffer.cells
      |> Enum.filter(fn {key, _} ->
        {x, y} = key_to_coords(key)
        x < width && y < height
      end)
      |> Map.new()

    %{buffer | width: width, height: height, cells: cells}
  end

  @doc """
  Gets a line from the buffer.
  """
  def get_line(buffer, y) do
    for x <- 0..(buffer.width - 1) do
      get_cell(buffer, x, y)
    end
  end

  @doc """
  Gets the content of the buffer as a string.
  """
  def get_content(buffer) do
    for y <- 0..(buffer.height - 1) do
      line =
        for x <- 0..(buffer.width - 1) do
          cell = get_cell(buffer, x, y)
          cell.char || " "
        end
        |> Enum.join("")
        |> String.trim_trailing()

      line
    end
    |> Enum.filter(&(&1 != ""))
    |> Enum.join("\n")
  end

  @doc """
  Sets a line in the buffer.
  """
  def set_line(buffer, y, cells) do
    cells
    |> Enum.with_index()
    |> Enum.reduce(buffer, fn {cell, x}, acc ->
      set_cell(acc, x, y, cell)
    end)
  end

  @doc """
  Gets the buffer size.
  """
  def get_size(buffer) do
    {buffer.width, buffer.height}
  end

  @doc """
  Gets the cursor position.
  """
  def get_cursor(buffer) do
    buffer.cursor_position
  end

  @doc """
  Sets the cursor position.
  """
  def set_cursor(buffer, cursor) do
    %{buffer | cursor_position: cursor}
  end

  @doc """
  Gets the current attributes.
  """
  def get_attributes(buffer) do
    buffer.attributes
  end

  @doc """
  Sets the current attributes.
  """
  def set_attributes(buffer, attributes) do
    %{buffer | attributes: attributes}
  end

  @doc """
  Gets the current mode.
  """
  def get_mode(buffer) do
    buffer.mode
  end

  @doc """
  Sets the current mode.
  """
  def set_mode(buffer, mode) do
    %{buffer | mode: mode}
  end

  @doc """
  Gets the window title.
  """
  def get_title(buffer) do
    buffer.title
  end

  @doc """
  Sets the window title.
  """
  def set_title(buffer, title) do
    %{buffer | title: title}
  end

  @doc """
  Gets the icon name.
  """
  def get_icon_name(buffer) do
    buffer.icon_name
  end

  @doc """
  Sets the icon name.
  """
  def set_icon_name(buffer, icon_name) do
    %{buffer | icon_name: icon_name}
  end

  @doc """
  Gets the icon title.
  """
  def get_icon_title(buffer) do
    buffer.icon_title
  end

  @doc """
  Sets the icon title.
  """
  def set_icon_title(buffer, icon_title) do
    %{buffer | icon_title: icon_title}
  end

  @doc """
  Adds content to the buffer at the current cursor position.
  """
  def add(buffer, content) when is_binary(content) do
    {x, y} = buffer.cursor_position
    cells = buffer.cells

    cells =
      content
      |> String.graphemes()
      |> Enum.with_index()
      |> Enum.reduce(cells, fn {char, offset}, acc ->
        pos_x = x + offset

        case pos_x < buffer.width do
          true ->
            key = cell_key(pos_x, y)
            cell = Cell.new(char)
            Map.put(acc, key, cell)
          false ->
            acc
        end
      end)

    %{buffer | cells: cells, cursor_position: {x + String.length(content), y}}
  end

  defp cell_key(x, y), do: y * 10_000 + x

  @doc """
  Writes content to the buffer (alias for add function).
  """
  def write(buffer, content) do
    add(buffer, content)
  end

  defp key_to_coords(key) do
    y = div(key, 10_000)
    x = rem(key, 10_000)
    {x, y}
  end
end
