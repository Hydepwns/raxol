defmodule Raxol.Core.Renderer.Views.ChartTest do
  use ExUnit.Case, async: true
  alias Raxol.Core.Renderer.Views.Chart
  alias Raxol.Core.Renderer.View

  @sample_series [
    %{
      name: "Series A",
      data: [1, 4, 2, 5, 3],
      color: :blue
    },
    %{
      name: "Series B",
      data: [2, 3, 4, 1, 5],
      color: :red
    }
  ]

  describe "new/1" do
    test "creates a basic bar chart" do
      view =
        Chart.new(
          type: :bar,
          series: @sample_series,
          width: 20,
          height: 10
        )

      assert view.type == :box
      content = List.first(view.children)
      assert content != nil
    end

    test "creates a line chart" do
      view =
        Chart.new(
          type: :line,
          series: @sample_series,
          width: 20,
          height: 10
        )

      assert view.type == :box
      content = List.first(view.children)
      assert content != nil
    end

    test "creates a sparkline" do
      view =
        Chart.new(
          type: :sparkline,
          series: [@sample_series |> List.first()],
          width: 20
        )

      assert view.type == :box
      content = List.first(view.children)
      assert content.type == :text
      assert String.length(content.content) == 20
    end
  end

  describe "bar chart features" do
    test "handles vertical orientation" do
      view =
        Chart.new(
          type: :bar,
          orientation: :vertical,
          series: @sample_series,
          width: 20,
          height: 10
        )

      content = get_bar_content(view)
      assert content.type == :flex
      assert content.direction == :row
    end

    test "handles horizontal orientation" do
      view =
        Chart.new(
          type: :bar,
          orientation: :horizontal,
          series: @sample_series,
          width: 20,
          height: 10
        )

      content = get_bar_content(view)
      assert content.type == :flex
      assert content.direction == :column
    end

    test "applies colors to bars" do
      view =
        Chart.new(
          type: :bar,
          series: @sample_series,
          width: 20,
          height: 10
        )

      content = get_bar_content(view)
      bars = content.children
      assert Enum.any?(bars, &(&1.fg == :blue))
      assert Enum.any?(bars, &(&1.fg == :red))
    end
  end

  describe "line chart features" do
    test "creates points and lines" do
      view =
        Chart.new(
          type: :line,
          series: @sample_series,
          width: 20,
          height: 10
        )

      content = get_line_content(view)
      points = List.flatten(content.children)
      assert length(points) > 0
      assert Enum.all?(points, &(&1.type == :text))
      assert Enum.all?(points, &(&1.content == "•"))
    end

    test "applies colors to lines" do
      view =
        Chart.new(
          type: :line,
          series: @sample_series,
          width: 20,
          height: 10
        )

      content = get_line_content(view)
      points = List.flatten(content.children)
      assert Enum.any?(points, &(&1.fg == :blue))
      assert Enum.any?(points, &(&1.fg == :red))
    end
  end

  describe "axes and labels" do
    test "adds axes when enabled" do
      view =
        Chart.new(
          type: :bar,
          series: @sample_series,
          width: 20,
          height: 10,
          show_axes: true
        )

      # Find y-axis
      y_axis =
        find_child(view, fn child ->
          child.type == :box and
            Enum.any?(child.children, &(&1.content =~ "│"))
        end)

      assert y_axis != nil

      # Find x-axis
      x_axis =
        find_child(view, fn child ->
          child.type == :text and
            String.contains?(child.content, "─")
        end)

      assert x_axis != nil
    end

    test "adds legend when enabled" do
      view =
        Chart.new(
          type: :bar,
          series: @sample_series,
          width: 20,
          height: 10,
          show_legend: true
        )

      legend =
        find_child(view, fn child ->
          child.type == :flex and
            Enum.any?(child.children, &(&1.content =~ "█"))
        end)

      assert legend != nil
      # Two series
      assert length(legend.children) == 2
    end
  end

  describe "data handling" do
    test "calculates correct range" do
      {min, max} = Chart.calculate_range(@sample_series, nil, nil)
      assert min == 1
      assert max == 5
    end

    test "respects custom min/max" do
      view =
        Chart.new(
          type: :bar,
          series: @sample_series,
          width: 20,
          height: 10,
          min: 0,
          max: 10
        )

      # Just ensure it creates without errors
      assert view != nil
    end

    test "scales values correctly" do
      value = Chart.scale_value(5, 0, 10, 0, 100)
      assert value == 50.0

      value = Chart.scale_value(7.5, 0, 10, 0, 100)
      assert value == 75.0
    end
  end

  # Helper functions

  defp get_bar_content(view) do
    view.children
    |> List.first()
    |> get_in([:children, Access.at(0)])
    |> get_in([:children, Access.at(1)])
  end

  defp get_line_content(view) do
    view.children
    |> List.first()
    |> get_in([:children, Access.at(0)])
    |> get_in([:children, Access.at(1)])
  end

  defp find_child(view, predicate) do
    case view do
      %{children: children} when is_list(children) ->
        Enum.find_value(children, fn child ->
          if predicate.(child) do
            child
          else
            find_child(child, predicate)
          end
        end)

      _ ->
        nil
    end
  end
end
