defmodule Raxol.UI.ThemeHandlingTest do
  use ExUnit.Case
  alias Raxol.UI.Renderer
  alias Raxol.UI.RendererTestHelper, as: Helper

  test "handles missing themes" do
    element = Helper.create_test_box(0, 0, 5, 5, %{theme: "nonexistent"})
    cells = Renderer.render(element)

    # Should use default theme
    cell = Helper.get_cell_at(cells, 0, 0)
    Helper.assert_cell_style(cell, :white, :black)
  end

  test "handles missing theme colors" do
    theme = Helper.create_test_theme("test", "Test Theme", "Test theme", %{})
    element = Helper.create_test_box(0, 0, 5, 5, %{theme: theme})
    cells = Renderer.render(element)

    # Should use default colors
    cell = Helper.get_cell_at(cells, 0, 0)
    Helper.assert_cell_style(cell, :white, :black)
  end

  test "handles style overrides" do
    theme = Helper.create_test_theme("test", "Test Theme", "Test theme", %{
      foreground: :red,
      background: :blue
    })
    element = Helper.create_test_box(0, 0, 5, 5, %{
      theme: theme,
      style: %{foreground: :green, background: :yellow}
    })
    cells = Renderer.render(element)

    # Style should override theme
    cell = Helper.get_cell_at(cells, 0, 0)
    Helper.assert_cell_style(cell, :green, :yellow)
  end

  test "handles border style overrides" do
    theme = Helper.create_test_theme("test", "Test Theme", "Test theme", %{
      border_style: %{type: :double}
    })
    element = Helper.create_test_box(0, 0, 5, 5, %{
      theme: theme,
      border_style: %{type: :single}
    })
    cells = Renderer.render(element)

    # Border style should be overridden
    cell = Helper.get_cell_at(cells, 0, 0)
    Helper.assert_cell_style(cell, :white, :black, [:single])
  end

  test "handles default border styles" do
    element = Helper.create_test_box(0, 0, 5, 5)
    cells = Renderer.render(element)

    # Should use default border style
    cell = Helper.get_cell_at(cells, 0, 0)
    Helper.assert_cell_style(cell, :white, :black, [:single])
  end

  test "handles no borders" do
    element = Helper.create_test_box(0, 0, 5, 5, %{border: false})
    cells = Renderer.render(element)

    # Should not have border style
    cell = Helper.get_cell_at(cells, 0, 0)
    Helper.assert_cell_style(cell, :white, :black, [])
  end

  test "handles theme inheritance" do
    parent_theme = Helper.create_test_theme("parent", "Parent Theme", "Parent theme", %{
      foreground: :red,
      background: :blue
    })
    child_theme = Helper.create_test_theme("child", "Child Theme", "Child theme", %{
      foreground: :green
    })
    element = Helper.create_test_box(0, 0, 5, 5, %{
      theme: child_theme,
      parent_theme: parent_theme
    })
    cells = Renderer.render(element)

    # Should inherit background from parent
    cell = Helper.get_cell_at(cells, 0, 0)
    Helper.assert_cell_style(cell, :green, :blue)
  end

  test "handles theme variants" do
    theme = Helper.create_test_theme("test", "Test Theme", "Test theme", %{
      variants: %{
        "error" => %{foreground: :red},
        "success" => %{foreground: :green}
      }
    })
    element = Helper.create_test_box(0, 0, 5, 5, %{
      theme: theme,
      variant: "error"
    })
    cells = Renderer.render(element)

    # Should use error variant
    cell = Helper.get_cell_at(cells, 0, 0)
    Helper.assert_cell_style(cell, :red, :black)
  end
end
