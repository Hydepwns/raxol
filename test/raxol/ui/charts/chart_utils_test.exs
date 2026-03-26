defmodule Raxol.UI.Charts.ChartUtilsTest do
  use ExUnit.Case, async: true

  alias Raxol.UI.Charts.ChartUtils

  describe "auto_range/1" do
    test "empty list returns {0.0, 1.0}" do
      assert ChartUtils.auto_range([]) == {0.0, 1.0}
    end

    test "single value returns +/- 1.0" do
      assert ChartUtils.auto_range([5.0]) == {4.0, 6.0}
    end

    test "multiple values adds 5% padding" do
      {min, max} = ChartUtils.auto_range([0.0, 100.0])
      assert min < 0.0
      assert max > 100.0
      assert_in_delta min, -5.0, 0.01
      assert_in_delta max, 105.0, 0.01
    end

    test "identical values returns +/- 1.0" do
      assert ChartUtils.auto_range([3.0, 3.0, 3.0]) == {2.0, 4.0}
    end

    test "negative values" do
      {min, max} = ChartUtils.auto_range([-10.0, -5.0])
      assert min < -10.0
      assert max > -5.0
    end
  end

  describe "auto_range_2d/1" do
    test "empty list returns defaults" do
      assert ChartUtils.auto_range_2d([]) == {{0.0, 1.0}, {0.0, 1.0}}
    end

    test "2D points produce separate x and y ranges" do
      {{x_min, x_max}, {y_min, y_max}} =
        ChartUtils.auto_range_2d([{0.0, 10.0}, {100.0, 20.0}])

      assert x_min < 0.0
      assert x_max > 100.0
      assert y_min < 10.0
      assert y_max > 20.0
    end
  end

  describe "scale_value/5" do
    test "scales value linearly" do
      assert_in_delta ChartUtils.scale_value(50, 0, 100, 0, 10), 5.0, 0.01
    end

    test "min equals max returns new_min" do
      assert ChartUtils.scale_value(5, 5, 5, 0, 10) == 0.0
    end

    test "scales to different range" do
      assert_in_delta ChartUtils.scale_value(0, -10, 10, 0, 100), 50.0, 0.01
    end
  end

  describe "clamp/3" do
    test "clamps below minimum" do
      assert ChartUtils.clamp(-5, 0, 10) == 0
    end

    test "clamps above maximum" do
      assert ChartUtils.clamp(15, 0, 10) == 10
    end

    test "value in range unchanged" do
      assert ChartUtils.clamp(5, 0, 10) == 5
    end
  end

  describe "normalize_data/1" do
    test "list passes through" do
      assert ChartUtils.normalize_data([1, 2, 3]) == [1, 2, 3]
    end

    test "CircularBuffer converts to list" do
      cb = Enum.into([1, 2, 3], CircularBuffer.new(5))
      assert ChartUtils.normalize_data(cb) == [1, 2, 3]
    end
  end

  describe "render_axes/3" do
    test "produces cell tuples" do
      cells = ChartUtils.render_axes({0, 0, 10, 5}, {0.0, 100.0})
      assert [_ | _] = cells
      assert Enum.all?(cells, fn cell -> tuple_size(cell) == 6 end)
    end
  end

  describe "render_legend/3" do
    test "renders series names with colors" do
      series = [
        %{name: "A", color: :red},
        %{name: "B", color: :blue}
      ]

      cells = ChartUtils.render_legend(0, 0, series)
      assert [_ | _] = cells

      # Should contain series name characters
      chars = Enum.map_join(cells, fn {_x, _y, c, _fg, _bg, _a} -> c end)
      assert String.contains?(chars, "A")
      assert String.contains?(chars, "B")
    end
  end

  describe "format_axis_label/2" do
    test "formats float" do
      assert ChartUtils.format_axis_label(3.14159, 2) == "3.14"
    end

    test "formats integer" do
      assert ChartUtils.format_axis_label(42, 1) == "42.0"
    end
  end
end
