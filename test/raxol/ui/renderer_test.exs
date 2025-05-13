defmodule Raxol.UI.RendererTest do
  use ExUnit.Case, async: true

  alias Raxol.UI.Renderer
  alias Raxol.UI.Theming.Theme
  alias Raxol.Core.UserPreferences

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
    # Initialize the theme system
    Theme.init()

    # Initialize UserPreferences in test mode
    {:ok, _pid} = UserPreferences.start_link(test_mode?: true)

    # Create a test theme with the required structure
    test_theme = %Theme{
      id: :test_theme,
      name: "Test Theme",
      colors: %{
        primary: Raxol.Style.Colors.Color.from_hex("#0077CC"),
        secondary: Raxol.Style.Colors.Color.from_hex("#666666"),
        background: Raxol.Style.Colors.Color.from_hex("#000000"),
        foreground: Raxol.Style.Colors.Color.from_hex("#FFFFFF")
      },
      component_styles: %{
        table: %{
          header: %{
            foreground: :cyan,
            background: :default
          },
          data: %{
            foreground: :default,
            background: :default
          }
        }
      },
      variants: %{},
      metadata: %{
        author: "Test",
        version: "1.0.0"
      }
    }

    # Register the test theme
    Theme.register(test_theme)

    {:ok, %{theme: test_theme}}
  end

  describe "Table Rendering" do
    test "renders basic table structure" do
      # Setup: Create a sample positioned table element (from Layout)
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
          _component_type: :table,
          style: %{}
        }
      }

      # Execute: Call Renderer.render_to_cells with the element and theme
      rendered_cells =
        Renderer.render_to_cells([positioned_table], Theme.get(:test_theme))

      # Assert: Check the final character grid/cell list for correct padding/positioning
      assert length(rendered_cells) > 0

      # Verify header cells
      header_cell = find_cell(rendered_cells, 1, 2)
      assert header_cell != nil
      assert elem(header_cell, 2) == "H"

      # Verify data cells
      data_cell = find_cell(rendered_cells, 1, 4)
      assert data_cell != nil
      assert elem(data_cell, 2) == "D"
    end

    test "applies theme styles to table header and data rows" do
      # Setup theme and element
      test_theme = Theme.get(:test_theme)

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
          _component_type: :table,
          style: %{}
        }
      }

      # Act
      rendered_cells = Renderer.render_to_cells([positioned_table], test_theme)

      # Assert header style
      header_cell = find_cell(rendered_cells, 1, 2)
      assert header_cell != nil
      {_, _, "H", fg, bg, _} = header_cell
      assert fg == :cyan
      assert bg == :default

      # Assert data row style
      data_cell = find_cell(rendered_cells, 1, 4)
      assert data_cell != nil
      {_, _, "D", fg, bg, _} = data_cell
      assert fg == :default
      assert bg == :default
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
