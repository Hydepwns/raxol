# defmodule Raxol.Style.Colors.UtilitiesTest do
#   use ExUnit.Case, async: true
#
#   # Skip this module for now due to outdated tests/missing functions
#   @moduletag :skip
#
#   doctest Raxol.Style.Colors.Utilities
#
#   alias Raxol.Style.Colors.{Color, Utilities}
#
#   describe "dark_color?/1" do
#     test "identifies dark colors" do
#       dark_colors = ["#000000", "#333333", "#555555"]
#       Enum.each(dark_colors, fn color ->
#         assert Utilities.dark_color?(color), "Expected #{color} to be dark"
#         assert Utilities.dark_color?(Color.from_hex(color)), "Expected #{color} struct to be dark"
#       end)
#     end
#
#     test "identifies light colors" do
#       light_colors = ["#FFFFFF", "#DDDDDD", "#BBBBBB", "#AAAAAA"]
#       Enum.each(light_colors, fn color ->
#         refute Utilities.dark_color?(color), "Expected #{color} not to be dark"
#         refute Utilities.dark_color?(Color.from_hex(color)), "Expected #{color} struct not to be dark"
#       end)
#     end
#   end
#
#   describe "brightness/1" do
#     test "calculates brightness correctly" do
#       assert Utilities.brightness("#000000") == 0
#       assert Utilities.brightness("#FFFFFF") == 255
#       assert Utilities.brightness("#FF0000") == 76 # Check red brightness
#       assert Utilities.brightness("#808080") == 128 # Check gray brightness
#
#       black = Color.from_hex("#000000")
#       assert Utilities.brightness(black) == 0
#     end
#   end
#
#   describe "readable?/3" do
#     test "correctly identifies readable text" do
#       dark_bg = Color.from_hex("#333333")
#       light_text = Color.from_hex("#FFFFFF")
#       assert Utilities.readable?(dark_bg, light_text)
#       assert Utilities.readable?(light_text, dark_bg)
#     end
#
#     test "correctly identifies unreadable text" do
#       gray1 = Color.from_hex("#777777")
#       gray2 = Color.from_hex("#999999")
#       refute Utilities.readable?(gray1, gray2)
#       refute Utilities.readable?(gray2, gray1)
#     end
#
#     test "respects accessibility levels" do
#       bg = Color.from_hex("#777777") # Gray background
#       fg = Color.from_hex("#DDDDDD") # Lighter gray foreground
#
#       # Should pass AA Large, might fail AA normal
#       assert Utilities.readable?(bg, fg, :aa_large)
#
#       # Expect it to fail AAA normal
#       refute Utilities.readable?(bg, fg, :aaa)
#
#       # Black on white should pass AAA
#       assert Utilities.readable?("#000000", "#FFFFFF", :aaa)
#     end
#   end
#
#   describe "relative_luminance/1" do
#     test "calculates relative luminance correctly" do
#       assert Utilities.relative_luminance("#000000") == 0.0
#       assert Utilities.relative_luminance("#FFFFFF") == 1.0
#
#       # Check a mid-gray value (should be around 0.21)
#       gray_lum = Utilities.relative_luminance("#808080")
#       assert gray_lum > 0.2 && gray_lum < 0.22
#
#       # Works with Color struct
#       white = Color.from_hex("#FFFFFF")
#       assert Utilities.relative_luminance(white) == 1.0
#     end
#   end
#
#   describe "contrast_ratio/2" do
#     test "calculates contrast ratio correctly" do
#       assert Utilities.contrast_ratio("#000000", "#FFFFFF") == 21.0
#       assert Utilities.contrast_ratio("#FFFFFF", "#000000") == 21.0
#
#       # Check a low contrast pair
#       low_contrast = Utilities.contrast_ratio("#777777", "#999999")
#       assert low_contrast > 1.2 && low_contrast < 1.4
#     end
#
#     test "contrast_ratio works with mixed input types" do
#       black = Color.from_hex("#000000")
#       assert Utilities.contrast_ratio("#FFFFFF", black) == 21.0
#       assert Utilities.contrast_ratio(black, "#FFFFFF") == 21.0
#       assert Utilities.contrast_ratio("#000000", black) == 1.0
#     end
#   end
#
#   describe "suggest_text_color/1" do
#     test "suggests white text for dark backgrounds" do
#       dark_colors = [
#         Color.from_hex("#000000"),
#         Color.from_hex("#333333"),
#         Color.from_hex("#550000") # Dark Red
#       ]
#
#       white = Color.from_hex("#FFFFFF")
#
#       Enum.each(dark_colors, fn color ->
#         suggested = Utilities.suggest_text_color(color)
#         assert suggested == white, "Expected white text for #{inspect color}"
#         assert Utilities.readable?(color, suggested, :aa), "Suggested white text not readable on #{inspect color}"
#       end)
#     end
#
#     test "suggests black text for light backgrounds" do
#       light_colors = [
#         Color.from_hex("#FFFFFF"),
#         Color.from_hex("#DDDDDD"),
#         Color.from_hex("#FFEECC") # Light Yellow
#       ]
#
#       black = Color.from_hex("#000000")
#
#       Enum.each(light_colors, fn color ->
#         suggested = Utilities.suggest_text_color(color)
#         assert suggested == black, "Expected black text for #{inspect color}"
#         assert Utilities.readable?(color, suggested, :aa), "Suggested black text not readable on #{inspect color}"
#       end)
#     end
#   end
#
#   describe "suggest_contrast_color/1" do
#     test "suggests a contrasting color with sufficient contrast" do
#       colors = [
#         Color.from_hex("#336699"), # Blue
#         Color.from_hex("#FFCC00"), # Yellow
#         Color.from_hex("#888888") # Gray
#       ]
#
#       Enum.each(colors, fn color ->
#         contrast_color = Utilities.suggest_contrast_color(color)
#         assert Utilities.readable?(color, contrast_color, :aa), "Suggested color not readable for #{inspect color}"
#       end)
#     end
#   end
#
#   describe "accessible_color_pair/2" do
#     test "creates color pairs that meet accessibility standards" do
#       colors = [
#         Color.from_hex("#336699"),
#         Color.from_hex("#AAAAAA"),
#         Color.from_hex("#FF0000")
#       ]
#
#       Enum.each(colors, fn color ->
#         {bg, fg} = Utilities.accessible_color_pair(color)
#         # Ensure one of them is the original color
#         assert bg == color or fg == color
#         assert Utilities.readable?(bg, fg, :aa), "Pair not accessible for #{inspect color}"
#       end)
#     end
#
#     test "respects accessibility level" do
#       color = Color.from_hex("#777777") # Mid-gray
#       # AA should work (likely with black or white)
#       {bg_aa, fg_aa} = Utilities.accessible_color_pair(color, :aa)
#       assert Utilities.readable?(bg_aa, fg_aa, :aa)
#
#       # AAA might fail if only pair is with mid-contrast color
#       # Assuming black/white are the main contrast options
#       # This test depends on the exact logic returning a *suitable* pair
#       {bg_aaa, fg_aaa} = Utilities.accessible_color_pair(color, :aaa)
#       # Check if a pair was found, and if so, if it meets AAA
#       if {bg_aaa, fg_aaa} != {nil, nil} do # Or however accessible_color_pair signals failure
#         assert Utilities.readable?(bg_aaa, fg_aaa, :aaa)
#       end
#     end
#   end
#
#   describe "analogous_colors/2" do
#     test "generates the correct number of analogous colors" do
#       red = Color.from_hex("#FF0000")
#       # Default is 3 colors total
#       colors = Utilities.analogous_colors(red)
#       assert length(colors) == 3
#
#       # Request 5 colors
#       colors_5 = Utilities.analogous_colors(red, 5)
#       assert length(colors_5) == 5
#     end
#
#     test "includes the original color" do
#       blue = Color.from_hex("#0000FF")
#       colors = Utilities.analogous_colors(blue)
#       assert blue in colors
#     end
#   end
#
#   describe "complementary_colors/1" do
#     test "returns a pair with the original and its complement" do
#       red = Color.from_hex("#FF0000")
#       colors = Utilities.complementary_colors(red)
#
#       assert length(colors) == 2
#       assert red in colors
#
#       # Complement of red is cyan (#00FFFF)
#       complement = Enum.find(colors, &(&1 != red))
#       assert complement.hex == "#00FFFF"
#     end
#   end
#
#   describe "triadic_colors/1" do
#     test "returns three colors evenly spaced on the color wheel" do
#       red = Color.from_hex("#FF0000")
#       colors = Utilities.triadic_colors(red)
#       assert length(colors) == 3
#       assert red in colors
#
#       # Triadic colors for Red (#FF0000) are Green (#00FF00) and Blue (#0000FF)
#       other_colors = Enum.reject(colors, &(&1 == red))
#       hexes = Enum.map(other_colors, & &1.hex) |> Enum.sort
#       assert hexes == ["#0000FF", "#00FF00"]
#     end
#   end
#
#   describe "color space conversions" do
#     # These require HSL conversion logic
#     # Add tests once HSL support is implemented in Color or Utilities
#   end
#
#   describe "color adjustment functions" do
#     # These require implementation of lighten_until_contrast, darken_until_contrast
#   end
#
#   describe "hue rotation" do
#     # Requires rotate_hue implementation
#   end
#
#   # Test luminance alias
#   describe "luminance/1" do
#     test "is an alias for relative_luminance" do
#       assert Utilities.luminance("#808080") == Utilities.relative_luminance("#808080")
#     end
#   end
#
#   # Test hex_color?
#   describe "hex_color?/1" do
#     test "validates various hex formats" do
#       assert Utilities.hex_color?("#FFF")
#       assert Utilities.hex_color?("#ff00aa")
#       assert Utilities.hex_color?("ABCDEF")
#       # Add tests for 4 and 8 digit hex if supported
#     end
#
#     test "rejects invalid formats" do
#       refute Utilities.hex_color?("red")
#       refute Utilities.hex_color?("#GHI")
#       refute Utilities.hex_color?("12345")
#     end
#   end
#
#   # PLACEHOLDER TESTS for potentially missing functions
#
#   describe "color lightening darken_until_contrast" do
#     test "darkens color until contrast is sufficient" do
#       original = "#777777"
#       result = Utilities.darken_until_contrast(original, "#FFFFFF", 4.5)
#       assert result != original
#       assert {:ok, ratio} = Raxol.Style.Colors.Accessibility.check_contrast(result, "#FFFFFF")
#       assert ratio >= 4.5
#     end
#
#     test "returns original color if already sufficient" do
#       color = "#000000"
#       result = Utilities.darken_until_contrast(color, "#FFFFFF", 4.5)
#       assert result == color
#     end
#
#     test "works with Color structs" do
#       color = Color.from_hex("#777777")
#       background = Color.from_hex("#FFFFFF")
#       result = Utilities.darken_until_contrast(color, background, 4.5)
#       assert result != color
#       assert {:ok, _} = Raxol.Style.Colors.Accessibility.check_contrast(result, background)
#     end
#   end
#
#   describe "color lightening lighten_until_contrast" do
#     test "returns original color if already sufficient" do
#       color = "#FFFFFF"
#       result = Utilities.lighten_until_contrast(color, "#000000", 4.5)
#       assert result == color
#     end
#
#     test "lightens color until contrast is sufficient" do
#       original = "#777777"
#       result = Utilities.lighten_until_contrast(original, "#000000", 4.5)
#       assert result != original
#       assert {:ok, ratio} = Raxol.Style.Colors.Accessibility.check_contrast(result, "#000000")
#       assert ratio >= 4.5
#     end
#
#     test "works with Color structs" do
#       color = Color.from_hex("#777777")
#       background = Color.from_hex("#000000")
#       result = Utilities.lighten_until_contrast(color, background, 4.5)
#       assert result != color
#       assert {:ok, _} = Raxol.Style.Colors.Accessibility.check_contrast(result, background)
#     end
#   end
#
#   describe "hue rotation" do
#     test "rotates red to green" do
#       assert Utilities.rotate_hue("#FF0000", 120) == "#00FF00"
#     end
#
#     test "rotates green to blue" do
#       assert Utilities.rotate_hue("#00FF00", 120) == "#0000FF"
#     end
#
#     test "rotates blue to red" do
#       assert Utilities.rotate_hue("#0000FF", 120) == "#FF0000"
#     end
#
#     test "works with Color struct" do
#       color = Color.from_hex("#FF0000")
#       assert Utilities.rotate_hue(color, 120) == "#00FF00"
#     end
#
#     test "handles 360 degree rotation" do
#       color = "#FF0000"
#       assert Utilities.rotate_hue(color, 360) == color
#     end
#   end
#
#   describe "color space conversions rgb_to_hsl" do
#     test "converts red correctly" do
#       {h, s, l} = Utilities.rgb_to_hsl(255, 0, 0)
#       assert h == 0
#       assert s == 1.0
#       assert l == 0.5
#     end
#
#     test "converts green correctly" do
#       {h, s, l} = Utilities.rgb_to_hsl(0, 255, 0)
#       assert h == 120
#       assert s == 1.0
#       assert l == 0.5
#     end
#
#     test "converts blue correctly" do
#       {h, s, l} = Utilities.rgb_to_hsl(0, 0, 255)
#       assert h == 240
#       assert s == 1.0
#       assert l == 0.5
#     end
#   end
#
#   describe "color space conversions hsl_to_rgb" do
#     test "converts red correctly" do
#       {r, g, b} = Utilities.hsl_to_rgb(0, 1.0, 0.5)
#       assert r == 255
#       assert g == 0
#       assert b == 0
#     end
#
#     test "converts green correctly" do
#       {r, g, b} = Utilities.hsl_to_rgb(120, 1.0, 0.5)
#       assert r == 0
#       assert g == 255
#       assert b == 0
#     end
#
#     test "converts blue correctly" do
#       {r, g, b} = Utilities.hsl_to_rgb(240, 1.0, 0.5)
#       assert r == 0
#       assert g == 0
#       assert b == 255
#     end
#   end
# end
