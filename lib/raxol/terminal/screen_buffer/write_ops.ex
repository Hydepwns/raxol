defmodule Raxol.Terminal.ScreenBuffer.WriteOps do
  @moduledoc false

  alias Raxol.Terminal.Cell
  alias Raxol.Terminal.Buffer.Writer

  def write_char(buffer, x, y, char) do
    write_char(buffer, x, y, char, buffer.default_style)
  end

  def write_char(buffer, x, y, char, style) when x >= 0 and y >= 0 do
    case {x < buffer.width, y < buffer.height} do
      {true, true} ->
        Writer.write_char(buffer, x, y, char, style)

      _ ->
        buffer
    end
  end

  def write_string(buffer, x, y, string),
    do: write_string(buffer, x, y, string, nil)

  def write_string(buffer, x, y, string, style) when x >= 0 and y >= 0 do
    case {x < buffer.width, y < buffer.height} do
      {true, true} ->
        Writer.write_string(buffer, x, y, string, style)

      _ ->
        buffer
    end
  end

  def get_char(buffer, x, y) do
    case {x >= 0 and x < buffer.width, y >= 0 and y < buffer.height} do
      {true, true} ->
        row = Enum.at(buffer.cells, y, [])
        cell = Enum.at(row, x)

        case cell do
          %{char: char} -> char
          _ -> " "
        end

      _ ->
        " "
    end
  end

  def get_cell(buffer, x, y) when x >= 0 and y >= 0 do
    cell =
      if x < buffer.width and y < buffer.height do
        case buffer.cells do
          nil ->
            Cell.new()

          cells ->
            cells
            |> Enum.at(y, [])
            |> Enum.at(x, Cell.new())
        end
      else
        Cell.new()
      end

    Map.from_struct(cell)
  end

  def get_cell(_, _, _), do: Map.from_struct(Cell.new())

  def get_content(buffer) do
    case buffer.cells do
      nil ->
        ""

      cells when is_list(cells) ->
        cells
        |> Enum.map(fn line when is_list(line) ->
          line
          |> Enum.map_join("", fn
            %Cell{char: char} ->
              char

            cell ->
              case Map.get(cell, :char) do
                nil -> " "
                char -> char
              end
          end)
          |> String.trim_trailing()
        end)
        |> Enum.reverse()
        |> Enum.drop_while(&(&1 == ""))
        |> Enum.reverse()
        |> case do
          [] -> ""
          lines -> Enum.join(lines, "\n")
        end

      _ ->
        ""
    end
  end

  def put_line(buffer, y, line) when y >= 0 and y < buffer.height do
    new_cells = List.replace_at(buffer.cells || [], y, line)
    %{buffer | cells: new_cells}
  end

  def put_line(buffer, _, _), do: buffer
end
