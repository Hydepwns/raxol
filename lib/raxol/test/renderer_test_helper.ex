import ExUnit.Assertions

defmodule Raxol.UI.RendererTestHelper do
  @moduledoc """
  Helper module for renderer tests providing common test utilities and fixtures.
  """

  alias Raxol.UI.Theming.Theme

  def create_test_theme(name, colors, styles, fonts) do
    %Raxol.UI.Theming.Theme{
      name: name,
      colors: colors,
      component_styles: styles,
      fonts: fonts
    }
  end

  def get_cell_at(cells, x, y) do
    Enum.find(cells, fn {cx, cy, _, _, _, _} -> cx == x && cy == y end)
  end

  def get_cells_with_char(cells, char) do
    Enum.filter(cells, fn {_, _, c, _, _, _} -> c == char end)
  end

  def assert_cell_style(
        cell,
        expected_fg,
        expected_bg,
        expected_style_attrs \\ []
      ) do
    assert cell != nil
    {_, _, _, fg, bg, style_attrs} = cell
    assert fg == expected_fg
    assert bg == expected_bg

    Enum.each(expected_style_attrs, fn attr ->
      assert attr in style_attrs
    end)
  end

  defp ensure_id(%Theme{} = map), do: map

  defp ensure_id(map) do
    if Map.has_key?(map, :id), do: map, else: Map.put(map, :id, :test_id)
  end

  defp ensure_style(map) do
    if Map.has_key?(map, :style), do: map, else: Map.put(map, :style, %{})
  end

  defp ensure_position(map) do
    if Map.has_key?(map, :position),
      do: map,
      else: Map.put(map, :position, {0, 0})
  end

  defp ensure_disabled(map) do
    if Map.has_key?(map, :disabled),
      do: map,
      else: Map.put(map, :disabled, false)
  end

  defp ensure_focused(map) do
    if Map.has_key?(map, :focused), do: map, else: Map.put(map, :focused, false)
  end

  defp ensure_attrs(map) do
    if Map.has_key?(map, :attrs), do: map, else: Map.put(map, :attrs, %{})
  end

  def create_test_element(type, x, y, opts \\ %{}) do
    base = %{
      type: type,
      x: x,
      y: y,
      position: {x, y}
    }

    Map.merge(base, opts)
    |> ensure_style()
    |> ensure_id()
    |> ensure_position()
    |> ensure_disabled()
    |> ensure_focused()
    |> ensure_attrs()
  end

  def create_test_box(x, y, width, height, opts \\ %{}) do
    create_test_element(
      :box,
      x,
      y,
      Map.merge(%{width: width, height: height}, opts)
    )
    |> ensure_style()
    |> ensure_id()
    |> ensure_position()
    |> ensure_disabled()
    |> ensure_focused()
    |> ensure_attrs()
  end

  def create_test_text(x, y, text, opts \\ %{}) do
    create_test_element(:text, x, y, Map.merge(%{text: text}, opts))
    |> ensure_style()
    |> ensure_id()
    |> ensure_position()
    |> ensure_disabled()
    |> ensure_focused()
    |> ensure_attrs()
  end

  def create_test_panel(x, y, width, height, children \\ [], opts \\ %{}) do
    create_test_element(
      :panel,
      x,
      y,
      Map.merge(%{width: width, height: height, children: children}, opts)
    )
    |> ensure_style()
    |> ensure_id()
    |> ensure_position()
    |> ensure_disabled()
    |> ensure_focused()
    |> ensure_attrs()
  end

  def create_test_table(x, y, headers, data, opts \\ %{}) do
    create_test_element(
      :table,
      x,
      y,
      Map.merge(%{headers: headers, data: data}, opts)
    )
    |> ensure_style()
    |> ensure_id()
    |> ensure_position()
    |> ensure_disabled()
    |> ensure_focused()
    |> ensure_attrs()
  end
end
