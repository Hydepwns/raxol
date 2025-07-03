import Raxol.Core.Renderer.View, only: [ensure_keyword: 1]
import Raxol.Guards

defmodule Raxol.Core.Renderer.Views.ChartTest do
  @moduledoc """
  Tests for the chart module, including creation, features,
  data handling, and axes/labels.
  """
  use ExUnit.Case

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
      # Use full name
      view =
        Raxol.Core.Renderer.Views.Chart.new(
          type: :bar,
          series: @sample_series,
          width: 20,
          height: 10
        )

      assert map?(view)
      assert Map.has_key?(view, :type)
      assert view.type == :box
      assert view.children != nil
    end

    test "creates a line chart" do
      # Use full name
      view =
        Raxol.Core.Renderer.Views.Chart.new(
          type: :line,
          series: @sample_series,
          width: 20,
          height: 10
        )

      assert map?(view)
      assert Map.has_key?(view, :type)
      assert view.type == :box
      assert view.children != nil
    end

    test "creates a sparkline" do
      # Sparkline only uses the first series
      spark_series = [@sample_series |> List.first()]

      # Use full name
      view =
        Raxol.Core.Renderer.Views.Chart.new(
          type: :sparkline,
          series: spark_series,
          width: 20
        )

      assert map?(view)
      assert Map.has_key?(view, :type)
      assert view.type == :box
      text_views = view.children
      assert text_views != nil
      assert list?(text_views)

      # Find the text view in the list
      text_view = Enum.find(text_views, fn v -> map?(v) and Map.get(v, :type) == :text end)
      assert text_view != nil
      assert text_view.type == :text
      assert text_view.content != nil
      # The sparkline should have exactly 20 characters (5 data points + 15 spaces)
      assert String.length(text_view.content) == 20
      # Should end with spaces (padded to full width)
      assert String.ends_with?(text_view.content, "               ")
    end
  end

  # End of describe "new/1"

  describe "bar chart features" do
    test "handles vertical orientation" do
      # Use full name
      view =
        Raxol.Core.Renderer.Views.Chart.new(
          type: :bar,
          orientation: :vertical,
          series: @sample_series,
          width: 20,
          height: 10
        )

      content = view
      assert map?(content)
      assert Map.has_key?(content, :type)
      assert content.type == :box
    end

    test "handles horizontal orientation" do
      # Use full name
      view =
        Raxol.Core.Renderer.Views.Chart.new(
          type: :bar,
          orientation: :horizontal,
          series: @sample_series,
          width: 20,
          height: 10
        )

      content = view
      assert map?(content)
      assert Map.has_key?(content, :type)
      assert content.type == :box
    end

    # Helper function
    defp find_all_text_children(view) do
      case view do
        %{type: :text} -> [view]
        %{children: children} -> process_children(children)
        _ -> []
      end
    end

    defp process_children(children) when list?(children) do
      if Enum.all?(children, &list?/1) do
        children
        |> List.flatten()
        |> Enum.flat_map(&find_all_text_children/1)
      else
        Enum.flat_map(children, &find_all_text_children/1)
      end
    end

    defp process_children(%{} = child_map),
      do: find_all_text_children(child_map)

    defp process_children(_), do: []

    test "applies colors to bars" do
      # Need to re-create the view within the test as setup context is gone
      view =
        Raxol.Core.Renderer.Views.Chart.new(
          type: :bar,
          series: @sample_series,
          width: 20,
          height: 10
        )

      bars = find_all_text_children(view)
      assert Enum.any?(bars, fn bar -> map?(bar) and bar.fg == :blue end)
      assert Enum.any?(bars, fn bar -> map?(bar) and bar.fg == :red end)
    end
  end

  describe "line chart features" do
    # Sample data for line charts - Restructure to match expected series format
    # The chart expects a list of series, each with a :data key containing points.
    @line_data_series [
      %{
        # Added name for consistency
        name: "Series 1",
        # Use the values as data points
        data: [10, 20],
        # Assuming color applies to the series
        color: :blue
      },
      %{
        name: "Series 2",
        # Example data points
        data: [15, 5],
        color: :red
      }
    ]

    test "creates points and lines" do
      # Define two-series data locally for this test
      local_series_data = [
        %{name: "Series 1", data: [10, 20], color: :blue},
        %{name: "Series 2", data: [15, 5], color: :red}
      ]

      # Use the local data
      view =
        Raxol.Core.Renderer.Views.Chart.new(
          type: :line,
          series: local_series_data,
          width: 40,
          height: 10
        )

      # Find points (represented by •)
      content = view
      points = find_all_text_children(content)
      # Check for at least 2 points
      assert Enum.count(points, &(map?(&1) and &1.content == "•")) >= 2
    end

    test "applies colors to lines" do
      # Define two-series data locally for this test
      local_series_data = [
        %{name: "Series 1", data: [10, 20], color: :blue},
        %{name: "Series 2", data: [15, 5], color: :red}
      ]

      # Use the local data
      view =
        Raxol.Core.Renderer.Views.Chart.new(
          type: :line,
          series: local_series_data,
          width: 40,
          height: 10
        )

      # Find points (represented by •) and check colors
      content = view
      points = find_all_text_children(content)
      assert Enum.any?(points, &(map?(&1) and &1.fg == :blue))
      assert Enum.any?(points, &(map?(&1) and &1.fg == :red))
    end
  end

  describe "axes and labels" do
    # Skipped tests removed: axes and legend features not implemented and not planned.
  end

  describe "data handling" do
    test "respects custom min/max" do
      # Use full name
      view =
        Raxol.Core.Renderer.Views.Chart.new(
          type: :bar,
          series: @sample_series,
          width: 20,
          height: 10,
          min_value: 0,
          max_value: 10
        )

      # Add assertions to verify min/max impact if possible
      assert map?(view)
      assert Map.has_key?(view, :type)
      assert view != nil
    end

    test "handles empty data" do
      view =
        Raxol.Core.Renderer.Views.Chart.new(type: :bar, series: [%{data: []}])

      # Verify the structure returned for empty data
      assert map?(view)
      assert Map.has_key?(view, :type)
      assert view.type == :box

      # The children should be a list containing the empty flex container
      children = view.children
      assert list?(children)
      assert length(children) == 1

      content_view = List.first(children)
      assert map?(content_view)
      assert Map.has_key?(content_view, :type)
      assert content_view.type == :flex
      assert content_view.children == []
    end
  end
end
