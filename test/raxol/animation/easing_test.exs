defmodule Raxol.Animation.EasingTest do
  use ExUnit.Case

  alias Raxol.Animation.Easing

  describe "Easing Functions" do
    test "linear easing" do
      t = 0.5
      assert Easing.calculate_value(:linear, 0.0) == 0.0
      assert Easing.calculate_value(:linear, 1.0) == 1.0
      assert Easing.calculate_value(:linear, t) == t
    end

    test "quadratic ease-in" do
      t = 0.5
      assert Easing.calculate_value(:ease_in_quad, 0.0) == 0.0
      assert Easing.calculate_value(:ease_in_quad, 1.0) == 1.0
      assert Easing.calculate_value(:ease_in_quad, t) == t * t
    end

    test "quadratic ease-out" do
      t = 0.5
      assert Easing.calculate_value(:ease_out_quad, 0.0) == 0.0
      assert Easing.calculate_value(:ease_out_quad, 1.0) == 1.0
      assert Easing.calculate_value(:ease_out_quad, t) == t * (2 - t)
    end

    test "quadratic ease-in-out" do
      # Test below 0.5
      t = 0.4
      assert Easing.calculate_value(:ease_in_out_quad, 0.0) == 0.0
      assert Easing.calculate_value(:ease_in_out_quad, 1.0) == 1.0
      assert Easing.calculate_value(:ease_in_out_quad, t) == 2 * t * t
      # Test above 0.5
      t = 0.6

      assert Easing.calculate_value(:ease_in_out_quad, t) ==
               -1 + (4 - 2 * t) * t
    end

    test "cubic ease-in" do
      t = 0.5
      assert Easing.calculate_value(:ease_in_cubic, 0.0) == 0.0
      assert Easing.calculate_value(:ease_in_cubic, 1.0) == 1.0
      assert Easing.calculate_value(:ease_in_cubic, t) == t * t * t
    end

    test "cubic ease-out" do
      t = 0.5
      assert Easing.calculate_value(:ease_out_cubic, 0.0) == 0.0
      assert Easing.calculate_value(:ease_out_cubic, 1.0) == 1.0
      t_minus_1 = t - 1

      assert Easing.calculate_value(:ease_out_cubic, t) ==
               t_minus_1 * t_minus_1 * t_minus_1 + 1
    end

    test "cubic ease-in-out" do
      # Test below 0.5
      t = 0.4
      assert Easing.calculate_value(:ease_in_out_cubic, 0.0) == 0.0
      assert Easing.calculate_value(:ease_in_out_cubic, 1.0) == 1.0
      assert Easing.calculate_value(:ease_in_out_cubic, t) == 4 * t * t * t
      # Test above 0.5
      t = 0.6
      t_minus_1 = t - 1

      assert Easing.calculate_value(:ease_in_out_cubic, t) ==
               (t - 1) * (2 * t_minus_1 * t_minus_1) + 1
    end

    test "elastic ease-in" do
      t = 0.7
      assert Easing.calculate_value(:ease_in_elastic, 0.0) == 0.0
      assert Easing.calculate_value(:ease_in_elastic, 1.0) == 1.0
      # Approximate value for elastic ease-in at t=0.7
      assert_in_delta Easing.calculate_value(:ease_in_elastic, t), -0.022, 0.001
    end

    test "elastic ease-out" do
      t = 0.7
      assert Easing.calculate_value(:ease_out_elastic, 0.0) == 0.0
      assert Easing.calculate_value(:ease_out_elastic, 1.0) == 1.0
      # Approximate value for elastic ease-out at t=0.7
      assert_in_delta Easing.calculate_value(:ease_out_elastic, t), 1.022, 0.001
    end

    test "elastic ease-in-out" do
      t = 0.7
      assert Easing.calculate_value(:ease_in_out_elastic, 0.0) == 0.0
      assert Easing.calculate_value(:ease_in_out_elastic, 1.0) == 1.0
      # Approximate value for elastic ease-in-out at t=0.7
      assert_in_delta Easing.calculate_value(:ease_in_out_elastic, t),
                      1.011,
                      0.001
    end

    test "standard ease-in" do
      t = 0.5
      assert Easing.calculate_value(:ease_in, 0.0) == 0.0
      assert Easing.calculate_value(:ease_in, 1.0) == 1.0
      # Update assertion based on actual default implementation if different
      # Defaults to quad
      assert Easing.calculate_value(:ease_in, t) == t * t
    end

    test "standard ease-out" do
      t = 0.5
      assert Easing.calculate_value(:ease_out, 0.0) == 0.0
      assert Easing.calculate_value(:ease_out, 1.0) == 1.0
      # Update assertion based on actual default implementation if different
      # Defaults to quad
      assert Easing.calculate_value(:ease_out, t) == t * (2 - t)
    end

    test "standard ease-in-out" do
      t = 0.4
      assert Easing.calculate_value(:ease_in_out, 0.0) == 0.0
      assert Easing.calculate_value(:ease_in_out, 1.0) == 1.0
      # Update assertion based on actual default implementation if different
      # Defaults to quad
      assert Easing.calculate_value(:ease_in_out, t) == 2 * t * t
    end

    test "all functions maintain range [0.0, 1.0] for inputs in [0.0, 1.0]" do
      inputs = [0.0, 0.1, 0.5, 0.9, 1.0]

      functions = [
        :linear,
        :ease_in_quad,
        :ease_out_quad,
        :ease_in_out_quad,
        :ease_in_cubic,
        :ease_out_cubic,
        :ease_in_out_cubic,
        :ease_in_elastic,
        :ease_out_elastic,
        :ease_in_out_elastic,
        :ease_in,
        :ease_out,
        :ease_in_out
      ]

      for func_atom <- functions, t <- inputs do
        result = Easing.calculate_value(func_atom, t)

        assert result >= 0.0 and result <= 1.0,
               "Easing.calculate_value(:#{func_atom}, #{t}) result #{result} out of range [0.0, 1.0]"
      end
    end
  end
end
