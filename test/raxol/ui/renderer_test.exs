defmodule Raxol.UI.RendererTest do
  use ExUnit.Case, async: true

  alias Raxol.UI.Renderer
  alias Raxol.UI.Theming.Theme

  # Helper function to find cells at a specific coordinate
  defp find_cell(cells, x, y) do
    Enum.find(cells, fn {cx, cy, _, _, _, _} -> cx == x and cy == y end)
  end

  # Helper to get all cells for a specific row
  defp get_row_cells(cells, y) do
    Enum.filter(cells, fn {_, cy, _, _, _, _} -> cy == y end)
    |> Enum.sort_by(fn {cx, _, _, _, _, _} -> cx end)
  end

  describe "Table Rendering" do
    # TODO: Add tests for rendering table elements received from the Layout Engine.
    # These tests should verify:
    # - Correct application of cell alignment (left, center, right) based on attributes/styles.
    # - Correct application of theme styles (header, data rows, borders, etc.).

    test "renders table cell alignment correctly" do
      # Setup: Create a sample positioned table element (from Layout)
      # Setup: Define a theme
      # Execute: Call Renderer.render with the element and theme
      # Assert: Check the final character grid/cell list for correct padding/positioning
      flunk("Test not implemented: Alignment is currently hardcoded to left.")
    end

    test "applies theme styles to table header and data rows" do
      # 1. Setup: Define Theme
      # Assuming a simple Theme struct structure for testing purposes
      test_theme = %Theme{
        id: :test_theme,
        component_styles: %{
          table: %{
            header_fg: :yellow,
            header_bg: :blue,
            row_fg: :white,
            row_bg: :black,
            border: :green # For separator
          }
        }
      }

      # 2. Setup: Define Positioned Table Element (Output from Layout Engine)
      positioned_table = %{
        type: :table,
        x: 1,
        y: 2,
        width: 15, # Width should be enough for content + separators
        height: 5,
        attrs: %{
          _headers: ["H1", "H2"], # Short headers
          _data: [%{a: "D1", b: "D2"}], # Sample data row (Layout passes original map?)
                                      # --> Renderer code extracts based on keys, maybe needs list?
                                      # --> Let's assume render_table_row handles map data correctly, or adapt if test fails.
                                      # --> Correction: render_table passes `_data` (list of maps), but render_table_row expects list of items.
                                      # --> The actual Renderer code uses _data: [_headers, _data, _col_widths]. Check Layout output again.
                                      # --> Re-checking Layout output: It passes _headers, _data (original list of maps), _col_widths.
                                      # --> Re-checking Renderer: render_table gets _data, but passes `row_data` (a map) to render_table_row.
                                      # --> Re-checking render_table_row: It expects `row_items` (list). This seems inconsistent.
                                      # Let's assume for the test that render_table extracts the items correctly based on col keys
                                      # Or use a simpler data structure if the implementation is simpler.
                                      # The code `Enum.flat_map(Enum.with_index(data), fn {row_data, index} -> render_table_row(...)` suggests
                                      # render_table_row DOES receive the map `row_data`. Let's assume `to_string` is used implicitly if needed.
                                      # Let's provide the data format expected by render_table_row based on how it uses it:
          _data: [["D1", "D2"]], # Renderer seems to expect list of lists here
          _col_widths: [5, 5], # Col widths from layout
          _component_type: :table,
          style: %{} # Base style
        }
      }

      # 3. Execute: Call Renderer.render
      # The function expects a list of elements
      rendered_cells = Renderer.render([positioned_table], test_theme)

      # 4. Assert: Check styles
      header_y = 2 # Table starts at y=1, header is at y=2
      separator_y = 3
      data_y = 4

      # Check header row styles (y=2)
      header_cells = get_row_cells(rendered_cells, header_y)
      assert Enum.all?(header_cells, fn {_, _, _, fg, bg, _} -> fg == :yellow and bg == :blue end)

      # Check separator row styles (y=3)
      separator_cells = get_row_cells(rendered_cells, separator_y)
      # Separator uses render_text with separator_style derived from theme's :border color
      assert Enum.all?(separator_cells, fn {_, _, _, fg, bg, _} -> fg == :green end)

      # Check data row styles (y=4)
      data_cells = get_row_cells(rendered_cells, data_y)
      assert Enum.all?(data_cells, fn {_, _, _, fg, bg, _} -> fg == :white and bg == :black end)
    end
  end
end
