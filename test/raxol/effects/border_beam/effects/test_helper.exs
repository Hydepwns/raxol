defmodule Raxol.Effects.BorderBeam.Effects.TestHelper do
  @moduledoc false

  @doc """
  Builds an indexed cell map representing a rectangular box border at the
  given position. Border characters are the standard single-line set;
  every cell starts with no fg/bg and an empty attr list.
  """
  def make_box_cells(%{x: bx, y: by, width: w, height: h}) do
    right = bx + w - 1
    bottom = by + h - 1

    horiz = for x <- bx..right, into: %{}, do: {{x, by}, build_cell(x, by, "─")}
    horiz = Enum.reduce(bx..right, horiz, fn x, acc ->
      Map.put(acc, {x, bottom}, build_cell(x, bottom, "─"))
    end)

    vert = Enum.reduce((by + 1)..(bottom - 1)//1, horiz, fn y, acc ->
      acc
      |> Map.put({bx, y}, build_cell(bx, y, "│"))
      |> Map.put({right, y}, build_cell(right, y, "│"))
    end)

    vert
    |> Map.put({bx, by}, build_cell(bx, by, "┌"))
    |> Map.put({right, by}, build_cell(right, by, "┐"))
    |> Map.put({bx, bottom}, build_cell(bx, bottom, "└"))
    |> Map.put({right, bottom}, build_cell(right, bottom, "┘"))
  end

  defp build_cell(x, y, char), do: {x, y, char, nil, nil, []}

  @doc """
  Returns only the cells whose fg color is not nil (i.e. the cells the
  effect actually touched).
  """
  def lit_cells(cells) do
    cells
    |> Enum.filter(fn {_, {_, _, _, fg, _, _}} -> not is_nil(fg) end)
    |> Map.new()
  end

  @doc "Counts cells whose char does not match the original border set."
  def replaced_chars(cells) do
    border_chars = ~w(─ │ ┌ ┐ └ ┘)

    cells
    |> Enum.count(fn {_, {_, _, char, _, _, _}} -> char not in border_chars end)
  end
end
