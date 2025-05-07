defmodule Raxol.Style.Colors.GradientTest do
  use ExUnit.Case
  doctest Raxol.Style.Colors.Gradient

  alias Raxol.Style.Colors.{Color, Gradient}

  describe "linear/3" do
    test "creates a linear gradient with the correct number of steps" do
      red = Color.from_hex("#FF0000")
      blue = Color.from_hex("#0000FF")
      steps = 5

      gradient = Gradient.linear(red, blue, steps)

      assert length(gradient.colors) == steps
      assert gradient.type == :linear
      # First color is red
      assert hd(gradient.colors).hex == "#FF0000"
      # Last color is blue
      assert List.last(gradient.colors).hex == "#0000FF"
    end

    test "interpolates colors correctly" do
      red = Color.from_hex("#FF0000")
      blue = Color.from_hex("#0000FF")

      gradient = Gradient.linear(red, blue, 3)

      assert length(gradient.colors) == 3
      # Middle color should be purple (average of red and blue)
      middle_color = Enum.at(gradient.colors, 1)
      assert middle_color.r == 128
      assert middle_color.g == 0
      assert middle_color.b == 128
    end
  end

  describe "multi_stop/2" do
    test "creates a multi-stop gradient with the correct number of steps" do
      colors = [
        # Red
        Color.from_hex("#FF0000"),
        # Green
        Color.from_hex("#00FF00"),
        # Blue
        Color.from_hex("#0000FF")
      ]

      steps = 10

      gradient = Gradient.multi_stop(colors, steps)

      assert length(gradient.colors) == steps
      assert gradient.type == :multi_stop
      # First color is red
      assert hd(gradient.colors).hex == "#FF0000"
      # Last color is blue
      assert List.last(gradient.colors).hex == "#0000FF"
    end

    test "handles uneven distribution of steps" do
      colors = [
        # Red
        Color.from_hex("#FF0000"),
        # Green
        Color.from_hex("#00FF00"),
        # Blue
        Color.from_hex("#0000FF")
      ]

      # Not evenly divisible by (colors - 1)
      steps = 5

      gradient = Gradient.multi_stop(colors, steps)

      assert length(gradient.colors) == steps
      # First color is red
      assert hd(gradient.colors).hex == "#FF0000"
      # Last color is blue
      assert List.last(gradient.colors).hex == "#0000FF"
    end

    test "raises error with less than 2 colors" do
      colors = [Color.from_hex("#FF0000")]

      assert_raise FunctionClauseError, fn ->
        Gradient.multi_stop(colors, 5)
      end
    end
  end

  describe "rainbow/1" do
    test "creates a rainbow gradient with the specified steps" do
      steps = 7

      gradient = Gradient.rainbow(steps)

      assert length(gradient.colors) == steps
      assert gradient.type == :rainbow
    end
  end

  describe "heat_map/1" do
    test "creates a heat map gradient with the specified steps" do
      steps = 5

      gradient = Gradient.heat_map(steps)

      assert length(gradient.colors) == steps
      assert gradient.type == :heat_map

      # First color should be blue (cold)
      assert hd(gradient.colors).hex == "#0000FF"
      # Last color should be red (hot)
      assert List.last(gradient.colors).hex == "#FF0000"
    end
  end

  describe "at_position/2" do
    test "gets color at the beginning of the gradient" do
      red = Color.from_hex("#FF0000")
      blue = Color.from_hex("#0000FF")
      gradient = Gradient.linear(red, blue, 5)

      color = Gradient.at_position(gradient, 0.0)
      assert color.hex == "#FF0000"
    end

    test "gets color at the end of the gradient" do
      red = Color.from_hex("#FF0000")
      blue = Color.from_hex("#0000FF")
      gradient = Gradient.linear(red, blue, 5)

      color = Gradient.at_position(gradient, 1.0)
      assert color.hex == "#0000FF"
    end

    test "gets color at the middle of the gradient" do
      red = Color.from_hex("#FF0000")
      blue = Color.from_hex("#0000FF")
      gradient = Gradient.linear(red, blue, 5)

      color = Gradient.at_position(gradient, 0.5)
      # Should be middle color (around purple)
      assert color.r > 0 and color.r < 255
      assert color.b > 0 and color.b < 255
    end
  end

  describe "reverse/1" do
    test "reverses the order of colors in the gradient" do
      red = Color.from_hex("#FF0000")
      blue = Color.from_hex("#0000FF")
      gradient = Gradient.linear(red, blue, 5)

      reversed = Gradient.reverse(gradient)

      # First color is now blue
      assert hd(reversed.colors).hex == "#0000FF"
      # Last color is now red
      assert List.last(reversed.colors).hex == "#FF0000"
      assert length(reversed.colors) == length(gradient.colors)
    end
  end

  describe "apply_to_text/2" do
    test "applies colors to text" do
      red = Color.from_hex("#FF0000")
      blue = Color.from_hex("#0000FF")
      gradient = Gradient.linear(red, blue, 5)
      text = "Hello"

      colored_text = Gradient.apply_to_text(gradient, text)

      # Expected output for 5 steps (Red -> #C00040 -> #800080 -> #4000C0 -> Blue)
      expected_output =
        "\e[38;2;255;0;0mH\e[0m" <>
          "\e[38;2;191;0;64me\e[0m" <>
          "\e[38;2;128;0;128ml\e[0m" <>
          "\e[38;2;64;0;191ml\e[0m" <>
          "\e[38;2;0;0;255mo\e[0m"

      assert colored_text == expected_output
    end

    test "handles empty text" do
      gradient = Gradient.rainbow(5)

      assert Gradient.apply_to_text(gradient, "") == ""
    end

    test "handles text longer than gradient colors" do
      red = Color.from_hex("#FF0000")
      blue = Color.from_hex("#0000FF")
      gradient = Gradient.linear(red, blue, 3)
      text = "This is a long text that has more characters than colors"

      colored_text = Gradient.apply_to_text(gradient, text)

      # Check that all characters are colored
      assert String.length(colored_text) > String.length(text)
    end

    test "handles text shorter than gradient colors" do
      gradient = Gradient.rainbow(10)
      text = "Hi"

      colored_text = Gradient.apply_to_text(gradient, text)

      # Check that we don't have errors and all characters are colored
      assert String.length(colored_text) > String.length(text)
    end
  end

  describe "to_ansi_sequence/2" do
    test "is an alias for apply_to_text" do
      red = Color.from_hex("#FF0000")
      blue = Color.from_hex("#0000FF")
      gradient = Gradient.linear(red, blue, 5)
      text = "Hello"

      result1 = Gradient.apply_to_text(gradient, text)
      result2 = Gradient.to_ansi_sequence(gradient, text)

      assert result1 == result2
    end
  end
end
