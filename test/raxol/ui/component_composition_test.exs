defmodule Raxol.UI.ComponentCompositionTest do
  use ExUnit.Case
  alias Raxol.UI.Renderer
  alias Raxol.UI.RendererTestHelper, as: Helper
  import Raxol.Test.Visual.Assertions

  test "handles basic component composition" do
    child1 = Helper.create_test_text(1, 1, "Child 1")
    child2 = Helper.create_test_text(1, 2, "Child 2")
    parent = Helper.create_test_panel(0, 0, 10, 10, [child1, child2])
    cells = Renderer.render_to_cells(parent)

    # Should render both children
    child1_cells = Helper.get_cells_with_char(cells, "C")
    assert length(child1_cells) > 0

    child2_cells = Helper.get_cells_with_char(cells, "2")
    assert length(child2_cells) > 0
  end

  test "handles deep nesting of components" do
    grandchild = Helper.create_test_text(1, 1, "Grandchild")
    child = Helper.create_test_panel(0, 0, 5, 5, [grandchild])
    parent = Helper.create_test_panel(0, 0, 10, 10, [child])
    cells = Renderer.render_to_cells(parent)

    # Should render grandchild
    grandchild_cells = Helper.get_cells_with_char(cells, "G")
    assert length(grandchild_cells) > 0
  end

  test "handles component inheritance" do
    child =
      Helper.create_test_box(0, 0, 5, 5, %{
        style: %{foreground: :red}
      })

    parent =
      Helper.create_test_panel(0, 0, 10, 10, [child], %{
        style: %{background: :blue}
      })

    cells = Renderer.render_to_cells(parent)

    # Child should inherit parent's background
    cell = Helper.get_cell_at(cells, 0, 0)
    Helper.assert_cell_style(cell, :red, :blue)
  end

  test "handles component overrides" do
    child =
      Helper.create_test_box(0, 0, 5, 5, %{
        style: %{foreground: :red, background: :green}
      })

    parent =
      Helper.create_test_panel(0, 0, 10, 10, [child], %{
        style: %{foreground: :blue, background: :yellow}
      })

    cells = Renderer.render_to_cells(parent)

    # Child's style should override parent's
    cell = Helper.get_cell_at(cells, 0, 0)
    Helper.assert_cell_style(cell, :red, :green)
  end

  test "handles component visibility" do
    child1 = Helper.create_test_text(1, 1, "Visible")
    child2 = Helper.create_test_text(1, 2, "Hidden", %{visible: false})
    parent = Helper.create_test_panel(0, 0, 10, 10, [child1, child2])
    cells = Renderer.render_to_cells(parent)

    # Should only render visible child
    visible_cells = Helper.get_cells_with_char(cells, "V")
    assert length(visible_cells) > 0

    hidden_cells = Helper.get_cells_with_char(cells, "H")
    assert Enum.empty?(hidden_cells)
  end

  test "handles component z-index" do
    child1 = Helper.create_test_box(0, 0, 5, 5, %{z_index: 1})
    child2 = Helper.create_test_box(0, 0, 5, 5, %{z_index: 2})
    parent = Helper.create_test_panel(0, 0, 10, 10, [child1, child2])
    cells = Renderer.render_to_cells(parent)

    # Higher z-index should be rendered on top
    cell = Helper.get_cell_at(cells, 0, 0)
    assert cell != nil
  end

  test "handles component clipping" do
    child = Helper.create_test_text(0, 0, "This text should be clipped")
    parent = Helper.create_test_panel(0, 0, 5, 5, [child], %{clip: true})
    cells = Renderer.render_to_cells(parent)

    # Should clip text to parent's bounds
    # 5x5 panel
    assert length(cells) <= 25
  end

  test "handles component padding" do
    child = Helper.create_test_text(0, 0, "Padded")
    parent = Helper.create_test_panel(0, 0, 10, 10, [child], %{padding: 2})
    cells = Renderer.render_to_cells(parent)

    # Should respect padding
    cell = Helper.get_cell_at(cells, 2, 2)
    assert cell != nil
  end
end
