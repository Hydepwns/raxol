defmodule Raxol.Core.Renderer.ColorTest do
  use ExUnit.Case, async: true
  alias Raxol.Core.Renderer.Color

  describe "to_ansi/1" do
    test "converts basic ANSI colors" do
      assert Color.to_ansi(:red) == "\e[31m"
      assert Color.to_ansi(:blue) == "\e[34m"
      assert Color.to_ansi(:bright_green) == "\e[92m"
    end

    test "converts RGB tuples to true color" do
      assert Color.to_ansi({255, 0, 0}) == "\e[38;2;255;0;0m"
      assert Color.to_ansi({0, 255, 0}) == "\e[38;2;0;255;0m"
      assert Color.to_ansi({0, 0, 255}) == "\e[38;2;0;0;255m"
    end

    test "converts hex colors" do
      assert Color.to_ansi("#FF0000") == "\e[38;2;255;0;0m"
      assert Color.to_ansi("#00FF00") == "\e[38;2;0;255;0m"
      assert Color.to_ansi("#0000FF") == "\e[38;2;0;0;255m"
    end
  end

  describe "to_bg_ansi/1" do
    test "converts basic ANSI colors for background" do
      assert Color.to_bg_ansi(:red) == "\e[41m"
      assert Color.to_bg_ansi(:blue) == "\e[44m"
      assert Color.to_bg_ansi(:bright_green) == "\e[102m"
    end

    test "converts RGB tuples to true color background" do
      assert Color.to_bg_ansi({255, 0, 0}) == "\e[48;2;255;0;0m"
      assert Color.to_bg_ansi({0, 255, 0}) == "\e[48;2;0;255;0m"
      assert Color.to_bg_ansi({0, 0, 255}) == "\e[48;2;0;0;255m"
    end

    test "converts hex colors for background" do
      assert Color.to_bg_ansi("#FF0000") == "\e[48;2;255;0;0m"
      assert Color.to_bg_ansi("#00FF00") == "\e[48;2;0;255;0m"
      assert Color.to_bg_ansi("#0000FF") == "\e[48;2;0;0;255m"
    end
  end

  describe "hex_to_rgb/1" do
    test "converts 6-digit hex colors" do
      assert Color.hex_to_rgb("#FF0000") == {255, 0, 0}
      assert Color.hex_to_rgb("#00FF00") == {0, 255, 0}
      assert Color.hex_to_rgb("#0000FF") == {0, 0, 255}
    end

    test "converts 3-digit hex colors" do
      assert Color.hex_to_rgb("#F00") == {255, 0, 0}
      assert Color.hex_to_rgb("#0F0") == {0, 255, 0}
      assert Color.hex_to_rgb("#00F") == {0, 0, 255}
    end

    test "handles lowercase hex colors" do
      assert Color.hex_to_rgb("#ff0000") == {255, 0, 0}
      assert Color.hex_to_rgb("#f00") == {255, 0, 0}
    end
  end

  describe "rgb_to_ansi256/1" do
    test "converts primary colors" do
      assert Color.rgb_to_ansi256({255, 0, 0}) == 196
      assert Color.rgb_to_ansi256({0, 255, 0}) == 46
      assert Color.rgb_to_ansi256({0, 0, 255}) == 21
    end

    test "converts grayscale colors" do
      assert Color.rgb_to_ansi256({128, 128, 128}) == 244
      assert Color.rgb_to_ansi256({255, 255, 255}) == 231
      assert Color.rgb_to_ansi256({0, 0, 0}) == 16
    end
  end

  describe "create_theme/1" do
    test "creates a theme with custom colors" do
      theme = Color.create_theme(%{
        primary: "#FF0000",
        secondary: {0, 255, 0},
        accent: :blue
      })

      assert theme.primary == {255, 0, 0}
      assert theme.secondary == {0, 255, 0}
      assert theme.accent == :blue
    end

    test "merges with default theme" do
      theme = Color.create_theme(%{primary: "#FF0000"})
      assert theme.primary == {255, 0, 0}
      assert Map.has_key?(theme, :background)
      assert Map.has_key?(theme, :foreground)
    end
  end

  describe "default_theme/0" do
    test "returns a complete theme map" do
      theme = Color.default_theme()
      
      assert is_map(theme)
      assert Map.has_key?(theme, :background)
      assert Map.has_key?(theme, :foreground)
      assert Map.has_key?(theme, :primary)
      assert Map.has_key?(theme, :secondary)
      assert Map.has_key?(theme, :accent)
      assert Map.has_key?(theme, :error)
      assert Map.has_key?(theme, :warning)
      assert Map.has_key?(theme, :success)
    end
  end

  describe "detect_background/0" do
    test "returns a valid background color" do
      background = Color.detect_background()
      assert is_tuple(background) or is_atom(background)
    end
  end
end 