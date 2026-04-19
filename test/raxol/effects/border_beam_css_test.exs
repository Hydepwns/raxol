defmodule Raxol.Effects.BorderBeam.CSSTest do
  use ExUnit.Case, async: true

  alias Raxol.Effects.BorderBeam.CSS

  @default_config %{
    size: :full,
    color_variant: :colorful,
    strength: 0.8,
    duration_ms: 2000,
    brightness: 1.3,
    saturation: 1.2,
    hue_range: 30,
    static_colors: false,
    active: true
  }

  describe "to_css/2" do
    test "generates CSS with @property declaration" do
      css = CSS.to_css(@default_config, "test-panel")
      assert css =~ "@property --bb-angle-test-panel"
      assert css =~ "syntax: \"<angle>\""
    end

    test "generates spin keyframes" do
      css = CSS.to_css(@default_config, "panel")
      assert css =~ "@keyframes bb-spin-panel"
      assert css =~ "360deg"
    end

    test "generates beam stroke with conic-gradient and mask" do
      css = CSS.to_css(@default_config, "card")
      assert css =~ "conic-gradient"
      assert css =~ "mask-composite: exclude"
      assert css =~ "[data-raxol-id=\"card\"]::after"
    end

    test "generates inner glow with blur" do
      css = CSS.to_css(@default_config, "card")
      assert css =~ "[data-raxol-id=\"card\"]::before"
      assert css =~ "blur(4px)"
    end

    test "generates bloom layer" do
      css = CSS.to_css(@default_config, "card")
      assert css =~ "[data-beam-bloom]"
      assert css =~ "blur(8px)"
    end

    test "includes prefers-reduced-motion" do
      css = CSS.to_css(@default_config, "card")
      assert css =~ "@media (prefers-reduced-motion: reduce)"
      assert css =~ "animation-duration: 0.01ms"
    end

    test "duration maps from ms to seconds" do
      css = CSS.to_css(%{@default_config | duration_ms: 3000}, "fast")
      assert css =~ "3.0s linear infinite"
    end

    test "compact size skips bloom and inner glow" do
      css = CSS.to_css(%{@default_config | size: :compact}, "compact")
      refute css =~ "[data-beam-bloom]"
      refute css =~ "::before"
    end

    test "line size uses linear-gradient" do
      css = CSS.to_css(%{@default_config | size: :line}, "line")
      assert css =~ "linear-gradient(90deg"
      refute css =~ "[data-beam-bloom]"
    end

    test "inactive sets opacity to 0" do
      css = CSS.to_css(%{@default_config | active: false}, "inactive")
      assert css =~ "opacity: 0"
    end

    test "static_colors skips hue keyframes" do
      css = CSS.to_css(%{@default_config | static_colors: true}, "static")
      refute css =~ "bb-hue-static"
    end

    test "non-static generates hue keyframes" do
      css = CSS.to_css(@default_config, "animated")
      assert css =~ "bb-hue-animated"
      assert css =~ "hue-rotate(30deg)"
    end

    test "each variant produces different gradient colors" do
      css_colorful =
        CSS.to_css(%{@default_config | color_variant: :colorful}, "a")

      css_ocean = CSS.to_css(%{@default_config | color_variant: :ocean}, "b")
      css_sunset = CSS.to_css(%{@default_config | color_variant: :sunset}, "c")

      # Different hex colors in gradients
      refute css_colorful == css_ocean
      refute css_ocean == css_sunset
    end
  end

  describe "to_hint/1" do
    test "returns border_beam hint map" do
      hint = CSS.to_hint(@default_config)
      assert hint.type == :border_beam
      assert hint.variant == :colorful
      assert hint.strength == 0.8
      assert hint.duration_ms == 2000
    end
  end
end
