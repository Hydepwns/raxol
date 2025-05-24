import ExUnit.Assertions

defmodule Raxol.UI.RendererTestHelper do
  @moduledoc """
  Helper module for renderer tests providing common test utilities and fixtures.
  """

  alias Raxol.UI.Theming.Theme

  def create_test_theme(id, name, description, colors \\ %{}) do
    %Theme{
      id: id,
      name: name,
      description: description,
      colors:
        Map.merge(
          %{
            foreground: :white,
            background: :black
          },
          colors
        ),
      fonts: %{},
      component_styles: %{},
      variants: %{}
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

  def create_test_element(type, x, y, opts \\ %{}) do
    base = %{
      type: type,
      x: x,
      y: y
    }

    Map.merge(base, opts)
  end

  def create_test_box(x, y, width, height, opts \\ %{}) do
    create_test_element(
      :box,
      x,
      y,
      Map.merge(%{width: width, height: height}, opts)
    )
  end

  def create_test_text(x, y, text, opts \\ %{}) do
    create_test_element(:text, x, y, Map.merge(%{text: text}, opts))
  end

  def create_test_panel(x, y, width, height, children \\ [], opts \\ %{}) do
    create_test_element(
      :panel,
      x,
      y,
      Map.merge(
        %{
          width: width,
          height: height,
          children: children
        },
        opts
      )
    )
  end

  def create_test_table(x, y, headers, data, opts \\ %{}) do
    create_test_element(
      :table,
      x,
      y,
      Map.merge(
        %{
          headers: headers,
          data: data
        },
        opts
      )
    )
  end
end
