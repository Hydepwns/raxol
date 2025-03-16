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
end 