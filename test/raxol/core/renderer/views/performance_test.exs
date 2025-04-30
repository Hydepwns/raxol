defmodule Raxol.Core.Renderer.Views.PerformanceTest do
  use ExUnit.Case, async: true
  alias Raxol.Core.Renderer.Views.{Table, Chart}
  alias Raxol.Core.Renderer.{View, Manager}

  # Allow longer timeout for performance tests
  @moduletag timeout: 120_000

  # Generate large sample data
  @large_data Enum.map(1..1000, fn i ->
                %{
                  id: i,
                  name: "Product #{i}",
                  sales: Enum.map(1..12, fn _ -> :rand.uniform(1000) end),
                  trend: Enum.random([:up, :down, :stable])
                }
              end)

  # Helper to measure execution time
  defp measure(fun) do
    {time, result} = :timer.tc(fun)
    # Convert to seconds
    {result, time / 1_000_000}
  end

  describe "large table performance" do
    test "renders large table efficiently" do
      columns = [
        %{header: "ID", key: :id, width: 6, align: :right},
        %{header: "Name", key: :name, width: 20, align: :left},
        %{
          header: "Trend",
          key: :sales,
          width: 24,
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
              width: 24
            )
          end
        }
      ]

      {view, time} =
        measure(fn ->
          Table.new(
            columns: columns,
            data: @large_data,
            border: :single,
            striped: true
          )
        end)

      # Table creation should be fast
      # Should take less than 100ms
      assert time < 0.1
      # Header + 1000 rows
      assert length(get_in(view, [:children, Access.at(0)])) == 1001
    end

    test "handles dynamic updates efficiently" do
      {:ok, manager} = Manager.start_link([])

      # Create initial view
      view =
        Table.new(
          columns: [
            %{header: "ID", key: :id, width: 6, align: :right},
            %{header: "Name", key: :name, width: 20, align: :left}
          ],
          data: @large_data,
          border: :single
        )

      # Measure initial render
      {_, initial_time} =
        measure(fn ->
          Manager.set_root_view(manager, view)
          Manager.render_frame(manager)
        end)

      # Update every row's style
      updated_view =
        update_in(
          view,
          [:children, Access.at(0)],
          fn [header | rows] ->
            [header | Enum.map(rows, &put_in(&1.style, [:bold]))]
          end
        )

      # Measure update render
      {_, update_time} =
        measure(fn ->
          Manager.set_root_view(manager, updated_view)
          Manager.render_frame(manager)
        end)

      # Updates should be efficient due to damage tracking
      assert update_time < initial_time * 1.5
    end
  end

  describe "complex layout performance" do
    test "handles deeply nested views efficiently" do
      # Create a deeply nested structure with alternating flex/grid containers
      {view, time} =
        measure(fn ->
          # 10 levels deep
          create_nested_structure(10)
        end)

      # Deep nesting should still be relatively fast
      # Should take less than 100ms
      assert time < 0.1
      # Verify we have many nested views
      assert count_nested_views(view) > 100
    end

    test "manages multiple charts efficiently" do
      # Create a grid of charts
      # 4x4 grid
      charts =
        for i <- 1..16 do
          Chart.new(
            type: if(rem(i, 2) == 0, do: :bar, else: :line),
            series: [
              %{
                name: "Series #{i}",
                data:
                  Enum.take_random(@large_data, 50)
                  |> Enum.map(&List.first(&1.sales)),
                color: :blue
              }
            ],
            width: 30,
            height: 10,
            show_axes: true,
            show_legend: true
          )
        end

      {view, time} =
        measure(fn ->
          View.grid(
            columns: 4,
            children: charts
          )
        end)

      # Grid of charts should render reasonably quickly
      # Should take less than 200ms
      assert time < 0.2
      assert length(view.children) == 16
    end

    test "handles dynamic resizing efficiently" do
      {:ok, manager} = Manager.start_link([])

      # Create a complex layout
      view = create_complex_layout()
      Manager.set_root_view(manager, view)

      # Measure initial render
      {_, initial_time} =
        measure(fn ->
          Manager.render_frame(manager)
        end)

      # Measure resize operation
      {_, resize_time} =
        measure(fn ->
          # Double the typical size
          Manager.resize(manager, 120, 40)
          Manager.render_frame(manager)
        end)

      # Resizing should be efficient
      assert resize_time < initial_time * 2
    end

    test "maintains performance with z-index sorting" do
      # Create overlapping views with various z-indices
      views =
        for i <- 1..100 do
          View.box(
            position: {rem(i, 10), rem(i, 5)},
            z_index: rem(i, 10),
            size: {10, 5},
            children: [
              View.text("Layer #{i}")
            ]
          )
        end

      {view, time} =
        measure(fn ->
          View.box(children: views)
        end)

      # Z-index sorting should be efficient
      # Should take less than 100ms
      assert time < 0.1
      assert length(view.children) == 100
    end
  end

  describe "memory usage" do
    test "maintains reasonable memory usage with large layouts" do
      before = :erlang.memory(:total)

      # Create a large complex layout
      _view = create_large_complex_layout()

      after_creation = :erlang.memory(:total)
      memory_increase = after_creation - before

      # Memory increase should be reasonable
      # Less than 10MB increase
      assert memory_increase < 10_000_000
    end
  end

  describe "animation performance" do
    test "handles smooth progress bar animation" do
      {:ok, manager} = Manager.start_link([])

      # Create animated progress bar
      frames =
        for i <- 0..100 do
          View.box(
            border: :single,
            size: {50, 3},
            children: [
              View.box(
                size: {i, 1},
                style: [bg: :blue],
                children: [View.text(String.duplicate(" ", i))]
              ),
              View.text("#{i}%", position: {22, 1})
            ]
          )
        end

      # Measure frame rendering times
      frame_times =
        for frame <- frames do
          {_, time} =
            measure(fn ->
              Manager.set_root_view(manager, frame)
              Manager.render_frame(manager)
              # Target 60 FPS
              Process.sleep(16)
            end)

          time
        end

      avg_frame_time = Enum.sum(frame_times) / length(frame_times)
      max_frame_time = Enum.max(frame_times)

      # Ensure smooth animation
      # Average frame time under 16ms (60 FPS)
      assert avg_frame_time < 0.016
      # No frame takes longer than 32ms
      assert max_frame_time < 0.032
    end

    test "handles spinner animation efficiently" do
      {:ok, manager} = Manager.start_link([])
      spinner_chars = ~w(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)

      # Create spinner frames
      frames =
        for {char, _i} <- Enum.with_index(spinner_chars) do
          View.box(
            children: [
              View.text(char, fg: :blue),
              View.text(" Loading...", position: {2, 0})
            ]
          )
        end

      # Measure multiple animation cycles
      cycles = 5

      frame_times =
        for _ <- 1..cycles, frame <- frames do
          {_, time} =
            measure(fn ->
              Manager.set_root_view(manager, frame)
              Manager.render_frame(manager)
              # Target 30 FPS for spinner
              Process.sleep(32)
            end)

          time
        end

      avg_frame_time = Enum.sum(frame_times) / length(frame_times)
      # Average frame time under 32ms
      assert avg_frame_time < 0.032
    end

    test "handles chart animation smoothly" do
      {:ok, manager} = Manager.start_link([])

      # Create animated chart frames
      data_points = 30

      frames =
        for frame <- 1..60 do
          # Create moving sine wave
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

      # Measure frame rendering times
      frame_times =
        for frame <- frames do
          {_, time} =
            measure(fn ->
              Manager.set_root_view(manager, frame)
              Manager.render_frame(manager)
              Process.sleep(16)
            end)

          time
        end

      avg_frame_time = Enum.sum(frame_times) / length(frame_times)
      # Average frame time under 16ms
      assert avg_frame_time < 0.016
    end
  end

  describe "scrolling performance" do
    test "handles smooth vertical scrolling" do
      {:ok, manager} = Manager.start_link([])

      # Create large content
      content =
        Table.new(
          columns: [
            %{header: "ID", key: :id, width: 6, align: :right},
            %{header: "Name", key: :name, width: 20, align: :left}
          ],
          data: @large_data,
          border: :single
        )

      viewport_height = 20
      # +1 for header
      total_height = length(@large_data) + 1

      # Measure scroll performance
      scroll_times =
        for offset <- 0..min(total_height - viewport_height, 50) do
          {_, time} =
            measure(fn ->
              view =
                View.box(
                  size: {30, viewport_height},
                  children: [
                    View.box(
                      position: {0, -offset},
                      children: [content]
                    )
                  ]
                )

              Manager.set_root_view(manager, view)
              Manager.render_frame(manager)
              Process.sleep(16)
            end)

          time
        end

      avg_scroll_time = Enum.sum(scroll_times) / length(scroll_times)
      max_scroll_time = Enum.max(scroll_times)

      # Ensure smooth scrolling
      # Average under 16ms
      assert avg_scroll_time < 0.016
      # No frame takes longer than 32ms
      assert max_scroll_time < 0.032
    end

    test "handles horizontal scrolling efficiently" do
      {:ok, manager} = Manager.start_link([])

      # Create wide content with many columns
      columns =
        for i <- 1..20 do
          %{
            header: "Column #{i}",
            key: :id,
            width: 15,
            align: :left,
            format: fn id -> "Value #{id}-#{i}" end
          }
        end

      content =
        Table.new(
          columns: columns,
          data: Enum.take(@large_data, 100),
          border: :single
        )

      viewport_width = 80
      # Each column is 15 wide
      total_width = length(columns) * 15

      # Measure horizontal scroll performance
      scroll_times =
        for offset <- 0..min(total_width - viewport_width, 50) do
          {_, time} =
            measure(fn ->
              view =
                View.box(
                  size: {viewport_width, 30},
                  children: [
                    View.box(
                      position: {-offset, 0},
                      children: [content]
                    )
                  ]
                )

              Manager.set_root_view(manager, view)
              Manager.render_frame(manager)
              Process.sleep(16)
            end)

          time
        end

      avg_scroll_time = Enum.sum(scroll_times) / length(scroll_times)
      # Average under 16ms
      assert avg_scroll_time < 0.016
    end
  end

  describe "dynamic content performance" do
    test "handles real-time data updates efficiently" do
      {:ok, manager} = Manager.start_link([])

      # Simulate real-time data updates
      update_times =
        for _i <- 1..100 do
          # Update random data point
          updated_data =
            Enum.map(@large_data, fn item ->
              # 5% chance to update
              if :rand.uniform(100) < 5 do
                %{
                  item
                  | sales: Enum.map(item.sales, fn _ -> :rand.uniform(1000) end)
                }
              else
                item
              end
            end)

          {_, time} =
            measure(fn ->
              view = create_large_complex_layout(updated_data)
              Manager.set_root_view(manager, view)
              Manager.render_frame(manager)
              Process.sleep(16)
            end)

          time
        end

      avg_update_time = Enum.sum(update_times) / length(update_times)
      # Average under 16ms
      assert avg_update_time < 0.016
    end

    test "handles incremental content loading" do
      {:ok, manager} = Manager.start_link([])
      chunk_size = 50

      # Measure performance of incrementally loading content
      load_times =
        for chunk_start <- 0..950//chunk_size do
          current_data = Enum.slice(@large_data, 0..(chunk_start + chunk_size))

          {_, time} =
            measure(fn ->
              view =
                Table.new(
                  columns: [
                    %{header: "ID", key: :id, width: 6, align: :right},
                    %{header: "Name", key: :name, width: 20, align: :left}
                  ],
                  data: current_data,
                  border: :single
                )

              Manager.set_root_view(manager, view)
              Manager.render_frame(manager)
              # Simulate network delay
              Process.sleep(32)
            end)

          time
        end

      avg_load_time = Enum.sum(load_times) / length(load_times)
      # Average under 32ms
      assert avg_load_time < 0.032
    end
  end

  # Helper functions

  defp create_nested_structure(depth, current_depth \\ 0)
  defp create_nested_structure(depth, depth), do: View.text("Leaf")

  defp create_nested_structure(depth, current_depth) do
    children =
      for _ <- 1..3 do
        create_nested_structure(depth, current_depth + 1)
      end

    if rem(current_depth, 2) == 0 do
      View.flex(direction: :row, children: children)
    else
      View.grid(columns: 3, children: children)
    end
  end

  defp count_nested_views(view) do
    1 +
      (Map.get(view, :children, [])
       |> Enum.map(&count_nested_views/1)
       |> Enum.sum())
  end

  defp create_complex_layout do
    View.box(
      children: [
        View.box(
          border: :single,
          children: [View.text("Header", style: [:bold])]
        ),
        View.flex(
          direction: :row,
          children: [
            View.box(
              size: {30, :auto},
              children: [
                Table.new(
                  columns: [
                    %{header: "ID", key: :id, width: 6, align: :right},
                    %{header: "Name", key: :name, width: 20, align: :left}
                  ],
                  data: Enum.take(@large_data, 100),
                  border: :single
                )
              ]
            ),
            View.grid(
              columns: 2,
              children:
                for i <- 1..4 do
                  Chart.new(
                    type: if(rem(i, 2) == 0, do: :bar, else: :line),
                    series: [
                      %{
                        name: "Series #{i}",
                        data:
                          Enum.take_random(@large_data, 20)
                          |> Enum.map(&List.first(&1.sales)),
                        color: :blue
                      }
                    ],
                    width: 30,
                    height: 10,
                    show_axes: true
                  )
                end
            )
          ]
        )
      ]
    )
  end

  defp create_large_complex_layout(data \\ @large_data) do
    View.box(
      children: [
        View.flex(
          direction: :row,
          children: [
            View.box(
              size: {40, :auto},
              children: [
                Table.new(
                  columns: [
                    %{header: "ID", key: :id, width: 6, align: :right},
                    %{header: "Name", key: :name, width: 20, align: :left},
                    %{
                      header: "Trend",
                      key: :sales,
                      width: 12,
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
                          width: 12
                        )
                      end
                    }
                  ],
                  data: data,
                  border: :single,
                  striped: true
                )
              ]
            ),
            View.grid(
              columns: 3,
              children:
                for i <- 1..9 do
                  Chart.new(
                    type:
                      case rem(i, 3) do
                        0 -> :bar
                        1 -> :line
                        2 -> :sparkline
                      end,
                    series: [
                      %{
                        name: "Series #{i}",
                        data:
                          Enum.take_random(data, 50)
                          |> Enum.map(&List.first(&1.sales)),
                        color: :blue
                      }
                    ],
                    width: 20,
                    height: 8,
                    show_axes: true
                  )
                end
            )
          ]
        )
      ]
    )
  end
end
