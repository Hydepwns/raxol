defmodule Raxol.Style.Colors.UtilitiesTest do
  use ExUnit.Case
  doctest Raxol.Style.Colors.Utilities

  alias Raxol.Style.Colors.{Color, Utilities}

  describe "contrast_ratio/2" do
    test "calculates contrast ratio between colors" do
      black = Color.from_hex("#000000")
      white = Color.from_hex("#FFFFFF")
      
      # Black and white should have maximum contrast (21:1)
      ratio = Utilities.contrast_ratio(black, white)
      assert_in_delta ratio, 21.0, 0.1
      
      # Same colors should have minimum contrast (1:1)
      assert Utilities.contrast_ratio(black, black) == 1.0
      assert Utilities.contrast_ratio(white, white) == 1.0
      
      # Test with intermediate colors
      medium_gray = Color.from_hex("#888888")
      light_gray = Color.from_hex("#DDDDDD")
      
      ratio = Utilities.contrast_ratio(medium_gray, light_gray)
      assert ratio > 1.0 and ratio < 21.0
    end
    
    test "contrast ratio is commutative" do
      color1 = Color.from_hex("#336699")
      color2 = Color.from_hex("#FFCC00")
      
      ratio1 = Utilities.contrast_ratio(color1, color2)
      ratio2 = Utilities.contrast_ratio(color2, color1)
      
      assert_in_delta ratio1, ratio2, 0.0001
    end
  end
  
  describe "is_readable?/3" do
    test "correctly identifies readable text" do
      # Dark background, light text (should be readable)
      dark_bg = Color.from_hex("#333333")
      light_text = Color.from_hex("#FFFFFF")
      assert Utilities.is_readable?(dark_bg, light_text)
      
      # Light background, dark text (should be readable)
      light_bg = Color.from_hex("#FFFFFF")
      dark_text = Color.from_hex("#000000")
      assert Utilities.is_readable?(light_bg, dark_text)
      
      # Low contrast (should not be readable)
      light_gray = Color.from_hex("#CCCCCC")
      medium_gray = Color.from_hex("#999999")
      refute Utilities.is_readable?(light_gray, medium_gray)
    end
    
    test "respects accessibility levels" do
      bg = Color.from_hex("#777777")
      fg = Color.from_hex("#DDDDDD")
      
      # Test different accessibility levels
      assert Utilities.is_readable?(bg, fg, :aa_large)  # Lower requirement
      refute Utilities.is_readable?(bg, fg, :aaa)      # Higher requirement
    end
  end
  
  describe "brightness/1" do
    test "calculates perceived brightness" do
      # Black should have 0 brightness
      black = Color.from_hex("#000000")
      assert Utilities.brightness(black) == 0
      
      # White should have maximum brightness (255)
      white = Color.from_hex("#FFFFFF")
      assert Utilities.brightness(white) == 255
      
      # Pure colors have different perceived brightness
      red = Color.from_hex("#FF0000")
      green = Color.from_hex("#00FF00")
      blue = Color.from_hex("#0000FF")
      
      # Green appears brightest to the human eye
      assert Utilities.brightness(green) > Utilities.brightness(red)
      assert Utilities.brightness(red) > Utilities.brightness(blue)
    end
  end
  
  describe "luminance/1" do
    test "calculates relative luminance" do
      # Black should have 0 luminance
      black = Color.from_hex("#000000")
      assert Utilities.luminance(black) == 0.0
      
      # White should have maximum luminance (1.0)
      white = Color.from_hex("#FFFFFF")
      assert_in_delta Utilities.luminance(white), 1.0, 0.001
      
      # Mid-gray should have around 0.5 luminance
      gray = Color.from_hex("#808080")
      assert Utilities.luminance(gray) > 0.2 and Utilities.luminance(gray) < 0.3
    end
  end
  
  describe "suggest_text_color/1" do
    test "suggests white text for dark backgrounds" do
      dark_colors = [
        Color.from_hex("#000000"),  # Black
        Color.from_hex("#333333"),  # Dark gray
        Color.from_hex("#0000AA"),  # Dark blue
        Color.from_hex("#660066")   # Dark purple
      ]
      
      for color <- dark_colors do
        text_color = Utilities.suggest_text_color(color)
        assert text_color.hex == "#FFFFFF"  # White
      end
    end
    
    test "suggests black text for light backgrounds" do
      light_colors = [
        Color.from_hex("#FFFFFF"),  # White
        Color.from_hex("#EEEEEE"),  # Light gray
        Color.from_hex("#FFFF00"),  # Yellow
        Color.from_hex("#99FFCC")   # Light green-blue
      ]
      
      for color <- light_colors do
        text_color = Utilities.suggest_text_color(color)
        assert text_color.hex == "#000000"  # Black
      end
    end
  end
  
  describe "suggest_contrast_color/1" do
    test "suggests a contrasting color with sufficient contrast" do
      colors = [
        Color.from_hex("#336699"),  # Blue
        Color.from_hex("#993366"),  # Purple
        Color.from_hex("#999999")   # Gray
      ]
      
      for color <- colors do
        contrast = Utilities.suggest_contrast_color(color)
        ratio = Utilities.contrast_ratio(color, contrast)
        
        # Should meet WCAG AA standard (4.5:1 minimum)
        assert ratio >= 4.5
      end
    end
  end
  
  describe "accessible_color_pair/2" do
    test "creates color pairs that meet accessibility standards" do
      colors = [
        Color.from_hex("#336699"),  # Blue
        Color.from_hex("#993366"),  # Purple
        Color.from_hex("#999999")   # Gray
      ]
      
      for color <- colors do
        {bg, fg} = Utilities.accessible_color_pair(color)
        
        # The pair should be readable
        assert Utilities.is_readable?(bg, fg)
      end
    end
    
    test "respects accessibility level" do
      color = Color.from_hex("#777777")
      
      {bg, fg} = Utilities.accessible_color_pair(color, :aa)
      assert Utilities.is_readable?(bg, fg, :aa)
      
      {bg, fg} = Utilities.accessible_color_pair(color, :aaa)
      assert Utilities.is_readable?(bg, fg, :aaa)
    end
  end
  
  describe "analogous_colors/2" do
    test "generates the correct number of analogous colors" do
      red = Color.from_hex("#FF0000")
      
      # Default count is 3
      colors = Utilities.analogous_colors(red)
      assert length(colors) == 3
      
      # Custom count
      colors = Utilities.analogous_colors(red, 5)
      assert length(colors) == 5
    end
    
    test "includes the original color" do
      blue = Color.from_hex("#0000FF")
      colors = Utilities.analogous_colors(blue)
      
      # The middle color should be the original
      middle = Enum.at(colors, div(length(colors), 2))
      assert middle.hex == blue.hex
    end
  end
  
  describe "complementary_colors/1" do
    test "returns a pair with the original and its complement" do
      red = Color.from_hex("#FF0000")
      colors = Utilities.complementary_colors(red)
      
      assert length(colors) == 2
      assert Enum.at(colors, 0).hex == red.hex
      
      # Complement of red is cyan
      complement = Enum.at(colors, 1)
      assert complement.g > 200 and complement.b > 200
    end
  end
  
  describe "triadic_colors/1" do
    test "returns three colors evenly spaced on the color wheel" do
      red = Color.from_hex("#FF0000")
      colors = Utilities.triadic_colors(red)
      
      assert length(colors) == 3
      assert Enum.at(colors, 0).hex == red.hex
      
      # Red -> Green -> Blue (120° spacing)
      second = Enum.at(colors, 1)
      third = Enum.at(colors, 2)
      
      # Second color should be primarily green
      assert second.g > second.r and second.g > second.b
      
      # Third color should be primarily blue
      assert third.b > third.r and third.b > third.g
    end
  end

  describe "relative luminance" do
    test "relative_luminance returns 0 for black" do
      assert Utilities.relative_luminance("#000000") == 0.0
    end

    test "relative_luminance returns 1 for white" do
      assert Utilities.relative_luminance("#FFFFFF") == 1.0
    end

    test "relative_luminance returns correct value for gray" do
      assert Utilities.relative_luminance("#808080") == 0.21586050011389962
    end

    test "relative_luminance works with Color struct" do
      color = Color.from_hex("#FF0000")
      assert Utilities.relative_luminance(color) == 0.2126
    end
  end

  describe "contrast ratio" do
    test "contrast_ratio returns 21 for black on white" do
      assert Utilities.contrast_ratio("#000000", "#FFFFFF") == 21.0
    end

    test "contrast_ratio returns 1 for same color" do
      assert Utilities.contrast_ratio("#FF0000", "#FF0000") == 1.0
    end

    test "contrast_ratio works with Color structs" do
      black = Color.from_hex("#000000")
      white = Color.from_hex("#FFFFFF")
      assert Utilities.contrast_ratio(black, white) == 21.0
    end

    test "contrast_ratio works with mixed input types" do
      black = Color.from_hex("#000000")
      assert Utilities.contrast_ratio(black, "#FFFFFF") == 21.0
      assert Utilities.contrast_ratio("#000000", black) == 21.0
    end
  end

  describe "color darkness" do
    test "is_dark_color? returns true for dark colors" do
      assert Utilities.is_dark_color?("#000000")
      assert Utilities.is_dark_color?("#333333")
    end

    test "is_dark_color? returns false for light colors" do
      refute Utilities.is_dark_color?("#FFFFFF")
      refute Utilities.is_dark_color?("#CCCCCC")
    end

    test "is_dark_color? works with Color struct" do
      color = Color.from_hex("#000000")
      assert Utilities.is_dark_color?(color)
    end
  end

  describe "color darkening" do
    test "darken_until_contrast returns original color if already sufficient" do
      color = "#000000"
      assert ^color = Utilities.darken_until_contrast(color, "#FFFFFF", 4.5)
    end

    test "darken_until_contrast darkens color until contrast is sufficient" do
      original = "#777777"
      result = Utilities.darken_until_contrast(original, "#FFFFFF", 4.5)
      assert result != original
      assert {:ok, _} = Accessibility.check_contrast(result, "#FFFFFF")
    end

    test "darken_until_contrast works with Color structs" do
      color = Color.from_hex("#777777")
      background = Color.from_hex("#FFFFFF")
      result = Utilities.darken_until_contrast(color, background, 4.5)
      assert result != Color.to_hex(color)
      assert {:ok, _} = Accessibility.check_contrast(result, "#FFFFFF")
    end
  end

  describe "color lightening" do
    test "lighten_until_contrast returns original color if already sufficient" do
      color = "#FFFFFF"
      assert ^color = Utilities.lighten_until_contrast(color, "#000000", 4.5)
    end

    test "lighten_until_contrast lightens color until contrast is sufficient" do
      original = "#777777"
      result = Utilities.lighten_until_contrast(original, "#000000", 4.5)
      assert result != original
      assert {:ok, _} = Accessibility.check_contrast(result, "#000000")
    end

    test "lighten_until_contrast works with Color structs" do
      color = Color.from_hex("#777777")
      background = Color.from_hex("#000000")
      result = Utilities.lighten_until_contrast(color, background, 4.5)
      assert result != Color.to_hex(color)
      assert {:ok, _} = Accessibility.check_contrast(result, "#000000")
    end
  end

  describe "hue rotation" do
    test "rotate_hue rotates red to green" do
      assert Utilities.rotate_hue("#FF0000", 120) == "#00FF00"
    end

    test "rotate_hue rotates green to blue" do
      assert Utilities.rotate_hue("#00FF00", 120) == "#0000FF"
    end

    test "rotate_hue rotates blue to red" do
      assert Utilities.rotate_hue("#0000FF", 120) == "#FF0000"
    end

    test "rotate_hue works with Color struct" do
      color = Color.from_hex("#FF0000")
      assert Utilities.rotate_hue(color, 120) == "#00FF00"
    end

    test "rotate_hue handles 360 degree rotation" do
      color = "#FF0000"
      assert Utilities.rotate_hue(color, 360) == color
    end
  end

  describe "color space conversions" do
    test "rgb_to_hsl converts red correctly" do
      {h, s, l} = Utilities.rgb_to_hsl(255, 0, 0)
      assert h == 0
      assert s == 1.0
      assert l == 0.5
    end

    test "rgb_to_hsl converts green correctly" do
      {h, s, l} = Utilities.rgb_to_hsl(0, 255, 0)
      assert h == 120
      assert s == 1.0
      assert l == 0.5
    end

    test "rgb_to_hsl converts blue correctly" do
      {h, s, l} = Utilities.rgb_to_hsl(0, 0, 255)
      assert h == 240
      assert s == 1.0
      assert l == 0.5
    end

    test "hsl_to_rgb converts red correctly" do
      {r, g, b} = Utilities.hsl_to_rgb(0, 1.0, 0.5)
      assert r == 255
      assert g == 0
      assert b == 0
    end

    test "hsl_to_rgb converts green correctly" do
      {r, g, b} = Utilities.hsl_to_rgb(120, 1.0, 0.5)
      assert r == 0
      assert g == 255
      assert b == 0
    end

    test "hsl_to_rgb converts blue correctly" do
      {r, g, b} = Utilities.hsl_to_rgb(240, 1.0, 0.5)
      assert r == 0
      assert g == 0
      assert b == 255
    end
  end
end 