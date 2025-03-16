defmodule Raxol.Style.Colors.ColorTest do
  use ExUnit.Case, async: true
  alias Raxol.Style.Colors.Color

  describe "from_hex/1" do
    test "creates a color from a 6-digit hex string with #" do
      color = Color.from_hex("#FF0000")
      assert color.r == 255
      assert color.g == 0
      assert color.b == 0
      assert color.hex == "#FF0000"
      assert color.ansi_code == 9
    end

    test "creates a color from a 6-digit hex string without #" do
      color = Color.from_hex("00FF00")
      assert color.r == 0
      assert color.g == 255
      assert color.b == 0
      assert color.hex == "#00FF00"
      assert color.ansi_code == 10
    end

    test "creates a color from a 3-digit hex string with #" do
      color = Color.from_hex("#F00")
      assert color.r == 255
      assert color.g == 0
      assert color.b == 0
      assert color.hex == "#F00"
      assert color.ansi_code == 9
    end

    test "creates a color from a 3-digit hex string without #" do
      color = Color.from_hex("0F0")
      assert color.r == 0
      assert color.g == 255
      assert color.b == 0
      assert color.hex == "#0F0"
      assert color.ansi_code == 10
    end

    test "raises error for invalid hex formats" do
      assert_raise ArgumentError, fn -> Color.from_hex("#12") end
      assert_raise ArgumentError, fn -> Color.from_hex("#1234567") end
      assert_raise ArgumentError, fn -> Color.from_hex("XYZ") end
    end
  end

  describe "to_hex/1" do
    test "converts color to hex string" do
      color = Color.from_rgb(255, 0, 0)
      assert Color.to_hex(color) == "#FF0000"
    end

    test "handles zero values correctly" do
      color = Color.from_rgb(0, 0, 0)
      assert Color.to_hex(color) == "#000000"
    end
  end

  describe "from_rgb/3" do
    test "creates a color from RGB values" do
      color = Color.from_rgb(255, 0, 0)
      assert color.r == 255
      assert color.g == 0
      assert color.b == 0
      assert color.hex == "#FF0000"
      assert color.ansi_code == 9
    end

    test "handles zero values correctly" do
      color = Color.from_rgb(0, 0, 0)
      assert color.r == 0
      assert color.g == 0
      assert color.b == 0
      assert color.hex == "#000000"
      assert color.ansi_code == 0
    end
  end

  describe "from_ansi/1" do
    test "creates a color from ANSI code 0 (black)" do
      color = Color.from_ansi(0)
      assert color.r == 0
      assert color.g == 0
      assert color.b == 0
      assert color.hex == "#000000"
      assert color.ansi_code == 0
    end

    test "creates a color from ANSI code 9 (bright red)" do
      color = Color.from_ansi(9)
      assert color.r == 255
      assert color.g == 0
      assert color.b == 0
      assert color.hex == "#FF0000"
      assert color.ansi_code == 9
    end
  end

  describe "to_ansi_16/1" do
    test "converts a color to the closest ANSI 16 code" do
      color = Color.from_rgb(255, 0, 0)
      assert Color.to_ansi_16(color) == 9
    end

    test "finds closest match for non-exact colors" do
      # A dark red that should match basic red (code 1)
      color = Color.from_rgb(150, 20, 20)
      assert Color.to_ansi_16(color) == 1
    end
  end

  describe "lighten/2" do
    test "lightens a color by specified amount" do
      color = Color.from_rgb(100, 100, 100)
      lightened = Color.lighten(color, 0.5)
      assert lightened.r == 177
      assert lightened.g == 177
      assert lightened.b == 177
    end

    test "lightening by 1.0 produces white" do
      color = Color.from_rgb(0, 0, 0)
      white = Color.lighten(color, 1.0)
      assert white.r == 255
      assert white.g == 255
      assert white.b == 255
    end

    test "lightening by 0.0 doesn't change the color" do
      original = Color.from_rgb(100, 150, 200)
      lightened = Color.lighten(original, 0.0)
      assert lightened.r == 100
      assert lightened.g == 150
      assert lightened.b == 200
    end
  end

  describe "darken/2" do
    test "darkens a color by specified amount" do
      color = Color.from_rgb(200, 200, 200)
      darkened = Color.darken(color, 0.5)
      assert darkened.r == 100
      assert darkened.g == 100
      assert darkened.b == 100
    end

    test "darkening by 1.0 produces black" do
      color = Color.from_rgb(255, 255, 255)
      black = Color.darken(color, 1.0)
      assert black.r == 0
      assert black.g == 0
      assert black.b == 0
    end

    test "darkening by 0.0 doesn't change the color" do
      original = Color.from_rgb(100, 150, 200)
      darkened = Color.darken(original, 0.0)
      assert darkened.r == 100
      assert darkened.g == 150
      assert darkened.b == 200
    end
  end

  describe "alpha_blend/3" do
    test "blends two colors with 0.5 alpha" do
      color1 = Color.from_rgb(255, 0, 0)
      color2 = Color.from_rgb(0, 0, 255)
      blended = Color.alpha_blend(color1, color2, 0.5)
      assert blended.r == 127
      assert blended.g == 0
      assert blended.b == 127
    end

    test "alpha 0.0 returns first color" do
      color1 = Color.from_rgb(255, 0, 0)
      color2 = Color.from_rgb(0, 0, 255)
      blended = Color.alpha_blend(color1, color2, 0.0)
      assert blended.r == 255
      assert blended.g == 0
      assert blended.b == 0
    end

    test "alpha 1.0 returns second color" do
      color1 = Color.from_rgb(255, 0, 0)
      color2 = Color.from_rgb(0, 0, 255)
      blended = Color.alpha_blend(color1, color2, 1.0)
      assert blended.r == 0
      assert blended.g == 0
      assert blended.b == 255
    end
  end

  describe "complement/1" do
    test "returns complementary color" do
      color = Color.from_rgb(255, 0, 0)
      complement = Color.complement(color)
      assert complement.r == 0
      assert complement.g == 255
      assert complement.b == 255
    end

    test "applying complement twice returns original color values" do
      original = Color.from_rgb(123, 45, 67)
      complement = Color.complement(original)
      double_complement = Color.complement(complement)
      assert double_complement.r == 123
      assert double_complement.g == 45
      assert double_complement.b == 67
    end
  end

  describe "mix/3" do
    test "mixes two colors with default weight" do
      color1 = Color.from_rgb(255, 0, 0)
      color2 = Color.from_rgb(0, 0, 255)
      mixed = Color.mix(color1, color2)
      assert mixed.r == 127
      assert mixed.g == 0
      assert mixed.b == 127
    end

    test "mixes two colors with custom weight" do
      color1 = Color.from_rgb(255, 0, 0)
      color2 = Color.from_rgb(0, 0, 255)
      mixed = Color.mix(color1, color2, 0.25)
      assert mixed.r == 191
      assert mixed.g == 0
      assert mixed.b == 63
    end

    test "weight 0.0 returns first color" do
      color1 = Color.from_rgb(255, 0, 0)
      color2 = Color.from_rgb(0, 0, 255)
      mixed = Color.mix(color1, color2, 0.0)
      assert mixed.r == 255
      assert mixed.g == 0
      assert mixed.b == 0
    end

    test "weight 1.0 returns second color" do
      color1 = Color.from_rgb(255, 0, 0)
      color2 = Color.from_rgb(0, 0, 255)
      mixed = Color.mix(color1, color2, 1.0)
      assert mixed.r == 0
      assert mixed.g == 0
      assert mixed.b == 255
    end
  end
end 