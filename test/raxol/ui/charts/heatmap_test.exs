defmodule Raxol.UI.Charts.HeatmapTest do
  use ExUnit.Case, async: true

  alias Raxol.UI.Charts.Heatmap

  @region {0, 0, 10, 5}

  describe "render/3" do
    test "returns cell tuples" do
      data = [[1, 2, 3], [4, 5, 6]]
      cells = Heatmap.render(@region, data)
      assert [_ | _] = cells
      assert Enum.all?(cells, fn cell -> tuple_size(cell) == 6 end)
    end

    test "empty data returns empty" do
      assert Heatmap.render(@region, []) == []
    end

    test "empty inner rows returns empty" do
      assert Heatmap.render(@region, [[], []]) == []
    end

    test "single cell renders" do
      cells = Heatmap.render(@region, [[42]])
      assert [_ | _] = cells
    end

    test "warm scale produces expected colors" do
      # Low value -> green, high value -> red
      data = [[0, 100]]
      cells = Heatmap.render({0, 0, 20, 1}, data, color_scale: :warm)

      bgs = Enum.map(cells, fn {_x, _y, _c, _fg, bg, _a} -> bg end) |> Enum.uniq()
      assert :green in bgs or :red in bgs
    end

    test "cool scale" do
      data = [[0, 50, 100]]
      cells = Heatmap.render({0, 0, 30, 1}, data, color_scale: :cool)
      assert [_ | _] = cells
    end

    test "diverging scale" do
      data = [[0, 50, 100]]
      cells = Heatmap.render({0, 0, 30, 1}, data, color_scale: :diverging)
      assert [_ | _] = cells
    end

    test "custom scale function" do
      custom = fn _value, _min, _max -> {:magenta, :yellow} end
      data = [[1, 2], [3, 4]]
      cells = Heatmap.render(@region, data, color_scale: custom)

      assert Enum.all?(cells, fn {_x, _y, _c, fg, bg, _a} ->
               fg == :magenta and bg == :yellow
             end)
    end

    test "show_values renders numbers in cells" do
      data = [[42]]
      cells = Heatmap.render({0, 0, 10, 5}, data, show_values: true)
      chars = Enum.map_join(cells, fn {_x, _y, c, _fg, _bg, _a} -> c end)
      assert String.contains?(chars, "42")
    end

    test "cells within region bounds" do
      data = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
      cells = Heatmap.render({5, 3, 9, 3}, data)

      assert Enum.all?(cells, fn {x, y, _c, _fg, _bg, _a} ->
               x >= 5 and x < 14 and y >= 3 and y < 6
             end)
    end
  end

  describe "color scales" do
    test "warm_scale" do
      assert Heatmap.warm_scale(0.1) == :green
      assert Heatmap.warm_scale(0.4) == :yellow
      assert Heatmap.warm_scale(0.9) == :red
    end

    test "cool_scale" do
      assert Heatmap.cool_scale(0.1) == :blue
      assert Heatmap.cool_scale(0.5) == :cyan
      assert Heatmap.cool_scale(0.9) == :white
    end

    test "diverging_scale" do
      assert Heatmap.diverging_scale(0.1) == :blue
      assert Heatmap.diverging_scale(0.5) == :white
      assert Heatmap.diverging_scale(0.9) == :red
    end
  end
end
