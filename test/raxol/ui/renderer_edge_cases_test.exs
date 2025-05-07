defmodule Raxol.UI.RendererEdgeCasesTest do
  use ExUnit.Case, async: true
  require Logger

  alias Raxol.UI.Renderer

  # Utility function to get cells for a specific position
  defp get_cell_at(cells, x, y) do
    Enum.find(cells, fn {cx, cy, _, _, _, _} -> cx == x && cy == y end)
  end

  # Utility function to get cells with a specific character
  defp get_cells_with_char(cells, char) do
    Enum.filter(cells, fn {_, _, c, _, _, _} -> c == char end)
  end

  describe "rendering edge cases" do
    test "handles empty elements" do
      # Empty list of elements
      elements = []

      # Create a test theme
      theme = %{
        foreground: %{default: :white},
        background: %{default: :black}
      }

      # Render empty elements
      result = Renderer.render(elements, theme)

      # Should return an empty list of cells
      assert result == []
    end

    test "handles nil elements" do
      # List with nil elements
      elements = [nil, nil]

      # Create a test theme
      theme = %{
        foreground: %{default: :white},
        background: %{default: :black}
      }

      # Render nil elements
      result = Renderer.render(elements, theme)

      # Should return an empty list of cells
      assert result == []
    end

    test "handles elements with missing required attributes" do
      # Create elements with missing required attributes
      elements = [
        %{type: :text}, # Missing content
        %{type: :panel, x: 0, y: 0}, # Missing width/height
        %{type: :box, width: 10, height: 5}, # Missing x/y
        %{type: :unknown_type, x: 0, y: 0, width: 10, height: 5} # Unknown type
      ]

      # Create a test theme
      theme = %{
        foreground: %{default: :white},
        background: %{default: :black},
        border: %{default: :green}
      }

      # Should not crash
      result = Renderer.render(elements, theme)

      # It may render some parts (e.g., box outline) but should gracefully handle missing attributes
      # The exact result depends on implementation details, but it should not crash
      assert is_list(result)
    end

    test "handles overlapping elements" do
      # Create overlapping elements
      elements = [
        %{type: :box, x: 0, y: 0, width: 10, height: 5, style: %{background: :blue}},
        %{type: :box, x: 5, y: 2, width: 10, height: 5, style: %{background: :red}}
      ]

      # Create a test theme
      theme = %{
        foreground: %{default: :white, blue: :cyan, red: :yellow},
        background: %{default: :black, blue: :blue, red: :red},
        border: %{default: :green}
      }

      # Render overlapping elements
      result = Renderer.render(elements, theme)

      # Should have cells for both boxes
      # The overlapping cells should use the style of the last element (red box)

      # Check a cell unique to first box (blue)
      cell_blue = get_cell_at(result, 2, 1)
      assert cell_blue != nil
      {_, _, _, _, bg, _} = cell_blue
      assert bg == :blue

      # Check a cell unique to second box (red)
      cell_red = get_cell_at(result, 12, 6)
      assert cell_red != nil
      {_, _, _, _, bg, _} = cell_red
      assert bg == :red

      # Check a cell in the overlap area - should have red background (last element wins)
      cell_overlap = get_cell_at(result, 8, 3)
      assert cell_overlap != nil
      {_, _, _, _, bg, _} = cell_overlap
      assert bg == :red
    end

    test "handles nested elements" do
      # Create nested elements
      parent = %{
        type: :panel,
        x: 0,
        y: 0,
        width: 20,
        height: 10,
        style: %{background: :blue},
        children: [
          %{
            type: :panel,
            x: 2,
            y: 2,
            width: 10,
            height: 5,
            style: %{background: :red},
            children: [
              %{type: :text, x: 1, y: 1, content: "Nested", style: %{foreground: :yellow}}
            ]
          }
        ]
      }

      # Create a test theme
      theme = %{
        foreground: %{default: :white, yellow: :yellow},
        background: %{default: :black, blue: :blue, red: :red}
      }

      # Render nested elements
      result = Renderer.render([parent], theme)

      # Check that the nesting is handled correctly

      # Check a cell in parent panel (blue)
      cell_parent = get_cell_at(result, 5, 0)
      assert cell_parent != nil
      {_, _, _, _, bg, _} = cell_parent
      assert bg == :blue

      # Check a cell in child panel (red)
      cell_child = get_cell_at(result, 5, 3)
      assert cell_child != nil
      {_, _, _, _, bg, _} = cell_child
      assert bg == :red

      # Check that the text in the nested panel is rendered with correct coordinates and style
      text_cells = get_cells_with_char(result, "N")
      assert length(text_cells) == 1
      {x, y, _, fg, _, _} = hd(text_cells)

      # Text should be at parent.x + child.x + text.x = 0 + 2 + 1 = 3
      # and parent.y + child.y + text.y = 0 + 2 + 1 = 3
      assert x == 3
      assert y == 3
      assert fg == :yellow
    end
  end

  describe "theme handling edge cases" do
    test "handles missing theme" do
      # Create a simple element
      element = %{type: :text, x: 0, y: 0, content: "Test"}

      # Render with nil theme
      result = Renderer.render([element], nil)

      # Should still render using default styles
      assert result != []
    end

    test "handles missing theme colors" do
      # Create elements with styles referencing missing theme colors
      elements = [
        %{type: :text, x: 0, y: 0, content: "Test", style: %{foreground: :missing_color}},
        %{type: :box, x: 5, y: 0, width: 10, height: 5, style: %{background: :another_missing}}
      ]

      # Create a theme with limited colors
      theme = %{
        foreground: %{default: :white},
        background: %{default: :black}
      }

      # Render with missing theme colors
      result = Renderer.render(elements, theme)

      # Should fall back to default colors when specific colors are missing

      # Check text element
      text_cell = get_cell_at(result, 0, 0)
      assert text_cell != nil
      {_, _, "T", fg, _, _} = text_cell
      # Should use default foreground color since missing_color is not defined
      assert fg == :white

      # Check box element
      box_cell = get_cell_at(result, 5, 0)
      assert box_cell != nil
      {_, _, _, _, bg, _} = box_cell
      # Should use default background color since another_missing is not defined
      assert bg == :black
    end

    test "handles style overrides" do
      # Create element with style that should override theme defaults
      element = %{
        type: :text,
        x: 0,
        y: 0,
        content: "Test",
        style: %{
          foreground: :custom_fg,
          background: :custom_bg,
          bold: true,
          underline: true
        }
      }

      # Create a theme with custom colors
      theme = %{
        foreground: %{default: :white, custom_fg: :magenta},
        background: %{default: :black, custom_bg: :cyan}
      }

      # Render with style overrides
      result = Renderer.render([element], theme)

      # Check that style overrides are applied
      cell = get_cell_at(result, 0, 0)
      assert cell != nil
      {_, _, "T", fg, bg, modifiers} = cell

      # Custom foreground and background should be applied
      assert fg == :magenta
      assert bg == :cyan

      # Modifiers should include bold and underline
      assert modifiers[:bold] == true
      assert modifiers[:underline] == true
    end
  end

  describe "special components" do
    test "handles tables with varying row lengths" do
      # Create a table with rows of different lengths
      table = %{
        type: :table,
        x: 0,
        y: 0,
        headers: ["Col 1", "Col 2", "Col 3"],
        data: [
          ["Row 1-1", "Row 1-2"], # Missing third column
          ["Row 2-1", "Row 2-2", "Row 2-3"],
          ["Row 3-1"] # Missing second and third columns
        ],
        style: %{}
      }

      # Create a theme
      theme = %{
        foreground: %{default: :white, header: :yellow},
        background: %{default: :black},
        border: %{default: :green}
      }

      # Render table
      result = Renderer.render([table], theme)

      # Should handle varying row lengths without crashing
      assert result != []

      # Verify the table headers are rendered
      header_cells = get_cells_with_char(result, "C")
      assert length(header_cells) > 0
    end

    test "handles very large elements" do
      # Create a very large element that might challenge the renderer
      large_box = %{
        type: :box,
        x: 0,
        y: 0,
        width: 1000,
        height: 500,
        style: %{}
      }

      # Create a theme
      theme = %{
        foreground: %{default: :white},
        background: %{default: :black},
        border: %{default: :green}
      }

      # Render large element
      result = Renderer.render([large_box], theme)

      # Should handle large dimensions without crashing
      assert result != []

      # Check that cells at the extremes are rendered
      top_left = get_cell_at(result, 0, 0)
      assert top_left != nil

      # Don't check cells at maximum coordinates, as implementations might optimize or limit rendering
      # Just ensure something was rendered
      assert length(result) > 100
    end

    test "handles non-ASCII characters in text" do
      # Create text with non-ASCII characters
      text = %{
        type: :text,
        x: 0,
        y: 0,
        content: "Unicode: äöü 你好 👋🌍",
        style: %{}
      }

      # Create a theme
      theme = %{
        foreground: %{default: :white},
        background: %{default: :black}
      }

      # Render text with unicode
      result = Renderer.render([text], theme)

      # Should handle Unicode characters
      assert result != []

      # Verify some Unicode characters are rendered
      unicode_chars = get_cells_with_char(result, "ä") ++
                     get_cells_with_char(result, "你") ++
                     get_cells_with_char(result, "👋")

      # At least some of these should be rendered
      assert length(unicode_chars) > 0
    end
  end

  describe "component composition" do
    test "handles deep nesting of components" do
      # Create deeply nested components
      deep_nesting = %{
        type: :panel,
        x: 0,
        y: 0,
        width: 50,
        height: 20,
        style: %{background: :color1},
        children: [
          %{
            type: :panel,
            x: 5,
            y: 2,
            width: 40,
            height: 15,
            style: %{background: :color2},
            children: [
              %{
                type: :panel,
                x: 5,
                y: 2,
                width: 30,
                height: 10,
                style: %{background: :color3},
                children: [
                  %{
                    type: :panel,
                    x: 5,
                    y: 2,
                    width: 20,
                    height: 6,
                    style: %{background: :color4},
                    children: [
                      %{
                        type: :text,
                        x: 2,
                        y: 2,
                        content: "Deeply Nested",
                        style: %{foreground: :color5}
                      }
                    ]
                  }
                ]
              }
            ]
          }
        ]
      }

      # Create a theme with the needed colors
      theme = %{
        foreground: %{default: :white, color5: :magenta},
        background: %{
          default: :black,
          color1: :blue,
          color2: :green,
          color3: :cyan,
          color4: :red
        }
      }

      # Render deeply nested components
      result = Renderer.render([deep_nesting], theme)

      # Should handle deep nesting without crashing
      assert result != []

      # Verify the text at the deepest level
      text_cells = get_cells_with_char(result, "D")
      assert length(text_cells) == 1

      # Check position of the text (should be at x=0+5+5+5+2=17, y=0+2+2+2+2=8)
      {x, y, _, fg, _, _} = hd(text_cells)
      assert x == 17
      assert y == 8
      assert fg == :magenta

      # Check that backgrounds at each level are rendered correctly
      level1_cell = get_cell_at(result, 2, 1) # In outermost panel
      assert level1_cell != nil
      {_, _, _, _, bg1, _} = level1_cell
      assert bg1 == :blue

      level2_cell = get_cell_at(result, 7, 4) # In second level panel
      assert level2_cell != nil
      {_, _, _, _, bg2, _} = level2_cell
      assert bg2 == :green

      level3_cell = get_cell_at(result, 12, 7) # In third level panel
      assert level3_cell != nil
      {_, _, _, _, bg3, _} = level3_cell
      assert bg3 == :cyan

      level4_cell = get_cell_at(result, 17, 7) # In fourth level panel
      assert level4_cell != nil
      {_, _, _, _, bg4, _} = level4_cell
      assert bg4 == :red
    end

    test "handles recursive composition" do
      # Create a function that builds a recursive tree of boxes
      build_recursive_box = fn
        _, 0 -> nil
        build_fn, depth ->
          %{
            type: :box,
            x: depth * 2,
            y: depth * 2,
            width: 20 - depth * 3,
            height: 10 - depth * 2,
            style: %{background: String.to_atom("color#{depth}")},
            children: [build_fn.(build_fn, depth - 1)]
          }
      end

      # Create a recursive structure with depth 5
      recursive_box = build_recursive_box.(build_recursive_box, 5)

      # Create a theme with the needed colors
      theme = %{
        foreground: %{default: :white},
        background: %{
          default: :black,
          color1: :red,
          color2: :green,
          color3: :blue,
          color4: :magenta,
          color5: :cyan
        },
        border: %{default: :white}
      }

      # Render recursive structure
      result = Renderer.render([recursive_box], theme)

      # Should handle recursive composition without crashing
      assert result != []

      # Verify cells from each level
      level5_cell = get_cell_at(result, 10, 5) # In level 5 box
      assert level5_cell != nil
      {_, _, _, _, bg5, _} = level5_cell
      assert bg5 == :cyan

      level3_cell = get_cell_at(result, 6, 3) # In level 3 box
      assert level3_cell != nil
      {_, _, _, _, bg3, _} = level3_cell
      assert bg3 == :blue
    end
  end
end
