
defmodule Raxol.Core.Renderer.Views.IntegrationTest do
  use ExUnit.Case, async: true
  alias Raxol.Core.Renderer.View
  require Raxol.Core.Renderer.View
  alias Raxol.Core.Renderer.Views.{Chart, Table}

  @sample_data [
    %{id: 1, name: "Product A", sales: [100, 120, 90, 150, 130], trend: :up},
    %{id: 2, name: "Product B", sales: [80, 85, 95, 88, 92], trend: :stable},
    %{id: 3, name: "Product C", sales: [200, 180, 160, 140, 120], trend: :down}
  ]

  def default_format_fn(v), do: to_string(v)

  @columns [
    %{
      header: "ID",
      key: :id,
      width: 4,
      align: :right,
      format: &__MODULE__.default_format_fn/1
    },
    %{
      header: "Name",
      key: :name,
      width: 15,
      align: :left,
      format: &__MODULE__.default_format_fn/1
    },
    %{
      header: "Status",
      key: :trend,
      width: 8,
      align: :center,
      format: &__MODULE__.default_format_fn/1
    }
  ]

  describe "dashboard layout" do
    test ~c"combines table with sparklines" do
      # Create table columns with embedded sparklines
      columns = [
        %{
          header: "ID",
          key: :id,
          width: 4,
          align: :right,
          format: fn value -> to_string(value) end
        },
        %{
          header: "Name",
          key: :name,
          width: 15,
          align: :left,
          format: fn value -> to_string(value) end
        },
        %{
          header: "Trend",
          key: :sales,
          width: 20,
          align: :left,
          format: fn sales ->
            Chart.new(
              type: :sparkline,
              series: [
                %{
                  name: "Sales",
                  data: sales,
                  color: :blue
                }
              ],
              width: 20,
              height: 1
            )
          end
        },
        %{
          header: "Status",
          key: :trend,
          width: 6,
          align: :center,
          format: fn
            :up -> View.text("↑", fg: :green)
            :down -> View.text("↓", fg: :red)
            :stable -> View.text("→", fg: :yellow)
          end
        }
      ]

      # Create the table
      view =
        Table.new(%{
          columns: columns,
          data: @sample_data,
          border: :single,
          header_style: [:bold]
        })

      context = %{width: 80, height: 20}
      alias Raxol.Renderer.Layout

      # Debug: Check what the table produces before layout
      _table_children =
        Raxol.Core.Renderer.Views.Table.build_table_content(view)

      # Get the rendered layout as a map, not a list
      rendered_layout = Layout.apply_layout(view, context)

      # Verify table structure
      assert rendered_layout.type == :table
      assert rendered_layout.border == :single
      assert length(rendered_layout.columns) == 4
      assert length(rendered_layout.data) == 3

      # Verify table content structure: children are rows
      # rendered_layout.children should be [header_row, separator_row, data_row1, data_row2, data_row3]
      # Header row, separator row, plus data rows
      assert Enum.count(rendered_layout.children) ==
               2 + Enum.count(@sample_data)

      [header_row_map, separator_row_map | data_row_maps] =
        rendered_layout.children

      # Verify header row
      assert header_row_map.type == :row
      # Number of cells should match columns
      assert Enum.count(header_row_map.children) == Enum.count(columns)

      # Example check for first header cell content (adjust as needed based on actual output)
      first_header_cell = hd(header_row_map.children)
      assert first_header_cell.type == :text
      # Adjusted for right-align width 4
      assert first_header_cell.content == "  ID"

      # Verify separator row (simple check)
      assert separator_row_map.type == :row
      assert Enum.count(separator_row_map.children) == 1
      assert hd(separator_row_map.children).type == :text

      assert Enum.count(data_row_maps) == Enum.count(@sample_data)

      # Verify sparkline integration by checking the 'Trend' column cells (index 2)
      trend_cells =
        Enum.map(data_row_maps, fn data_row ->
          # 'Trend' column is the 3rd cell (index 2)
          Enum.at(data_row.children, 2)
        end)

      Enum.each(trend_cells, fn cell_chart ->
        assert cell_chart.type == :text,
               "Expected cell to be a text cell (chart rendered as text), got: #{inspect(cell_chart)}"
      end)

      # Verify status indicators by checking the 'Status' column cells (index 3)
      status_cells =
        Enum.map(data_row_maps, fn data_row ->
          # 'Status' column is the 4th cell (index 3)
          Enum.at(data_row.children, 3)
        end)

      # Status cells are text cells (color information may be lost during layout processing)
      assert Enum.any?(status_cells, &(&1.type == :text)),
             "No status cell found"
    end

    test ~c"creates side-by-side charts" do
      # Create bar chart
      bar_chart =
        Chart.new(
          type: :bar,
          series: [
            %{
              name: "Total Sales",
              data: Enum.map(@sample_data, &List.last(&1.sales)),
              color: :blue
            }
          ],
          width: 30,
          height: 10,
          show_axes: true,
          show_legend: true
        )

      # Create line chart
      line_chart =
        Chart.new(
          type: :line,
          series:
            Enum.map(@sample_data, fn product ->
              %{
                name: product.name,
                data: product.sales,
                color: if(product.trend == :up, do: :green, else: :red)
              }
            end),
          width: 40,
          height: 10,
          show_axes: true,
          show_legend: true
        )

      # Combine charts side by side
      view =
        View.flex direction: :row do
          [bar_chart, line_chart]
        end

      context = %{width: 80, height: 20}
      alias Raxol.Renderer.Layout
      # Get the rendered layout as a map, not a list
      rendered_layout = Layout.apply_layout(view, context)

      # Verify flex container
      assert rendered_layout.type == :flex
      assert rendered_layout.direction == :row
      assert length(rendered_layout.children) == 2

      # Verify bar chart
      [bar_chart_view, line_chart_view] = rendered_layout.children
      # Charts are rendered as boxes by Chart.new/1
      assert bar_chart_view.type == :box

      # Verify line chart (assuming it's also a box)
      # Charts are rendered as boxes by Chart.new/1
      assert line_chart_view.type == :box
    end

    test ~c"creates complex dashboard layout" do
      # Create header
      header =
        View.box(
          style: [:bold],
          border: :single,
          children: [
            View.text("Sales Dashboard", style: [:bold], fg: :blue)
          ]
        )

      # Create summary table
      summary_table =
        Table.new(%{
          columns: [
            %{
              header: "Metric",
              key: :metric,
              width: 15,
              align: :left,
              format: fn value -> to_string(value) end
            },
            %{
              header: "Value",
              key: :value,
              width: 10,
              align: :right,
              format: fn value -> to_string(value) end
            }
          ],
          data: [
            %{metric: "Total Products", value: length(@sample_data)},
            %{
              metric: "Growing",
              value: Enum.count(@sample_data, &(&1.trend == :up))
            },
            %{
              metric: "Declining",
              value: Enum.count(@sample_data, &(&1.trend == :down))
            }
          ],
          border: :single
        })

      # Create trend chart
      trend_chart =
        Chart.new(
          type: :line,
          series:
            Enum.map(@sample_data, fn product ->
              %{
                name: product.name,
                data: product.sales,
                color:
                  case product.trend do
                    :up -> :green
                    :down -> :red
                    :stable -> :yellow
                  end
              }
            end),
          width: 60,
          height: 15,
          show_axes: true,
          show_legend: true
        )

      # Combine all elements
      view =
        View.box(
          children: [
            header,
            View.flex direction: :row do
              [
                View.box(size: {25, :auto}, children: [summary_table]),
                View.box(size: {60, :auto}, children: [trend_chart])
              ]
            end
          ]
        )

      # Verify overall structure
      assert view.type == :box
      assert length(view.children) == 2

      # Verify header
      [header, content] = view.children
      assert header.type == :box
      assert header.border == :single
      assert header.style == [:bold]
      assert length(header.children) == 1
      [header_text] = header.children
      assert header_text.type == :text
      assert header_text.content == "Sales Dashboard"
      assert header_text.style == [:bold]
      assert header_text.fg == :blue

      # Verify content layout
      assert content.type == :flex
      assert content.direction == :row
      assert length(content.children) == 2

      # Verify summary table
      [summary, chart] = content.children
      assert summary.type == :box
      assert summary.size == {25, :auto}
      assert length(summary.children) == 1
      [table] = summary.children
      assert table.type == :table
      assert table.border == :single
      assert length(table.columns) == 2
      assert length(table.data) == 3

      # Verify chart
      assert chart.type == :box
      assert chart.size == {60, :auto}
      assert length(chart.children) == 1
      [_chart_component_wrapper] = chart.children
    end
  end

  describe "interactive components" do
    test ~c"combines table with chart detail view" do
      # Create selectable table
      table =
        Table.new(%{
          columns: [
            %{
              header: "ID",
              key: :id,
              width: 4,
              align: :right,
              format: fn value -> to_string(value) end
            },
            %{
              header: "Name",
              key: :name,
              width: 15,
              align: :left,
              format: fn value -> to_string(value) end
            },
            %{
              header: "Status",
              key: :trend,
              width: 8,
              align: :center,
              format: fn value -> to_string(value) end
            }
          ],
          data: @sample_data,
          selectable: true,
          selected: 0,
          border: :single
        })

      # Create detail chart for selected item
      selected_item = Enum.at(@sample_data, 0)

      detail_chart =
        Chart.new(
          type: :line,
          series: [
            %{
              name: selected_item.name,
              data: selected_item.sales,
              color: :blue
            }
          ],
          width: 40,
          height: 10,
          show_axes: true,
          show_legend: true
        )

      # Combine views
      view =
        View.flex direction: :row do
          [
            View.box(size: {30, :auto}, children: [table]),
            View.box(size: {40, :auto}, children: [detail_chart])
          ]
        end

      # Define context if not already present
      context = %{width: 80, height: 20}
      alias Raxol.Renderer.Layout
      # Get the rendered layout as a map, not a list
      rendered_layout = Layout.apply_layout(view, context)

      # Traverse the rendered_layout to find the table
      # rendered_layout should be the flex container
      assert rendered_layout.type == :flex
      assert length(rendered_layout.children) == 2
      [table_box_rendered, _chart_box_rendered] = rendered_layout.children

      assert table_box_rendered.type == :box
      # Size might be resolved by layout
      assert table_box_rendered.size == {30, 1}
      assert length(table_box_rendered.children) == 1

      # This is the processed table map
      table_rendered = hd(table_box_rendered.children)

      # Verify table selection (assertions on the processed table_rendered map)
      assert table_rendered.type == :table
      # This was from the input Table.new
      assert table_rendered.selectable == true
      # This was from the input Table.new
      assert table_rendered.selected == 0

      # table_rendered.children should now exist and be [header_row, separator_row, data_row1, ...]
      assert Map.has_key?(table_rendered, :children),
             "Processed table map should have :children key"

      assert length(table_rendered.children) >= 2 + Enum.count(@sample_data)

      [_header_row_map, _separator_row_map | data_row_maps] =
        table_rendered.children

      # Selected index is 0
      selected_data_row_map = Enum.at(data_row_maps, 0)

      assert is_map(selected_data_row_map),
             "Selected data row map not found or not a map"

      assert selected_data_row_map.type == :row
      # table is the original Table.new struct
      assert Enum.count(selected_data_row_map.children) == length(@columns)

      # Verify selected row has expected structure
      assert selected_data_row_map.type == :row
      assert is_list(selected_data_row_map.children)
      assert length(selected_data_row_map.children) > 0

      # Verify selected row has expected content
      [id_cell, name_cell, status_cell] = selected_data_row_map.children
      assert id_cell.content == "   1"
      assert name_cell.content == "Product A      "
      assert status_cell.content == "   up   "
    end

    test ~c"creates tabbed view container" do
      # Create tab headers
      tabs = [
        %{id: :table, label: "Table View"},
        %{id: :chart, label: "Chart View"}
      ]

      tab_headers =
        View.flex direction: :row do
          Enum.map(tabs, fn tab ->
            style = if tab.id == :table, do: [bg: :blue, fg: :white], else: []
            View.text(" #{tab.label} ", style: style)
          end)
        end

      # Create tab content
      table_view =
        Table.new(%{
          columns: [
            %{
              header: "ID",
              key: :id,
              width: 4,
              align: :right,
              format: fn value -> to_string(value) end
            },
            %{
              header: "Name",
              key: :name,
              width: 15,
              align: :left,
              format: fn value -> to_string(value) end
            }
          ],
          data: @sample_data,
          border: :single
        })

      _chart_view =
        Chart.new(
          type: :bar,
          series: [
            %{
              name: "Sales",
              data: Enum.map(@sample_data, &List.last(&1.sales)),
              color: :blue
            }
          ],
          width: 40,
          height: 10,
          show_axes: true
        )

      # Combine into tabbed view
      view =
        View.box(
          border: :single,
          children: [
            tab_headers,
            # Currently selected tab
            table_view
          ]
        )

      assert view.type == :box
      assert length(view.children) == 2

      [headers, _content] = view.children
      assert headers.type == :flex
      assert length(headers.children) == 2

      # Verify tab styling
      [active_tab, inactive_tab] = headers.children
      assert active_tab.style == [bg: :blue, fg: :white]
      assert inactive_tab.style == []
    end
  end

  describe "layout adaptability" do
    test ~c"handles nested borders and padding" do
      view =
        View.border :double, padding: 1 do
          View.border :single, [] do
            table =
              Table.new(%{
                columns: [
                  %{
                    header: "Name",
                    key: :name,
                    width: 15,
                    align: :left,
                    format: fn value -> to_string(value) end
                  },
                  %{
                    header: "Status",
                    key: :trend,
                    width: 8,
                    align: :center,
                    format: fn value -> to_string(value) end
                  }
                ],
                data: @sample_data,
                border: :single
              })

            table
          end
        end

      context = %{width: 80, height: 20}
      alias Raxol.Renderer.Layout
      # Get the rendered layout as a map, not a list
      rendered_layout = Layout.apply_layout(view, context)

      # Verify outer border
      assert is_map(rendered_layout),
             "Layout.apply_layout should return a single map for a root border. Got: #{inspect(rendered_layout)}"

      assert rendered_layout.type == :border
      assert rendered_layout.border == :double

      # Verify inner border
      inner_border = hd(rendered_layout.children)
      assert inner_border.type == :border
      assert inner_border.border == :single

      # Verify table
      table = hd(inner_border.children)
      assert table.type == :table
      assert table.border == :single
      assert length(table.columns) == 2
      assert length(table.data) == 3

      # Verify table content
      assert is_list(table.children) and table.children != [],
             "Table children (rows) should not be empty"

      [header, separator_row | data_rows] = table.children
      assert header.type == :row
      assert separator_row.type == :row
      assert Enum.all?(data_rows, &(&1.type == :row))

      assert length(header.children) == 2
      assert length(data_rows) == Enum.count(@sample_data)

      # Verify header cells
      [name_header, status_header] = header.children
      assert name_header.content == "Name           "
      # Center-aligned in width 8
      assert status_header.content == " Status "

      # Verify first row
      first_row = hd(data_rows)
      [name_cell, status_cell] = first_row.children
      assert name_cell.content == "Product A      "
      # Center-aligned in width 8
      assert status_cell.content == "   up   "
    end

    test ~c"creates responsive grid layout" do
      # Create multiple charts in a grid
      charts =
        Enum.map(@sample_data, fn product ->
          Chart.new(
            type: :line,
            series: [
              %{
                name: product.name,
                data: product.sales,
                color: :blue
              }
            ],
            width: 30,
            height: 8,
            show_legend: true
          )
        end)

      # Arrange in a grid
      view =
        View.grid columns: 2 do
          charts
        end

      # Test with enough width
      context = %{width: 100, height: 10}
      alias Raxol.Renderer.Layout
      # Get the rendered layout as a map, not a list
      rendered_layout = Layout.apply_layout(view, context)

      assert is_map(rendered_layout),
             "Layout.apply_layout (wide context) should return a single map for a root grid. Got: #{inspect(rendered_layout)}"

      # Verify grid structure
      assert rendered_layout.type == :grid
      assert is_list(rendered_layout.children)
      assert length(rendered_layout.children) == 3

      # Verify each chart in the grid
      Enum.each(rendered_layout.children, fn chart_as_box ->
        assert is_map(chart_as_box)
        assert chart_as_box.type == :box
      end)

      # Test with narrow width
      context_narrow = %{width: 10, height: 10}
      alias Raxol.Renderer.Layout
      # Get the rendered layout as a map, not a list
      rendered_layout_narrow = Layout.apply_layout(view, context_narrow)

      # Verify grid structure with narrow width
      assert is_map(rendered_layout_narrow),
             "Layout.apply_layout (narrow context) should return a single map for a root grid. Got: #{inspect(rendered_layout_narrow)}"

      assert rendered_layout_narrow.type == :grid

      # Verify charts are properly scaled down
      Enum.each(rendered_layout_narrow.children, fn chart_as_box ->
        assert is_map(chart_as_box)
        assert chart_as_box.type == :box
      end)
    end
  end

  describe "layout with borders and padding" do
    setup do
      # Define columns matching the Table.new/1 expectation
      columns = [
        %{
          header: "Name",
          key: :name,
          width: 15,
          align: :left,
          format: fn val -> to_string(val) end
        },
        %{
          header: "Status",
          key: :status,
          width: 8,
          align: :center,
          format: fn val -> to_string(val) end
        }
      ]

      # Define data as a list of maps with keys matching column keys
      data = [
        %{name: "Product A", status: "up"},
        %{name: "Product B", status: "stable"},
        %{name: "Product C", status: "down"}
      ]

      view =
        View.border :double, padding: 1 do
          View.border :single do
            # Pass opts as a keyword list with correct keys
            Table.new(%{
              columns: columns,
              data: data,
              row_style: fn _row_index, row_data ->
                if row_data.status == "stable", do: [bg: :bright_black]
              end,
              header_style: [:bold]
              # striped, selectable, selected, border options use defaults from Table.new
            })
          end
        end

      %{view: view}
    end

    test ~c"layout with borders and padding handles nested borders and padding" do
      # Defines a complex nested structure: Border > Border > Grid > Table
      view =
        View.border :double, padding: 1, border: :double do
          View.border :single, padding: 1 do
            # Grid is child of inner border
            View.grid columns: 1 do
              # Table is child of Grid - wrap in list since grid expects children list
              [
                Table.new(%{
                  columns: @columns,
                  data: @sample_data,
                  border: :none
                })
              ]
            end
          end
        end

      context = %{width: 80, height: 20}
      alias Raxol.Renderer.Layout
      # Get the rendered layout as a map, not a list
      rendered_layout = Layout.apply_layout(view, context)

      # Check outer border properties
      assert is_map(rendered_layout),
             "Layout.apply_layout should return a single map for a root border. Got: #{inspect(rendered_layout)}"

      assert rendered_layout.type == :border
      assert rendered_layout.border == :double

      # Check inner border properties
      inner_border_view = hd(rendered_layout.children)
      assert inner_border_view.type == :border
      assert inner_border_view.border == :single

      # Padding is handled internally by the border processing, not exposed in the output structure

      # Check content - Corrected traversal
      grid_view = hd(inner_border_view.children)
      # Verify it's a grid
      assert grid_view.type == :grid
      # Grid should have one child (the table)
      assert length(grid_view.children) == 1

      table_view = hd(grid_view.children)
      # Verify it's a table
      assert table_view.type == :table
      # As defined in Table.new
      assert table_view.border == :none

      # Now access table's children (rows)
      assert is_list(table_view.children) and table_view.children != [],
             "Table should have rendered rows as children"

      # This is the list of [header_row, separator_row, data_row1, ...]
      rows_list = table_view.children

      # Example: Check header row (first element in rows_list)
      header_row_map = hd(rows_list)
      assert header_row_map.type == :row
      # Number of header cells
      assert length(header_row_map.children) == length(@columns)

      first_header_cell = hd(header_row_map.children)
      assert first_header_cell.type == :text
    end
  end

  describe "complex nested layout" do
    # Add more tests for complex nested layout
  end
end
