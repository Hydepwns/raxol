defmodule Raxol.UI.Components.Display.TableTest do
  use ExUnit.Case, async: true

  alias Raxol.UI.Components.Display.Table
  # Assuming Theme structure for context
  alias Raxol.UI.Theming.Theme

  # Helper to extract text content from rendered elements at a specific line
  defp get_line_text(elements, y) do
    elements
    |> Enum.filter(&(&1.y == y && &1.type == :text))
    |> Enum.sort_by(&(&1.x || 0))
    |> Enum.map_join(& &1.text)
  end

  # Helper to find a specific cell element
  defp find_cell(elements, y, text_content) do
    Enum.find(elements, fn el ->
      el.y == y && el.type == :text && el.text == text_content
    end)
  end

  # Basic rendering context
  defp default_context(width \\ 80) do
    %{
      max_width: width,
      # Mock theme structure
      theme: %Theme{
        component_styles: %{
          "Table" => %{
            header: %{fg: :blue, bold: true},
            data: %{fg: :white}
          }
        }
      }
      # Add other context keys if needed by the component
    }
  end

  describe "Table Rendering" do
    test "renders basic table structure" do
      props = %{
        headers: ["ID", "Name"],
        rows: [[1, "Alice"], [2, "Bob"]]
      }

      {:ok, component_state} = Table.init(props)
      # Assume context has theme
      context_with_props = Map.put(default_context(), :attrs, props)
      elements = Table.render(component_state, context_with_props)

      # Check header rendering (y=1 assuming top border y=0)
      header_line = get_line_text(elements, 1)
      assert header_line =~ "│ID"
      assert header_line =~ "│Name│"

      # Check data row rendering (y=3 assuming separator y=2)
      row1_line = get_line_text(elements, 3)
      assert row1_line =~ "│1"
      assert row1_line =~ "│Alice"

      row2_line = get_line_text(elements, 4)
      assert row2_line =~ "│2"
      assert row2_line =~ "│Bob"

      # Check borders (example: top border)
      top_border = get_line_text(elements, 0)
      assert top_border =~ "┌" and top_border =~ "┬" and top_border =~ "┐"
    end

    test "renders without borders" do
      props = %{
        headers: ["A", "B"],
        rows: [[1, 2]],
        border_style: :none
      }

      {:ok, component_state} = Table.init(props)
      context_with_props = Map.put(default_context(), :attrs, props)
      elements = Table.render(component_state, context_with_props)

      # No border elements should exist
      assert Enum.empty?(Enum.filter(elements, &(&1.text =~ ~r/[┌┐└┘─│┼┬┴]/)))

      # Check content rendering (y=0, 1)
      header_line = get_line_text(elements, 0)
      # Check spacing if vertical separator is space
      assert header_line =~ " A "
      assert header_line =~ " B "

      row1_line = get_line_text(elements, 1)
      assert row1_line =~ " 1 "
      assert row1_line =~ " 2 "
    end
  end

  describe "Column Width Calculation" do
    test "auto-calculates width based on content" do
      props = %{
        headers: ["Short", "Looooong Header"],
        rows: [["Data", "More Data"]],
        column_widths: :auto,
        # Simplify assertions
        border_style: :none,
        width: :auto
      }

      {:ok, component_state} = Table.init(props)
      context_with_props = Map.put(default_context(100), :attrs, props)
      elements = Table.render(component_state, context_with_props)

      # Header line (y=0)
      header_line = get_line_text(elements, 0)
      # Expect "Short" column to be width 5, "Looooong Header" to be width 15
      # Format: "Short   Looooong Header " (1 space separator)
      assert header_line == "Short Looooong Header "

      # Data line (y=1)
      data_line = get_line_text(elements, 1)
      # Expect "Data" padded to 5, "More Data" padded to 15
      assert data_line == "Data  More Data       "
    end

    test "respects fixed column widths" do
      props = %{
        headers: ["H1", "H2"],
        rows: [["D1", "D2"]],
        column_widths: [5, 10],
        border_style: :none,
        width: :auto
      }

      {:ok, component_state} = Table.init(props)
      context_with_props = Map.put(default_context(100), :attrs, props)
      elements = Table.render(component_state, context_with_props)

      header_line = get_line_text(elements, 0)
      assert header_line == "H1    H2          "

      data_line = get_line_text(elements, 1)
      assert data_line == "D1    D2          "
    end

    test "handles mixed fixed and auto widths" do
      props = %{
        headers: ["Fixed", "Auto", "Long Auto"],
        rows: [["Data1", "Data2", "Very Loooong Data"]],
        # 5, 5, 17 based on content
        column_widths: [5, :auto, :auto],
        border_style: :none,
        width: :auto
      }

      {:ok, component_state} = Table.init(props)
      context_with_props = Map.put(default_context(100), :attrs, props)
      elements = Table.render(component_state, context_with_props)

      header_line = get_line_text(elements, 0)
      assert header_line == "Fixed Auto  Long Auto         "

      data_line = get_line_text(elements, 1)
      assert data_line == "Data1 Data2 Very Loooong Data "
    end

    test "shrinks columns to fit narrow context width" do
      props = %{
        # Content width: 8, 8
        headers: ["Header A", "Header B"],
        # Content width: 6, 6
        rows: [["Data 1", "Data 2"]],
        column_widths: :auto,
        border_style: :single,
        width: :auto
      }

      {:ok, component_state} = Table.init(props)
      context_with_props_20 = Map.put(default_context(20), :attrs, props)
      elements = Table.render(component_state, context_with_props_20)
      header_line = get_line_text(elements, 1)
      # Exact fit
      assert header_line == "│Header A│Header B│"

      # Available content width = 15 - 3 = 12
      # Initial widths: 8, 8 (total 16) -> needs shrink by 4
      # Should shrink largest first (both 8) -> 7, 7 (total 14) -> needs shrink by 2 -> 6, 6 (total 12)
      context_with_props_15 = Map.put(default_context(15), :attrs, props)
      elements_narrow = Table.render(component_state, context_with_props_15)
      header_line_narrow = get_line_text(elements_narrow, 1)
      # Truncated to 6, 6
      assert header_line_narrow == "│Header│Header│"
      data_line_narrow = get_line_text(elements_narrow, 3)
      # Fit within 6, 6
      assert data_line_narrow == "│Data 1│Data 2│"
    end

    test "expands columns to fit wide context width" do
      props = %{
        # Content width 1, 1
        headers: ["A", "B"],
        rows: [["1", "2"]],
        column_widths: :auto,
        border_style: :single,
        width: :auto
      }

      {:ok, component_state} = Table.init(props)
      # Available content width = 15 - 3 = 12
      # Initial widths 1, 1 (total 2) -> needs expand by 10
      # Expands to 6, 6
      context_with_props = Map.put(default_context(15), :attrs, props)
      elements = Table.render(component_state, context_with_props)
      header_line = get_line_text(elements, 1)
      assert header_line == "│A     │B     │"
    end
  end

  describe "Cell Alignment" do
    test "defaults to left alignment" do
      props = %{
        headers: ["Header"],
        rows: [["Data"]],
        column_widths: [10],
        border_style: :none
      }
      {:ok, component_state} = Table.init(props)
      context_with_props = Map.put(default_context(20), :attrs, props)
      elements = Table.render(component_state, context_with_props)
      header_line = get_line_text(elements, 0)
      data_line = get_line_text(elements, 1)
      assert header_line == "Header     "
      assert data_line == "Data       "
    end

    test "applies right alignment" do
      props = %{
        headers: ["Header"],
        rows: [["Data"]],
        column_widths: [10],
        border_style: :none,
        alignments: :right
      }
      {:ok, component_state} = Table.init(props)
      context_with_props = Map.put(default_context(20), :attrs, props)
      elements = Table.render(component_state, context_with_props)
      header_line = get_line_text(elements, 0)
      data_line = get_line_text(elements, 1)
      assert header_line == "    Header"
      assert data_line == "      Data"
    end

    test "applies center alignment" do
      props = %{
        headers: ["Header"],
        rows: [["Data"]],
        column_widths: [10],
        border_style: :none,
        alignments: :center
      }
      {:ok, component_state} = Table.init(props)
      context_with_props = Map.put(default_context(20), :attrs, props)
      elements = Table.render(component_state, context_with_props)
      # "Header" len 6, pad 4 -> 2 left, 2 right
      header_line = get_line_text(elements, 0)
      # "Data" len 4, pad 6 -> 3 left, 3 right
      data_line = get_line_text(elements, 1)
      assert header_line == "  Header  "
      assert data_line == "   Data   "

      # Test odd padding
      props2 = %{
        headers: ["Head"],
        rows: [["Datum"]],
        column_widths: [9],
        alignments: :center,
        border_style: :none
      }

      component2 = Table.create(props2)
      elements2 = Table.render(component2, default_context())
      # "Head" len 4, pad 5 -> 2 left, 3 right
      header_line2 = get_line_text(elements2, 0)
      # "Datum" len 5, pad 4 -> 2 left, 2 right
      data_line2 = get_line_text(elements2, 1)
      assert header_line2 == "  Head   "
      assert data_line2 == "  Datum  "
    end

    test "applies mixed alignments per column" do
      props = %{
        headers: ["Left", "Center", "Right"],
        rows: [["L", "C", "R"]],
        column_widths: [10, 10, 10],
        border_style: :none,
        alignments: [:left, :center, :right]
      }
      {:ok, component_state} = Table.init(props)
      context_with_props = Map.put(default_context(40), :attrs, props)
      elements = Table.render(component_state, context_with_props)

      header_line = get_line_text(elements, 0)
      data_line = get_line_text(elements, 1)

      assert header_line == "Left        Center     Right"
      assert data_line == "L           C         R"
    end
  end

  describe "Styling Integration" do
    test "applies theme styles to header and data rows" do
      props = %{
        headers: ["Head"],
        rows: [["Data"]],
        column_widths: [10]
      }
      {:ok, component_state} = Table.init(props)
      context_with_props = Map.put(default_context(20), :attrs, props)
      elements = Table.render(component_state, context_with_props)

      # Find header cell element (y=1 because of top border)
      # Text includes padding
      header_cell = find_cell(elements, 1, "Head      ")
      refute is_nil(header_cell)
      assert header_cell.attrs == %{fg: :blue, bold: true}

      # Find data cell element (y=3 because of header separator)
      data_cell = find_cell(elements, 3, "Data      ")
      refute is_nil(data_cell)
      assert data_cell.attrs == %{fg: :white}
    end

    # Test theme override prop?
    # Test border styling?
  end
end
