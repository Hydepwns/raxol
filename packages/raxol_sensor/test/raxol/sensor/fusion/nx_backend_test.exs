defmodule Raxol.Sensor.Fusion.NxBackendTest do
  use ExUnit.Case, async: true

  alias Raxol.Sensor.Fusion.NxBackend

  describe "weighted_average/2" do
    test "computes weighted average of single reading" do
      values = [%{temp: 20.0, humidity: 60.0}]
      qualities = [1.0]

      result = NxBackend.weighted_average(values, qualities)

      assert_in_delta result.temp, 20.0, 0.001
      assert_in_delta result.humidity, 60.0, 0.001
    end

    test "computes weighted average of multiple readings" do
      values = [
        %{temp: 20.0, humidity: 60.0},
        %{temp: 30.0, humidity: 40.0}
      ]

      qualities = [1.0, 1.0]

      result = NxBackend.weighted_average(values, qualities)

      assert_in_delta result.temp, 25.0, 0.001
      assert_in_delta result.humidity, 50.0, 0.001
    end

    test "weights readings by quality" do
      values = [
        %{temp: 20.0},
        %{temp: 40.0}
      ]

      # 3:1 weight ratio -> (20*3 + 40*1)/4 = 25.0
      qualities = [3.0, 1.0]

      result = NxBackend.weighted_average(values, qualities)

      assert_in_delta result.temp, 25.0, 0.001
    end

    test "returns first reading when total quality is zero" do
      values = [%{temp: 20.0}, %{temp: 30.0}]
      qualities = [0.0, 0.0]

      result = NxBackend.weighted_average(values, qualities)

      assert result.temp == 20.0
    end

    test "handles missing keys across readings" do
      values = [
        %{temp: 20.0, humidity: 60.0},
        %{temp: 30.0}
      ]

      qualities = [1.0, 1.0]

      result = NxBackend.weighted_average(values, qualities)

      # humidity: (60*1 + 0*1)/2 = 30.0 (missing treated as 0)
      assert_in_delta result.temp, 25.0, 0.001
      assert_in_delta result.humidity, 30.0, 0.001
    end

    test "handles many readings" do
      values = for i <- 1..100, do: %{x: i * 1.0}
      qualities = List.duplicate(1.0, 100)

      result = NxBackend.weighted_average(values, qualities)

      # average of 1..100 = 50.5
      assert_in_delta result.x, 50.5, 0.001
    end

    test "produces same results as pure-Elixir implementation" do
      values = [
        %{a: 10.0, b: 20.0, c: 30.0},
        %{a: 40.0, b: 50.0, c: 60.0},
        %{a: 70.0, b: 80.0, c: 90.0}
      ]

      qualities = [0.5, 1.0, 0.25]
      total = 1.75

      result = NxBackend.weighted_average(values, qualities)

      expected_a = (10.0 * 0.5 + 40.0 * 1.0 + 70.0 * 0.25) / total
      expected_b = (20.0 * 0.5 + 50.0 * 1.0 + 80.0 * 0.25) / total
      expected_c = (30.0 * 0.5 + 60.0 * 1.0 + 90.0 * 0.25) / total

      assert_in_delta result.a, expected_a, 0.001
      assert_in_delta result.b, expected_b, 0.001
      assert_in_delta result.c, expected_c, 0.001
    end
  end
end
