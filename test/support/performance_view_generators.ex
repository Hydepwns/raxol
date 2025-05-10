defmodule Raxol.Test.PerformanceViewGenerators do
  @moduledoc """
  Provides helper functions for generating complex view structures for performance tests.
  """

  alias Raxol.Core.Renderer.Views.{Table, Chart}
  alias Raxol.Core.Renderer.View
  alias Raxol.Test.PerformanceTestData

  def create_nested_structure(depth, current_depth \\ 0)
  def create_nested_structure(depth, depth), do: View.text("Leaf")

  def create_nested_structure(depth, current_depth) do
    children =
      for _ <- 1..3 do
        create_nested_structure(depth, current_depth + 1)
      end

    if rem(current_depth, 2) == 0 do
      View.flex [direction: :row], do: children
    else
      View.grid [columns: 3], do: children
    end
  end

  def count_nested_views(view) do
    1 +
      (Map.get(view, :children, [])
       |> Enum.map(&count_nested_views/1)
       |> Enum.sum())
  end

  def create_configurable_test_layout(opts \\ []) do
    table_rows = Keyword.get(opts, :table_rows, 100)
    table_data_source = Keyword.get(opts, :table_data_source, PerformanceTestData.large_data())
    actual_table_data = Enum.take(table_data_source, table_rows)

    num_charts = Keyword.get(opts, :num_charts, 4)
    chart_grid_columns = Keyword.get(opts, :chart_grid_columns, round(:math.sqrt(num_charts)))
    chart_data_points = Keyword.get(opts, :chart_data_points, 20)
    chart_width = Keyword.get(opts, :chart_width, 30)
    chart_height = Keyword.get(opts, :chart_height, 10)
    show_chart_axes = Keyword.get(opts, :show_chart_axes, true)

    default_table_columns = [
      %{header: "ID", key: :id, width: 6, align: :right},
      %{header: "Name", key: :name, width: 20, align: :left}
    ]
    table_columns_spec = Keyword.get(opts, :table_columns, default_table_columns)

    processed_table_columns = Enum.map(table_columns_spec, fn
      %{format: :sparkline} = col_spec ->
        key_for_sparkline = Map.get(col_spec, :key, :sales)
        sparkline_width = Map.get(col_spec, :width, 12)

        Map.merge(col_spec, %{
          key: key_for_sparkline,
          width: sparkline_width,
          format: fn sales_data ->
            Chart.new(
              type: :sparkline,
              series: [%{name: "Sales", data: sales_data, color: :blue}],
              width: sparkline_width
            )
          end
        })
      col_spec ->
        Map.put_if_absent(col_spec, :format, fn data_for_cell -> to_string(data_for_cell) end)
    end)

    table_view = Table.new(
      columns: processed_table_columns,
      data: actual_table_data,
      border: :single,
      striped: Keyword.get(opts, :table_striped, true)
    )

    charts_view_children =
      for i <- 1..num_charts do
        Chart.new(
          type: Enum.random([:bar, :line, :sparkline]),
          series: [
            %{
              name: "Series \#{i}",
              data: Enum.take_random(table_data_source, chart_data_points)
                    |> Enum.map(&Map.get(&1, :sales, []))
                    |> Enum.map(&List.first(&1))
                    |> Enum.reject(&is_nil/1),
              color: :blue
            }
          ],
          width: chart_width,
          height: chart_height,
          show_axes: show_chart_axes
        )
      end

    charts_panel = View.grid columns: chart_grid_columns, do: charts_view_children

    flex_children = [
      View.box(size: {Keyword.get(opts, :table_panel_width, :auto), :auto}, children: [table_view]),
      charts_panel
    ]

    main_content = View.flex direction: :row, do: flex_children

    if Keyword.get(opts, :include_top_header, false) do
      View.box(children: [
        View.box(border: :single, children: [View.text("Header", style: [:bold])]),
        main_content
      ])
    else
      View.box(children: [main_content])
    end
  end

  def create_simple_table(rows, columns) do
    Table.new(
      columns: PerformanceTestData.generate_columns(columns),
      data: PerformanceTestData.generate_data(rows, columns),
      border: :single
    )
  end

  def update_some_data(data, index) do
    Enum.map(data, fn item ->
      if item.id == index do
        %{
          item
          | sales: Enum.map(item.sales, fn _ -> :rand.uniform(1000) end)
        }
      else
        item
      end
    end)
  end

  def create_progress_bar_frames(count) do
    for i <- 0..count do
      View.box(
        border: :single,
        size: {50, 3},
        children: [
          View.box(
            size: {i, 1},
            style: [bg: :blue],
            children: [View.text(String.duplicate(" ", i))]
          ),
          View.text("\#{i}%", position: {22, 1})
        ]
      )
    end
  end

  def create_spinner_frames(count) do
    spinner_chars = ~w(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
    # Use count to determine how many frames, though spinner_chars is fixed length
    # This example will cycle through spinner_chars `count` times if count > length(spinner_chars)
    # or take a subset if count < length(spinner_chars)
    # For simplicity, let's just create one frame for each char, ignoring count for now if not needed for variation
    for {char, _idx} <- Enum.take(Stream.cycle(spinner_chars), count) |> Enum.with_index() do
      View.box(
        children: [
          View.text(char, fg: :blue),
          View.text(" Loading...", position: {2, 0})
        ]
      )
    end
  end

  def create_chart_animation_frames(count) do
    data_points = 30
    for frame <- 1..count do
      data =
        for i <- 0..data_points do
          :math.sin(i * 0.2 + frame * 0.1) * 100
        end

      Chart.new(
        type: :line,
        series: [
          %{
            name: "Wave",
            data: data,
            color: :blue
          }
        ],
        width: 60,
        height: 20,
        show_axes: true,
        min: -100,
        max: 100
      )
    end
  end
end
