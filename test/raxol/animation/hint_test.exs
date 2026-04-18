defmodule Raxol.Animation.HintTest do
  use ExUnit.Case, async: true

  alias Raxol.Animation.Hint

  describe "struct defaults" do
    test "creates hint with required fields and defaults" do
      hint = %Hint{property: :opacity, to: 1.0}

      assert hint.property == :opacity
      assert hint.to == 1.0
      assert hint.from == nil
      assert hint.duration_ms == 300
      assert hint.easing == :ease_out_cubic
      assert hint.delay_ms == 0
    end

    test "all fields can be overridden" do
      hint = %Hint{
        property: :color,
        from: :red,
        to: :blue,
        duration_ms: 500,
        easing: :ease_in_out_cubic,
        delay_ms: 100
      }

      assert hint.property == :color
      assert hint.from == :red
      assert hint.to == :blue
      assert hint.duration_ms == 500
      assert hint.easing == :ease_in_out_cubic
      assert hint.delay_ms == 100
    end
  end

  describe "to_css_property/1" do
    test "maps standard properties" do
      assert Hint.to_css_property(:opacity) == "opacity"
      assert Hint.to_css_property(:color) == "color"
      assert Hint.to_css_property(:fg) == "color"
      assert Hint.to_css_property(:bg_color) == "background-color"
      assert Hint.to_css_property(:bg) == "background-color"
      assert Hint.to_css_property(:width) == "width"
      assert Hint.to_css_property(:height) == "height"
      assert Hint.to_css_property(:transform) == "transform"
    end

    test "returns nil for unknown properties" do
      assert Hint.to_css_property(:custom_thing) == nil
      assert Hint.to_css_property(:border_radius) == nil
    end
  end

  describe "to_css_timing/1" do
    test "linear" do
      assert Hint.to_css_timing(:linear) == "linear"
    end

    test "cubic-bezier easings return valid cubic-bezier strings" do
      cubic_easings = [
        :ease_in_quad,
        :ease_out_quad,
        :ease_in_out_quad,
        :ease_in_cubic,
        :ease_out_cubic,
        :ease_in_out_cubic,
        :ease_in_quart,
        :ease_out_quart,
        :ease_in_out_quart,
        :ease_in_quint,
        :ease_out_quint,
        :ease_in_out_quint,
        :ease_in_sine,
        :ease_out_sine,
        :ease_in_out_sine,
        :ease_in_expo,
        :ease_out_expo,
        :ease_in_out_expo,
        :ease_in_circ,
        :ease_out_circ,
        :ease_in_out_circ,
        :ease_in_back,
        :ease_out_back,
        :ease_in_out_back
      ]

      for easing <- cubic_easings do
        result = Hint.to_css_timing(easing)
        assert String.starts_with?(result, "cubic-bezier("), "#{easing} should produce cubic-bezier"
        assert String.ends_with?(result, ")"), "#{easing} should end with )"
      end
    end

    test "aliases map to their base easing" do
      assert Hint.to_css_timing(:ease_in) == Hint.to_css_timing(:ease_in_quad)
      assert Hint.to_css_timing(:ease_out) == Hint.to_css_timing(:ease_out_quad)
      assert Hint.to_css_timing(:ease_in_out) == Hint.to_css_timing(:ease_in_out_quad)
    end

    test "bounce and elastic fall back to linear" do
      bounce_elastic = [
        :ease_in_bounce,
        :ease_out_bounce,
        :ease_in_out_bounce,
        :ease_in_elastic,
        :ease_out_elastic,
        :ease_in_out_elastic
      ]

      for easing <- bounce_elastic do
        assert Hint.to_css_timing(easing) == "linear",
               "#{easing} should fall back to linear"
      end
    end

    test "unknown easings fall back to linear" do
      assert Hint.to_css_timing(:nonexistent) == "linear"
    end
  end
end
