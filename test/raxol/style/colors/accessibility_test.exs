defmodule Raxol.Style.Colors.AccessibilityTest do
  use ExUnit.Case, async: true

  alias Raxol.Style.Colors.Accessibility
  alias Raxol.Style.Colors.Color

  describe "contrast checking" do
    test "check_contrast identifies sufficient contrast (AA)" do
      # Black on White
      assert {:ok, ratio} = Accessibility.check_contrast("#000000", "#FFFFFF")
      assert ratio >= 4.5

      # White on Black
      assert {:ok, ratio} = Accessibility.check_contrast("#FFFFFF", "#000000")
      assert ratio >= 4.5
    end

    test "check_contrast identifies insufficient contrast (AA)" do
      # Gray on Gray
      assert {:error, {:contrast_too_low, ratio, _}} =
               Accessibility.check_contrast("#777777", "#999999")

      assert ratio < 4.5
    end

    test "check_contrast respects WCAG level parameter" do
      # Black/White passes AAA
      assert {:ok, _} = Accessibility.check_contrast("#000000", "#FFFFFF", :aaa)

      # Mid-gray fails AAA but passes AA
      assert {:error, _} =
               Accessibility.check_contrast("#767676", "#FFFFFF", :aaa)

      assert {:ok, _} = Accessibility.check_contrast("#767676", "#FFFFFF", :aa)
    end

    test "check_contrast respects text size parameter" do
      # Colors that fail AA normal but pass AA large
      fg = "#949494"
      bg = "#FFFFFF"
      assert {:error, _} = Accessibility.check_contrast(fg, bg, :aa, :normal)
      assert {:ok, _} = Accessibility.check_contrast(fg, bg, :aa, :large)
    end
  end

  describe "color suggestions" do
    test "suggest_accessible_color returns original color if already accessible" do
      color = "#000000"
      # Black on white is accessible
      assert ^color = Accessibility.suggest_accessible_color(color, "#FFFFFF")
    end

    test "suggest_accessible_color suggests darker color for light backgrounds" do
      # Light gray
      original = "#AAAAAA"
      suggested = Accessibility.suggest_accessible_color(original, "#FFFFFF")
      # Expect a darker color or fallback to black
      original_lum = Accessibility.relative_luminance(original)
      suggested_lum = Accessibility.relative_luminance(suggested)

      assert suggested_lum < original_lum or suggested == "#000000"
      # Ensure suggested color has sufficient contrast
      assert {:ok, _} = Accessibility.check_contrast(suggested, "#FFFFFF")
    end

    test "suggest_accessible_color suggests lighter color for dark backgrounds" do
      # Dark gray, changed from #777777
      original = "#222222"
      suggested = Accessibility.suggest_accessible_color(original, "#000000")
      # Expect a lighter color or fallback to white
      original_lum = Accessibility.relative_luminance(original)
      suggested_lum = Accessibility.relative_luminance(suggested)

      assert suggested_lum > original_lum or suggested == "#FFFFFF"
      # Ensure suggested color has sufficient contrast
      assert {:ok, _} = Accessibility.check_contrast(suggested, "#000000")
    end
  end

  describe "palette generation" do
    test "generate_accessible_palette creates a complete palette" do
      palette = Accessibility.generate_accessible_palette("#0077CC", "#FFFFFF")
      assert Map.has_key?(palette, :primary)
      assert Map.has_key?(palette, :secondary)
      assert Map.has_key?(palette, :accent)
      # ... check other required keys
    end

    test "generate_accessible_palette ensures all colors are accessible" do
      palette = Accessibility.generate_accessible_palette("#0077CC", "#FFFFFF")
      background = palette.background

      for {name, color} <- palette do
        unless name == :background do
          assert {:ok, _} = Accessibility.check_contrast(color, background)
        end
      end
    end

    test "generate_accessible_palette adapts to dark backgrounds" do
      palette = Accessibility.generate_accessible_palette("#0077CC", "#000000")
      background = palette.background

      for {name, color} <- palette do
        unless name == :background do
          assert {:ok, _} = Accessibility.check_contrast(color, background)
        end
      end

      # Text color should be light
      text_lum = Accessibility.relative_luminance(palette.text)
      assert text_lum > 0.5
    end
  end

  describe "color validation" do
    test "validate_colors returns ok for accessible combinations" do
      colors = %{
        text: "#000000",
        # Accessible link color on white
        link: "#0066CC"
      }

      assert {:ok, ^colors} = Accessibility.validate_colors(colors, "#FFFFFF")
    end

    test "validate_colors returns error for inaccessible combinations" do
      colors = %{
        # Low contrast text on white
        text: "#777777",
        # Low contrast link on white
        link: "#999999"
      }

      assert {:error, issues} = Accessibility.validate_colors(colors, "#FFFFFF")
      assert length(issues) == 2
      assert Keyword.has_key?(issues, :text)
      assert Keyword.has_key?(issues, :link)
    end
  end

  describe "palette adjustment" do
    test "adjust_palette makes all colors accessible" do
      colors = %{
        text: "#777777",
        link: "#999999",
        background: "#FFFFFF"
      }

      adjusted = Accessibility.adjust_palette(colors, "#FFFFFF")

      # Validate adjusted colors
      assert {:ok, _} =
               Accessibility.validate_colors(
                 Map.drop(adjusted, [:background]),
                 Map.get(adjusted, :background)
               )

      # Check that colors were actually changed
      refute Map.get(adjusted, :text) == Map.get(colors, :text)
      refute Map.get(adjusted, :link) == Map.get(colors, :link)
    end
  end

  describe "text suitability" do
    test "is_suitable_for_text? returns true for accessible combinations" do
      assert Accessibility.is_suitable_for_text?("#000000", "#FFFFFF")
      assert Accessibility.is_suitable_for_text?("#FFFFFF", "#000000")
    end

    test "is_suitable_for_text? returns false for inaccessible combinations" do
      refute Accessibility.is_suitable_for_text?("#777777", "#FFFFFF")
    end
  end

  describe "optimal text color" do
    test "get_optimal_text_color returns black for light backgrounds" do
      assert "#000000" == Accessibility.get_optimal_text_color("#FFFFFF")
      assert "#000000" == Accessibility.get_optimal_text_color("#CCCCCC")
    end

    test "get_optimal_text_color returns white for dark backgrounds" do
      assert "#FFFFFF" == Accessibility.get_optimal_text_color("#000000")
      assert "#FFFFFF" == Accessibility.get_optimal_text_color("#333333")
    end
  end
end
