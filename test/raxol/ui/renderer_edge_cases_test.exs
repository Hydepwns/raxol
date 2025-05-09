defmodule Raxol.UI.RendererEdgeCasesTest do
  use ExUnit.Case, async: true
  require Logger

  alias Raxol.UI.Renderer
  alias Raxol.UI.Theming.Theme
  alias Raxol.Core.UserPreferences

  setup_all do
    Raxol.UI.Theming.Theme.init()
    {:ok, _pid} = UserPreferences.start_link(%{name: UserPreferences})
    :ok
  end

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

      # Create a test theme using the Theme struct
      theme = %Theme{
        id: :test_theme_empty,
        name: "Test Theme Empty",
        description: "A test theme for empty elements",
        colors: %{
          foreground: :white,
          background: :black
        },
        fonts: %{},
        component_styles: %{},
        variants: %{}
      }

      Raxol.UI.Theming.Theme.register(theme)

      # Render empty elements
      result = Renderer.render_to_cells(elements, theme)

      # Should return an empty list of cells
      assert result == []
    end

    test "handles nil elements" do
      # List with nil elements
      elements = [nil, nil]

      theme = %Theme{
        id: :test_theme_nil,
        name: "Test Theme Nil",
        description: "A test theme for nil elements",
        colors: %{
          foreground: :white,
          background: :black
        },
        fonts: %{},
        component_styles: %{},
        variants: %{}
      }

      Raxol.UI.Theming.Theme.register(theme)

      # Render nil elements
      result = Renderer.render_to_cells(elements, theme)

      # Should return an empty list of cells
      assert result == []
    end

    test "handles elements with missing required attributes" do
      # Create elements with missing required attributes
      elements = [
        # Missing content
        %{type: :text, x: 0, y: 0},
        # Missing width/height
        %{type: :panel, x: 0, y: 0},
        # Missing x/y
        %{type: :box, width: 10, height: 5},
        # Unknown type
        %{type: :unknown_type, x: 0, y: 0, width: 10, height: 5}
      ]

      theme = %Theme{
        id: :test_theme_missing_attrs,
        name: "Test Theme Missing Attrs",
        description: "A test theme for missing attributes",
        colors: %{
          foreground: :white,
          background: :black,
          border: :green
        },
        fonts: %{},
        component_styles: %{},
        variants: %{}
      }

      Raxol.UI.Theming.Theme.register(theme)

      # Should not crash
      result = Renderer.render_to_cells(elements, theme)

      # It may render some parts (e.g., box outline) but should gracefully handle missing attributes
      # The exact result depends on implementation details, but it should not crash
      assert is_list(result)
    end

    test "handles overlapping elements" do
      # Create overlapping elements
      elements = [
        %{
          type: :box,
          x: 0,
          y: 0,
          width: 10,
          height: 5,
          style: %{background: :blue}
        },
        %{
          type: :box,
          x: 5,
          y: 2,
          width: 10,
          height: 5,
          style: %{background: :red}
        }
      ]

      theme = %Theme{
        id: :test_theme_overlap,
        name: "Test Theme Overlap",
        description: "A test theme for overlapping elements",
        colors: %{
          foreground: :white,
          blue_fg: :cyan,
          red_fg: :yellow,
          background: :black,
          blue_bg: :blue,
          red_bg: :red,
          border: :green
        },
        fonts: %{},
        component_styles: %{},
        variants: %{}
      }

      Raxol.UI.Theming.Theme.register(theme)
      # Render overlapping elements
      result = Renderer.render_to_cells(elements, theme)

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
              %{
                type: :text,
                x: 1,
                y: 1,
                text: "Nested",
                style: %{foreground: :yellow}
              }
            ]
          }
        ]
      }

      theme = %Theme{
        id: :test_theme_nested,
        name: "Test Theme Nested",
        description: "A test theme for nested elements",
        colors: %{
          foreground: :white,
          yellow_fg: :yellow,
          background: :black,
          blue_bg: :blue,
          red_bg: :red
        },
        fonts: %{},
        component_styles: %{},
        variants: %{}
      }

      Raxol.UI.Theming.Theme.register(theme)

      # Render nested elements
      result = Renderer.render_to_cells([parent], theme)

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
      element = %{type: :text, x: 0, y: 0, text: "Test"}

      # Render with nil theme
      result = Renderer.render_to_cells([element], nil)

      # Should still render using default styles
      assert result != []
    end

    test "handles missing theme colors" do
      # Create elements with styles referencing missing theme colors
      elements = [
        %{
          type: :text,
          x: 0,
          y: 0,
          text: "Test",
          style: %{foreground: :missing_color}
        },
        %{
          type: :box,
          x: 5,
          y: 0,
          width: 10,
          height: 5,
          style: %{background: :another_missing}
        }
      ]

      theme = %Theme{
        id: :test_theme_missing_colors,
        name: "Test Theme Missing Colors",
        description: "A test theme with limited colors",
        colors: %{
          foreground: :white,
          background: :black
        },
        fonts: %{},
        component_styles: %{},
        variants: %{}
      }

      Raxol.UI.Theming.Theme.register(theme)

      # Render with missing theme colors
      result = Renderer.render_to_cells(elements, theme)

      # Should fall back to default colors when specific colors are missing

      # Check text element
      text_cell = get_cell_at(result, 0, 0)
      assert text_cell != nil
      {_, _, "T", fg, _, _} = text_cell
      assert fg == :white

      # Check box element
      box_cell = get_cell_at(result, 5, 0)
      assert box_cell != nil
      {_, _, _, _, bg, _} = box_cell
      assert bg == :black
    end

    test "handles style overrides" do
      # Create an element with explicit style overrides
      element = %{
        type: :text,
        x: 0,
        y: 0,
        text: "Test",
        style: %{
          foreground: :custom_fg,
          background: :custom_bg,
          bold: true,
          underline: true
        }
      }

      theme = %Theme{
        id: :test_theme_overrides,
        name: "Test Theme Overrides",
        description: "A test theme for style overrides",
        colors: %{
          foreground: :theme_fg,
          custom_fg: :red,
          background: :theme_bg,
          custom_bg: :blue
        },
        fonts: %{},
        component_styles: %{
          text: %{fg: :component_fg, style: [:bold_false]}
        },
        variants: %{}
      }

      Raxol.UI.Theming.Theme.register(theme)

      # Render with style overrides
      result = Renderer.render_to_cells([element], theme)

      # Check that the explicit styles are applied
      cell = get_cell_at(result, 0, 0)
      assert cell != nil
      {_, _, "T", fg, bg, style_attrs} = cell
      assert fg == :custom_fg
      assert bg == :custom_bg
      assert :bold in style_attrs
      assert :underline in style_attrs
    end

    test "handles explicit border style override" do
      element = %{
        type: :box,
        x: 0,
        y: 0,
        width: 3,
        height: 3,
        style: %{
          border: %{
            style: :double,
            fg: :red
          }
        }
      }

      theme = %Theme{
        id: :test_theme_border_override,
        name: "Test Theme Border Override",
        description: "A test theme for border overrides",
        colors: %{
          foreground: :white,
          background: :black,
          border: :blue,
          red: :red
        },
        fonts: %{},
        component_styles: %{
          box: %{
            border_style: :single,
            border_fg: :blue
          }
        },
        variants: %{}
      }

      Raxol.UI.Theming.Theme.register(theme)
      result = Renderer.render_to_cells([element], theme)
      cell = get_cell_at(result, 0, 0)
      assert cell != nil
      {_, _, char, fg, _, _} = cell
      assert char == "╔"
      assert fg == :red
    end

    test "handles default border style" do
      element = %{
        type: :box,
        x: 0,
        y: 0,
        width: 3,
        height: 3
      }

      theme = %Theme{
        id: :test_theme_default_border,
        name: "Test Theme Default Border",
        description: "A test theme for default borders",
        colors: %{
          foreground: :white,
          background: :black,
          border_color: :green
        },
        fonts: %{},
        component_styles: %{
          box: %{
            border_style: :single,
            border_fg: :green
          }
        },
        variants: %{}
      }

      Raxol.UI.Theming.Theme.register(theme)
      result = Renderer.render_to_cells([element], theme)
      cell = get_cell_at(result, 0, 0)
      assert cell != nil
      {_, _, char, fg, _, _} = cell
      assert char == "┌"
      assert fg == :green
    end

    test "handles no border" do
      element = %{
        type: :box,
        x: 0,
        y: 0,
        width: 3,
        height: 3,
        style: %{
          border: :none
        }
      }

      theme = %Theme{
        id: :test_theme_no_border,
        name: "Test Theme No Border",
        description: "A test theme for no border",
        colors: %{
          foreground: :white,
          background: :black,
          border_color: :green
        },
        fonts: %{},
        component_styles: %{
          box: %{border_style: :single, border_fg: :green}
        },
        variants: %{}
      }

      Raxol.UI.Theming.Theme.register(theme)
      result = Renderer.render_to_cells([element], theme)
      cell = get_cell_at(result, 0, 0)
      assert cell != nil
      {_, _, char, _, _, _} = cell
      assert char != "┌"
      assert char != "╔"
    end
  end

  describe "special components" do
    test "handles tables with varying row lengths" do
      # Table with varying row lengths
      table = %{
        type: :table,
        x: 0,
        y: 0,
        headers: ["Col 1", "Col 2", "Col 3"],
        data: [
          ["Row 1-1", "Row 1-2"],
          ["Row 2-1", "Row 2-2", "Row 2-3"],
          ["Row 3-1"]
        ],
        style: %{}
      }

      theme = %Theme{
        id: :test_theme_table_varying,
        name: "Test Theme Table Varying",
        description: "A test theme for table with varying rows",
        colors: %{
          foreground: :white,
          background: :black,
          table_header_fg: :yellow,
          table_header_bg: :blue,
          table_row_fg: :white,
          table_row_bg: :black,
          table_border: :cyan
        },
        fonts: %{},
        component_styles: %{
          table: %{
            header_fg: :yellow,
            header_bg: :blue,
            row_fg: :white,
            row_bg: :black,
            border_color: :cyan
          }
        },
        variants: %{}
      }

      Raxol.UI.Theming.Theme.register(theme)

      # Render table
      result = Renderer.render_to_cells([table], theme)

      # Should render correctly, padding shorter rows
      assert result != []
      header_col1 = Enum.find(result, fn {_, _, c, _, _, _} -> c == "Col 1" end)
      assert header_col1 != nil
      {_hx, _hy, _, hfg, hbg, _} = header_col1
      assert hfg == :yellow
      assert hbg == :blue

      data_row1_col1 =
        Enum.find(result, fn {_, _, c, _, _, _} -> c == "Row 1-1" end)

      assert data_row1_col1 != nil
      {_dx, _dy, _, dfg, dbg, _} = data_row1_col1
      assert dfg == :white
      assert dbg == :black
    end

    test "handles very large elements" do
      # Element larger than typical terminal size
      large_box = %{
        type: :box,
        x: 0,
        y: 0,
        width: 200,
        height: 100,
        style: %{background: :blue}
      }

      theme = %Theme{
        id: :test_theme_large,
        name: "Test Theme Large",
        description: "A test theme for large elements",
        colors: %{
          foreground: :white,
          background: :black,
          border: :green,
          blue_bg: :blue
        },
        fonts: %{},
        component_styles: %{},
        variants: %{}
      }

      Raxol.UI.Theming.Theme.register(theme)

      # Render large element
      result = Renderer.render_to_cells([large_box], theme)

      # Should not crash and produce a list of cells
      assert is_list(result)

      if result != [] do
        assert Enum.any?(result, fn {_, _, _, _, bg, _} -> bg == :blue end)
      else
        assert large_box.width > 0 && large_box.height > 0 && result != [],
               "Expected cells for a large box, but got none."
      end
    end

    test "handles non-ASCII characters in text" do
      unicode_text = %{
        type: :text,
        x: 0,
        y: 0,
        text: "Unicode: äöü 你好 👋🌍",
        style: %{}
      }

      theme = %Theme{
        id: :test_theme_unicode,
        name: "Test Theme Unicode",
        description: "A test theme for unicode text",
        colors: %{
          foreground: :white,
          background: :black
        },
        fonts: %{},
        component_styles: %{},
        variants: %{}
      }

      Raxol.UI.Theming.Theme.register(theme)
      result = Renderer.render_to_cells([unicode_text], theme)
      assert result != []
      first_char_cell = get_cell_at(result, 0, 0)
      assert first_char_cell != nil
      {_, _, char, _, _, _} = first_char_cell
      assert char == "U"
      assert Enum.any?(result, fn {_, _, c, _, _, _} -> c == "ä" end)
      assert Enum.any?(result, fn {_, _, c, _, _, _} -> c == "你" end)
      assert Enum.any?(result, fn {_, _, c, _, _, _} -> c == "👋" end)
    end
  end

  describe "component composition" do
    # Simulating a simple custom component structure for testing composition
    defmodule MyCustomComponent do
      def render(props) do
        text_content = Map.get(props, :text, "Default")

        %{
          type: :box,
          x: Map.get(props, :x, 0),
          y: Map.get(props, :y, 0),
          width: Map.get(props, :width, 10),
          height: Map.get(props, :height, 3),
          style: %{background: Map.get(props, :bgColor, :cyan)},
          children: [
            %{
              type: :text,
              x: 1,
              y: 1,
              text: text_content,
              style: %{foreground: Map.get(props, :fgColor, :black)}
            }
          ]
        }
      end
    end

    test "handles basic component composition" do
      # Element that uses the custom component
      composed_element = %{
        type: :my_custom_component_output,
        children_elements: [MyCustomComponent.render(%{text: "Hello"})]
      }

      theme = %Theme{
        id: :test_theme_composition1,
        name: "Test Theme Composition 1",
        description: "A test theme for composition",
        colors: %{
          foreground: :white,
          background: :black,
          cyan_bg: :cyan,
          black_fg: :black
        },
        fonts: %{},
        component_styles: %{},
        variants: %{}
      }

      Raxol.UI.Theming.Theme.register(theme)

      # Render the composed structure (output of MyCustomComponent.render)
      result =
        Renderer.render_to_cells(
          [MyCustomComponent.render(%{text: "Hello"})],
          theme
        )

      assert result != []
      assert Enum.any?(result, fn {_, _, _, _, bg, _} -> bg == :cyan end)
      text_cell = Enum.find(result, fn {_, _, c, _, _, _} -> c == "H" end)
      assert text_cell != nil
      {_, _, _, fg, _, _} = text_cell
      assert fg == :black
    end

    test "handles deep nesting of components" do
      # Define a component that can nest itself conceptually
      # For the test, construct the deeply nested map structure directly
      deep_nesting_data_generator = fn me, level, max_level, props ->
        if level >= max_level do
          %{
            type: :text,
            x: 1,
            y: 1,
            text: Map.get(props, :text, "End"),
            style: %{foreground: Map.get(props, :fgEnd, :color5)}
          }
        else
          %{
            type: :box,
            x: 1,
            y: 1,
            width: 10 - level * 2,
            height: 5 - level,
            style: %{background: Map.get(props, :"color#{level}", :color1)},
            children: [
              me.(me, level + 1, max_level, props)
            ]
          }
        end
      end

      deep_nesting =
        deep_nesting_data_generator.(deep_nesting_data_generator, 1, 5, %{
          text: "Deep",
          fgEnd: :color5,
          color1: :color1,
          color2: :color2,
          color3: :color3,
          color4: :color4
        })

      theme = %Theme{
        id: :test_theme_deep_nest,
        name: "Test Theme Deep Nest",
        description: "A test theme for deep nesting",
        colors: %{
          foreground: :white,
          background: :black,
          color1: :blue,
          color2: :green,
          color3: :cyan,
          color4: :red,
          color5: :magenta
        },
        fonts: %{},
        component_styles: %{},
        variants: %{}
      }

      Raxol.UI.Theming.Theme.register(theme)

      result = Renderer.render_to_cells([deep_nesting], theme)
      assert result != []

      assert Enum.any?(result, fn {x, y, _, _, bg, _} -> bg == :blue end),
             "Outermost box with :blue bg not found"

      assert Enum.any?(result, fn {_, _, _, _, bg, _} -> bg == :cyan end),
             "Inner box with :cyan bg not found"

      text_cell = Enum.find(result, fn {_, _, char, _, _, _} -> char == "D" end)
      assert text_cell != nil, "Text 'Deep' not found"
      {_, _, _, fg, _, _} = text_cell
      assert fg == :magenta
    end

    test "handles recursive composition" do
      # Define a component that includes itself (simplified structure for testing map)
      # Max depth to prevent infinite recursion in test data generation
      recursive_data_generator = fn me, data, current_depth, max_depth ->
        if current_depth >= max_depth do
          %{
            type: :text,
            x: 0,
            y: 0,
            text: data.text,
            style: %{foreground: data.fg_color}
          }
        else
          %{
            type: :box,
            x: data.x,
            y: data.y,
            width: data.width,
            height: data.height,
            style: %{background: data.bg_color},
            children: [
              me.(
                me,
                %{
                  text: "L#{current_depth + 1}",
                  fg_color: data.child_fg,
                  x: 1,
                  y: 1,
                  width: data.width - 2,
                  height: data.height - 2,
                  bg_color: data.child_bg,
                  child_fg: data.child_fg,
                  child_bg: data.child_bg
                },
                current_depth + 1,
                max_depth
              )
            ]
          }
        end
      end

      initial_props = %{
        text: "L0",
        fg_color: :color5,
        x: 0,
        y: 0,
        width: 10,
        height: 5,
        bg_color: :color1,
        child_fg: :color5,
        child_bg: :color2
      }

      recursive_box =
        recursive_data_generator.(recursive_data_generator, initial_props, 1, 3)

      theme = %Theme{
        id: :test_theme_recursive,
        name: "Test Theme Recursive",
        description: "A test theme for recursive composition",
        colors: %{
          foreground: :white,
          background: :black,
          border: :white,
          color1: :red,
          color2: :green,
          color3: :blue,
          color4: :magenta,
          color5: :cyan
        },
        fonts: %{},
        component_styles: %{},
        variants: %{}
      }

      Raxol.UI.Theming.Theme.register(theme)
      result = Renderer.render_to_cells([recursive_box], theme)
      assert result != []
      assert Enum.any?(result, fn {_, _, _, _, bg, _} -> bg == :red end)
      assert Enum.any?(result, fn {_, _, _, _, bg, _} -> bg == :green end)

      final_text_cell =
        Enum.find(result, fn {_, _, c, _, _, _} ->
          c == "L" and length(result) > 0 and
            elem(
              Enum.at(
                result,
                Enum.find_index(result, fn {_, _, ch, _, _, _} -> ch == "L" end)
              ),
              2
            ) == "L"
        end)

      l_text_cell =
        Enum.find(result, fn {_, _, c, fg, _, _} -> c == "L" && fg == :cyan end)

      assert l_text_cell != nil,
             "Final nested text 'L3' with fg :cyan not found"
    end
  end
end
