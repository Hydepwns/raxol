defmodule Raxol.UI.BasicRenderingTest do
  use ExUnit.Case
  alias Raxol.UI.Renderer
  alias Raxol.UI.RendererTestHelper, as: Helper

  test "handles empty elements" do
    element = Helper.create_test_element(:box, 0, 0, %{width: 0, height: 0})
    cells = Renderer.render_to_cells(element)
    assert cells == []
  end

  test "handles nil elements" do
    cells = Renderer.render_to_cells(nil)
    assert cells == []
  end

  test "handles missing required attributes" do
    element = Helper.create_test_element(:box, 0, 0)

    assert_raise ArgumentError, fn ->
      Renderer.render_to_cells(element)
    end
  end

  test "handles overlapping elements" do
    element1 = Helper.create_test_box(0, 0, 5, 5)
    element2 = Helper.create_test_box(2, 2, 5, 5)
    cells = Renderer.render_to_cells([element1, element2])

    # Element2 should be rendered on top of element1
    cell = Helper.get_cell_at(cells, 2, 2)
    assert cell != nil
  end

  test "handles nested elements" do
    child = Helper.create_test_text(1, 1, "test")
    parent = Helper.create_test_panel(0, 0, 10, 10, [child])
    cells = Renderer.render_to_cells(parent)

    text_cell = Helper.get_cells_with_char(cells, "t")
    assert length(text_cell) > 0
  end

  test "handles non-ASCII characters in text" do
    element = Helper.create_test_text(0, 0, "Hello 世界")
    cells = Renderer.render_to_cells(element)

    non_ascii_cells =
      Enum.filter(cells, fn {_, _, char, _, _, _} ->
        String.length(to_string(char)) > 1
      end)

    assert length(non_ascii_cells) > 0
  end

  test "handles very large elements" do
    element = Helper.create_test_box(0, 0, 1000, 1000)
    cells = Renderer.render_to_cells(element)

    # Should handle large elements without crashing
    assert length(cells) > 0
  end

  test "handles elements with zero dimensions" do
    element = Helper.create_test_box(0, 0, 0, 0)
    cells = Renderer.render_to_cells(element)
    assert cells == []
  end

  test "handles elements with negative dimensions" do
    element = Helper.create_test_box(0, 0, -5, -5)
    cells = Renderer.render_to_cells(element)
    assert cells == []
  end

  test "handles elements with negative coordinates" do
    element = Helper.create_test_box(-5, -5, 10, 10)
    cells = Renderer.render_to_cells(element)
    assert length(cells) > 0
  end
end
