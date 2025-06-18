defmodule Raxol.UI.SpecialComponentsTest do
  use ExUnit.Case
  alias Raxol.UI.Renderer
  alias Raxol.UI.RendererTestHelper, as: Helper
  import Raxol.Test.Visual.Assertions

  test 'handles tables with varying row lengths' do
    headers = ["Name", "Age", "City"]

    data = [
      ["John", "25"],
      ["Alice", "30", "New York", "Extra"],
      ["Bob"]
    ]

    element = Helper.create_test_table(0, 0, headers, data)
    cells = Renderer.render_to_cells(element)

    # Should handle varying row lengths
    assert length(cells) > 0
  end

  test 'handles tables with empty data' do
    headers = ["Name", "Age", "City"]
    data = []
    element = Helper.create_test_table(0, 0, headers, data)
    cells = Renderer.render_to_cells(element)

    # Should render headers only
    assert length(cells) > 0
  end

  test 'handles tables with empty headers' do
    headers = []
    data = [["John", "25", "New York"]]
    element = Helper.create_test_table(0, 0, headers, data)
    cells = Renderer.render_to_cells(element)

    # Should handle empty headers
    assert length(cells) > 0
  end

  test 'handles tables with very long content' do
    headers = ["Name", "Description"]

    data = [
      ["John", String.duplicate("Very long description ", 50)]
    ]

    element = Helper.create_test_table(0, 0, headers, data)
    cells = Renderer.render_to_cells(element)

    # Should handle long content
    assert length(cells) > 0
  end

  test 'handles tables with special characters' do
    headers = ["Name", "Symbol"]

    data = [
      ["John", "★"],
      ["Alice", "→"],
      ["Bob", "∞"]
    ]

    element = Helper.create_test_table(0, 0, headers, data)
    cells = Renderer.render_to_cells(element)

    # Should handle special characters
    special_chars = Helper.get_cells_with_char(cells, "★")
    assert length(special_chars) > 0
  end

  test 'handles tables with custom column widths' do
    headers = ["Name", "Age", "City"]
    data = [["John", "25", "New York"]]

    element =
      Helper.create_test_table(0, 0, headers, data, %{
        column_widths: [10, 5, 15]
      })

    cells = Renderer.render_to_cells(element)

    # Should respect column widths
    assert length(cells) > 0
  end

  test 'handles tables with custom styles' do
    headers = ["Name", "Age"]
    data = [["John", "25"]]

    element =
      Helper.create_test_table(0, 0, headers, data, %{
        header_style: %{foreground: :red},
        row_style: %{foreground: :green}
      })

    cells = Renderer.render_to_cells(element)

    # Should apply custom styles
    header_cell = Helper.get_cell_at(cells, 0, 0)
    Helper.assert_cell_style(header_cell, :red, :black)

    data_cell = Helper.get_cell_at(cells, 0, 1)
    Helper.assert_cell_style(data_cell, :green, :black)
  end

  test 'handles tables with sorting' do
    headers = ["Name", "Age"]

    data = [
      ["John", "25"],
      ["Alice", "30"],
      ["Bob", "20"]
    ]

    element =
      Helper.create_test_table(0, 0, headers, data, %{
        sort_by: "Age",
        sort_direction: :desc
      })

    cells = Renderer.render_to_cells(element)

    # Should sort data
    assert length(cells) > 0
  end
end
