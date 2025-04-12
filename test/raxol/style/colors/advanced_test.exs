defmodule Raxol.Style.Colors.AdvancedTest do
  use ExUnit.Case
  alias Raxol.Style.Colors.{Color, Advanced}

  describe "blend_colors/3" do
    test "blends red and blue to purple" do
      red = Color.from_hex("#FF0000")
      blue = Color.from_hex("#0000FF")
      purple = Advanced.blend_colors(red, blue, 0.5)

      assert purple.hex == "#800080"
    end

    test "blends with ratio 0 returns first color" do
      red = Color.from_hex("#FF0000")
      blue = Color.from_hex("#0000FF")
      result = Advanced.blend_colors(red, blue, 0.0)

      assert result.hex == red.hex
    end

    test "blends with ratio 1 returns second color" do
      red = Color.from_hex("#FF0000")
      blue = Color.from_hex("#0000FF")
      result = Advanced.blend_colors(red, blue, 1.0)

      assert result.hex == blue.hex
    end
  end

  describe "create_gradient/3" do
    test "creates a gradient with 3 steps" do
      red = Color.from_hex("#FF0000")
      blue = Color.from_hex("#0000FF")
      gradient = Advanced.create_gradient(red, blue, 3)

      assert length(gradient) == 3
      assert Enum.at(gradient, 0).hex == "#FF0000"
      assert Enum.at(gradient, 1).hex == "#800080"
      assert Enum.at(gradient, 2).hex == "#0000FF"
    end

    test "creates a gradient with 2 steps" do
      red = Color.from_hex("#FF0000")
      blue = Color.from_hex("#0000FF")
      gradient = Advanced.create_gradient(red, blue, 2)

      assert length(gradient) == 2
      assert Enum.at(gradient, 0).hex == "#FF0000"
      assert Enum.at(gradient, 1).hex == "#0000FF"
    end
  end

  describe "convert_color_space/2" do
    test "converts RGB to HSL" do
      red = Color.from_hex("#FF0000")
      hsl = Advanced.convert_color_space(red, :hsl)

      assert hsl.h == 0
      assert hsl.s == 100
      assert hsl.l == 50
    end

    test "converts RGB to Lab" do
      red = Color.from_hex("#FF0000")
      lab = Advanced.convert_color_space(red, :lab)

      assert is_number(lab.l)
      assert is_number(lab.a)
      assert is_number(lab.b)
    end

    test "converts RGB to XYZ" do
      red = Color.from_hex("#FF0000")
      xyz = Advanced.convert_color_space(red, :xyz)

      assert is_number(xyz.x)
      assert is_number(xyz.y)
      assert is_number(xyz.z)
    end
  end

  describe "create_harmony/2" do
    test "creates complementary harmony" do
      red = Color.from_hex("#FF0000")
      harmony = Advanced.create_harmony(red, :complementary)

      assert length(harmony) == 2
      assert Enum.at(harmony, 0).hex == "#FF0000"
      assert Enum.at(harmony, 1).hex == "#00FFFF"
    end

    test "creates analogous harmony" do
      red = Color.from_hex("#FF0000")
      harmony = Advanced.create_harmony(red, :analogous)

      assert length(harmony) == 3
      assert Enum.at(harmony, 0).hex == "#FF0000"
    end

    test "creates triadic harmony" do
      red = Color.from_hex("#FF0000")
      harmony = Advanced.create_harmony(red, :triadic)

      assert length(harmony) == 3
      assert Enum.at(harmony, 0).hex == "#FF0000"
    end

    test "creates tetradic harmony" do
      red = Color.from_hex("#FF0000")
      harmony = Advanced.create_harmony(red, :tetradic)

      assert length(harmony) == 4
      assert Enum.at(harmony, 0).hex == "#FF0000"
    end
  end

  describe "adapt_color_advanced/2" do
    test "adapts color with default options" do
      red = Color.from_hex("#FF0000")
      adapted = Advanced.adapt_color_advanced(red)

      assert adapted.hex == red.hex
    end

    test "adapts color with preserve_brightness option" do
      red = Color.from_hex("#FF0000")
      adapted = Advanced.adapt_color_advanced(red, preserve_brightness: true)

      assert adapted.hex == red.hex
    end

    test "adapts color with enhance_contrast option" do
      red = Color.from_hex("#FF0000")
      adapted = Advanced.adapt_color_advanced(red, enhance_contrast: true)

      assert adapted.hex == red.hex
    end

    test "adapts color with color_blind_safe option" do
      red = Color.from_hex("#FF0000")
      adapted = Advanced.adapt_color_advanced(red, color_blind_safe: true)

      assert adapted.hex == red.hex
    end
  end
end
