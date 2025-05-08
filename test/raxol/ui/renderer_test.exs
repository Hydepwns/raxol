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

  # Add setup block
  setup do
    # Ensure the themes ETS table exists for tests that need it
    Theme.init()
    # Also register the specific theme used in the failing test if necessary
    # Assuming :test_theme is an atom ID, we need a Theme struct
    # Basic theme struct
    test_theme_struct = %Theme{id: :test_theme, name: "Test Theme"}
    Theme.register(test_theme_struct)
    :ok
  end

  describe "Table Rendering" do
    # TODO: Add tests for rendering table elements received from the Layout Engine.
    # These tests should verify:
    # - Correct application of cell alignment (left, center, right) based on attributes/styles.
    # - Correct application of theme styles (header, data rows, borders, etc.).

    test "renders basic table structure" do
      # Setup: Create a sample positioned table element (from Layout)
      # Setup: Define a theme
      # Execute: Call Renderer.render with the element and theme
      # Assert: Check the final character grid/cell list for correct padding/positioning
      flunk("Test not implemented: Alignment is currently hardcoded to left.")
    end

    test "applies theme styles to table header and data rows" do
      # Setup theme and element
      # Get the theme registered in setup
      test_theme = Theme.get(:test_theme)
      # Define your positioned_table element here...
      positioned_table = %{
        type: :table,
        x: 1,
        y: 2,
        width: 15,
        height: 5,
        attrs: %{
          _headers: ["H1", "H2"],
          _data: [["D1", "D2"]],
          _col_widths: [5, 5],
          # ensure this matches component style key if needed
          _component_type: :table,
          # Add base styles if needed
          style: %{}
        }
      }

      # Act
      rendered_cells = Renderer.render_to_cells([positioned_table], test_theme)

      # Assert header style
      # Assuming render_table_row applies theme style correctly
      header_cell =
        Enum.find(rendered_cells, fn {cx, cy, _, _, _, _} ->
          cx == 1 and cy == 2
        end)

      # Check header fg/bg from Theme.component_style
      assert {_, _, "H", :cyan, :default, _} = header_cell

      # Assert data row style
      data_cell =
        Enum.find(rendered_cells, fn {cx, cy, _, _, _, _} ->
          cx == 1 and cy == 4
        end)

      # Check data fg/bg from Theme.component_style
      assert {_, _, "D", :default, :default, _} = data_cell
    end

    # Skipped test
    @tag :skip
    test "renders table cell alignment correctly" do
      # Setup: Create a sample positioned table element (from Layout)
      # Setup: Define a theme
      # Execute: Call Renderer.render with the element and theme
      # Assert: Check the final character grid/cell list for correct padding/positioning
      flunk("Test not implemented: Alignment is currently hardcoded to left.")
    end
  end
end
