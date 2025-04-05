defmodule Raxol.Style.Colors.AccessibilityTest do
  use ExUnit.Case
  alias Raxol.Style.Colors.Accessibility

  describe "contrast checking" do
    test "check_contrast returns ok for high contrast combinations" do
      assert {:ok, ratio} = Accessibility.check_contrast("#000000", "#FFFFFF")
      assert ratio > 20.0
    end

    test "check_contrast returns insufficient for low contrast combinations" do
      assert {:insufficient, ratio} = Accessibility.check_contrast("#777777", "#999999")
      assert ratio < 4.5
    end

    test "check_contrast respects WCAG level parameter" do
      # This combination passes AA but fails AAA
      assert {:ok, _} = Accessibility.check_contrast("#000000", "#FFFFFF", :aa)
      assert {:insufficient, _} = Accessibility.check_contrast("#777777", "#999999", :aaa)
    end

    test "check_contrast respects text size parameter" do
      # This combination passes for large text but fails for normal text
      assert {:insufficient, _} = Accessibility.check_contrast("#777777", "#999999", :aa, :normal)
      assert {:ok, _} = Accessibility.check_contrast("#777777", "#999999", :aa, :large)
    end
  end

  describe "color suggestions" do
    test "suggest_accessible_color returns original color if already accessible" do
      color = "#000000"
      assert ^color = Accessibility.suggest_accessible_color(color, "#FFFFFF")
    end

    test "suggest_accessible_color suggests darker color for light backgrounds" do
      original = "#777777"
      suggested = Accessibility.suggest_accessible_color(original, "#FFFFFF")
      assert suggested != original
      assert {:ok, _} = Accessibility.check_contrast(suggested, "#FFFFFF")
    end

    test "suggest_accessible_color suggests lighter color for dark backgrounds" do
      original = "#777777"
      suggested = Accessibility.suggest_accessible_color(original, "#000000")
      assert suggested != original
      assert {:ok, _} = Accessibility.check_contrast(suggested, "#000000")
    end
  end

  describe "palette generation" do
    test "generate_accessible_palette creates a complete palette" do
      palette = Accessibility.generate_accessible_palette("#0077CC", "#FFFFFF")
      assert Map.has_key?(palette, :primary)
      assert Map.has_key?(palette, :secondary)
      assert Map.has_key?(palette, :accent)
      assert Map.has_key?(palette, :text)
    end

    test "generate_accessible_palette ensures all colors are accessible" do
      palette = Accessibility.generate_accessible_palette("#0077CC", "#FFFFFF")
      Enum.each(palette, fn {_name, color} ->
        assert {:ok, _} = Accessibility.check_contrast(color, "#FFFFFF")
      end)
    end

    test "generate_accessible_palette adapts to dark backgrounds" do
      palette = Accessibility.generate_accessible_palette("#0077CC", "#000000")
      Enum.each(palette, fn {_name, color} ->
        assert {:ok, _} = Accessibility.check_contrast(color, "#000000")
      end)
    end
  end

  describe "color validation" do
    test "validate_colors returns ok for accessible combinations" do
      colors = %{
        text: "#000000",
        link: "#0066CC"
      }
      assert {:ok, ^colors} = Accessibility.validate_colors(colors, "#FFFFFF")
    end

    test "validate_colors returns error for inaccessible combinations" do
      colors = %{
        text: "#777777",
        link: "#999999"
      }
      assert {:error, issues} = Accessibility.validate_colors(colors, "#FFFFFF")
      assert length(issues) == 2
    end
  end

  describe "palette adjustment" do
    test "adjust_palette makes all colors accessible" do
      colors = %{
        text: "#777777",
        link: "#999999"
      }
      adjusted = Accessibility.adjust_palette(colors, "#FFFFFF")
      assert adjusted.text != colors.text
      assert adjusted.link != colors.link
      assert {:ok, _} = Accessibility.check_contrast(adjusted.text, "#FFFFFF")
      assert {:ok, _} = Accessibility.check_contrast(adjusted.link, "#FFFFFF")
    end
  end

  describe "text suitability" do
    test "is_suitable_for_text? returns true for accessible combinations" do
      assert Accessibility.is_suitable_for_text?("#000000", "#FFFFFF")
    end

    test "is_suitable_for_text? returns false for inaccessible combinations" do
      refute Accessibility.is_suitable_for_text?("#777777", "#999999")
    end
  end

  describe "optimal text color" do
    test "get_optimal_text_color returns black for light backgrounds" do
      assert "#000000" == Accessibility.get_optimal_text_color("#FFFFFF")
    end

    test "get_optimal_text_color returns white for dark backgrounds" do
      assert "#FFFFFF" == Accessibility.get_optimal_text_color("#000000")
    end

    test "get_optimal_text_color handles mid-tone backgrounds" do
      color = Accessibility.get_optimal_text_color("#808080")
      assert {:ok, _} = Accessibility.check_contrast(color, "#808080")
    end
  end
end 