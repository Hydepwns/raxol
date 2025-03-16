defmodule Raxol.Core.Renderer.Views.IntegrationTest do
  use ExUnit.Case, async: true
  alias Raxol.Core.Renderer.Views.{Table, Chart}
  alias Raxol.Core.Renderer.View

  @sample_data [
    %{id: 1, name: "Product A", sales: [100, 120, 90, 150, 130], trend: :up},
    %{id: 2, name: "Product B", sales: [80, 85, 95, 88, 92], trend: :stable},
    %{id: 3, name: "Product C", sales: [200, 180, 160, 140, 120], trend: :down}
  ]

  describe "dashboard layout" do
    test "combines table with sparklines" do
      # Create table columns with embedded sparklines
      columns = [
        %{header: "ID", key: :id, width: 4, align: :right},
        %{header: "Name", key: :name, width: 15, align: :left},
        %{
          header: "Trend",
          key: :sales,
          width: 20,
          align: :left,
          format: fn sales ->
            Chart.new(
              type: :sparkline,
              series: [%{
                name: "Sales",
                data: sales,
                color: :blue
              }],
              width: 20
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
      view = Table.new(
        columns: columns,
        data: @sample_data,
        border: :single,
        header_style: [:bold]
      )

      assert view.type == :border
      [header | rows] = get_in(view, [:children, Access.at(0)])
      
      # Verify structure
      assert length(rows) == 3
      assert length(header.children) == 4

      # Verify sparkline integration
      trend_cells = Enum.map(rows, fn row ->
        Enum.at(row.children, 2)
      end)
      assert Enum.all?(trend_cells, & &1.type == :box)

      # Verify status indicators
      status_cells = Enum.map(rows, fn row ->
        Enum.at(row.children, 3)
      end)
      assert Enum.any?(status_cells, & &1.fg == :green)
      assert Enum.any?(status_cells, & &1.red == :red)
    end

    test "creates side-by-side charts" do
      # Create bar chart
      bar_chart = Chart.new(
        type: :bar,
        series: [%{
          name: "Total Sales",
          data: Enum.map(@sample_data, & List.last(&1.sales)),
          color: :blue
        }],
        width: 30,
        height: 10,
        show_axes: true,
        show_legend: true
      )

      # Create line chart
      line_chart = Chart.new(
        type: :line,
        series: Enum.map(@sample_data, fn product ->
          %{
            name: product.name,
            data: product.sales,
            color: if product.trend == :up, do: :green, else: :red
          }
        end),
        width: 40,
        height: 10,
        show_axes: true,
        show_legend: true
      )

      # Combine charts side by side
      view = View.flex(
        direction: :row,
        children: [bar_chart, line_chart]
      )

      assert view.type == :flex
      assert length(view.children) == 2
      assert Enum.at(view.children, 0).type == :box  # Bar chart
      assert Enum.at(view.children, 1).type == :box  # Line chart
    end

    test "creates complex dashboard layout" do
      # Create header
      header = View.box(
        style: [:bold],
        border: :single,
        children: [
          View.text("Sales Dashboard", style: [:bold], fg: :blue)
        ]
      )

      # Create summary table
      summary_table = Table.new(
        columns: [
          %{header: "Metric", key: :metric, width: 15, align: :left},
          %{header: "Value", key: :value, width: 10, align: :right}
        ],
        data: [
          %{metric: "Total Products", value: length(@sample_data)},
          %{metric: "Growing", value: Enum.count(@sample_data, & &1.trend == :up)},
          %{metric: "Declining", value: Enum.count(@sample_data, & &1.trend == :down)}
        ],
        border: :single
      )

      # Create trend chart
      trend_chart = Chart.new(
        type: :line,
        series: Enum.map(@sample_data, fn product ->
          %{
            name: product.name,
            data: product.sales,
            color: case product.trend do
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
      view = View.box(
        children: [
          header,
          View.flex(
            direction: :row,
            children: [
              View.box(size: {25, :auto}, children: [summary_table]),
              View.box(size: {60, :auto}, children: [trend_chart])
            ]
          )
        ]
      )

      assert view.type == :box
      assert length(view.children) == 2  # Header and content flex
      
      [header, content] = view.children
      assert header.border == :single
      assert content.type == :flex
      assert length(content.children) == 2  # Summary and chart
      
      # Verify layout structure
      [summary, chart] = content.children
      assert summary.size == {25, :auto}
      assert chart.size == {60, :auto}
    end
  end

  describe "interactive components" do
    test "combines table with chart detail view" do
      # Create selectable table
      table = Table.new(
        columns: [
          %{header: "ID", key: :id, width: 4, align: :right},
          %{header: "Name", key: :name, width: 15, align: :left},
          %{header: "Status", key: :trend, width: 8, align: :center}
        ],
        data: @sample_data,
        selectable: true,
        selected: 0,
        border: :single
      )

      # Create detail chart for selected item
      selected_item = Enum.at(@sample_data, 0)
      detail_chart = Chart.new(
        type: :line,
        series: [%{
          name: selected_item.name,
          data: selected_item.sales,
          color: :blue
        }],
        width: 40,
        height: 10,
        show_axes: true,
        show_legend: true
      )

      # Combine views
      view = View.flex(
        direction: :row,
        children: [
          View.box(size: {30, :auto}, children: [table]),
          View.box(size: {40, :auto}, children: [detail_chart])
        ]
      )

      assert view.type == :flex
      assert length(view.children) == 2
      
      [table_box, chart_box] = view.children
      assert table_box.size == {30, :auto}
      assert chart_box.size == {40, :auto}
      
      # Verify table selection
      table_view = List.first(table_box.children)
      [_header | rows] = get_in(table_view, [:children, Access.at(0)])
      selected_row = Enum.at(rows, 0)
      assert selected_row.style == [bg: :blue, fg: :white]
    end

    test "creates tabbed view container" do
      # Create tab headers
      tabs = [
        %{id: :table, label: "Table View"},
        %{id: :chart, label: "Chart View"}
      ]
      
      tab_headers = View.flex(
        direction: :row,
        children: Enum.map(tabs, fn tab ->
          style = if tab.id == :table, do: [bg: :blue, fg: :white], else: []
          View.text(" #{tab.label} ", style: style)
        end)
      )

      # Create tab content
      table_view = Table.new(
        columns: [
          %{header: "ID", key: :id, width: 4, align: :right},
          %{header: "Name", key: :name, width: 15, align: :left}
        ],
        data: @sample_data,
        border: :single
      )

      chart_view = Chart.new(
        type: :bar,
        series: [%{
          name: "Sales",
          data: Enum.map(@sample_data, & List.last(&1.sales)),
          color: :blue
        }],
        width: 40,
        height: 10,
        show_axes: true
      )

      # Combine into tabbed view
      view = View.box(
        border: :single,
        children: [
          tab_headers,
          table_view  # Currently selected tab
        ]
      )

      assert view.type == :box
      assert length(view.children) == 2
      
      [headers, content] = view.children
      assert headers.type == :flex
      assert length(headers.children) == 2
      
      # Verify tab styling
      [active_tab, inactive_tab] = headers.children
      assert active_tab.style == [bg: :blue, fg: :white]
      assert inactive_tab.style == []
    end
  end

  describe "layout adaptability" do
    test "handles nested borders and padding" do
      view = View.border(
        border: :double,
        padding: 1,
        children: [
          View.border(
            border: :single,
            children: [
              Table.new(
                columns: [
                  %{header: "Name", key: :name, width: 15, align: :left},
                  %{header: "Status", key: :trend, width: 8, align: :center}
                ],
                data: @sample_data
              )
            ]
          )
        ]
      )

      assert view.border == :double
      assert view.padding == {1, 1, 1, 1}
      
      inner_border = List.first(view.children)
      assert inner_border.border == :single
      
      table = List.first(inner_border.children)
      assert table.type == :border
    end

    test "creates responsive grid layout" do
      # Create multiple charts in a grid
      charts = Enum.map(@sample_data, fn product ->
        Chart.new(
          type: :line,
          series: [%{
            name: product.name,
            data: product.sales,
            color: :blue
          }],
          width: 30,
          height: 8,
          show_legend: true
        )
      end)

      # Arrange in a grid
      view = View.grid(
        columns: 2,
        children: charts
      )

      assert view.type == :grid
      assert length(view.children) == 3  # Three charts
      
      # Verify chart sizes
      Enum.each(view.children, fn chart ->
        assert chart.width == 30
        assert chart.height == 8
      end)
    end
  end
end 