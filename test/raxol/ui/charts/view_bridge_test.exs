defmodule Raxol.UI.Charts.ViewBridgeTest do
  use ExUnit.Case, async: true

  alias Raxol.UI.Charts.{LineChart, ViewBridge}

  describe "cells_to_view/2" do
    test "empty cells returns empty box" do
      result = ViewBridge.cells_to_view([])
      assert result.type == :box
      assert result.children == []
    end

    test "converts cells to view elements" do
      cells = [
        {0, 0, "A", :red, :default, %{}},
        {1, 0, "B", :red, :default, %{}},
        {0, 1, "C", :blue, :default, %{}}
      ]

      result = ViewBridge.cells_to_view(cells)
      assert result.type == :box
      assert [_ | _] = result.children

      # All children should be text elements
      assert Enum.all?(result.children, fn child -> child.type == :text end)
    end

    test "groups same-color cells on same row" do
      cells = [
        {0, 0, "A", :red, :default, %{}},
        {1, 0, "B", :red, :default, %{}},
        {2, 0, "C", :red, :default, %{}}
      ]

      result = ViewBridge.cells_to_view(cells)
      # Should produce a single text element "ABC"
      assert length(result.children) == 1
      assert hd(result.children).content == "ABC"
    end

    test "different colors on same row split into separate elements" do
      cells = [
        {0, 0, "A", :red, :default, %{}},
        {1, 0, "B", :blue, :default, %{}}
      ]

      result = ViewBridge.cells_to_view(cells)
      assert length(result.children) == 2
    end

    test "preserves fg color on text elements" do
      cells = [{0, 0, "X", :magenta, :default, %{}}]
      result = ViewBridge.cells_to_view(cells)
      [child] = result.children
      assert child.fg == :magenta
    end

    test "style option passed to box" do
      cells = [{0, 0, "X", :white, :default, %{}}]
      result = ViewBridge.cells_to_view(cells, style: %{border: :single})
      assert result.style == %{border: :single}
    end
  end

  describe "chart_box/3" do
    test "wraps chart function output in view element" do
      series = [%{name: "Test", data: [1, 2, 3, 4, 5], color: :cyan}]

      result =
        ViewBridge.chart_box(&LineChart.render/3, [{0, 0, 10, 5}, series, []])

      assert result.type == :box
      assert [_ | _] = result.children
    end
  end
end
