defmodule Raxol.Core.StyleTest do
  use ExUnit.Case, async: true

  alias Raxol.Core.Style

  describe "new/1" do
    test "creates style with default values" do
      style = Style.new()
      assert style.bold == false
      assert style.italic == false
      assert style.fg_color == nil
    end

    test "creates style with specified attributes" do
      style = Style.new(bold: true, fg_color: :red)
      assert style.bold == true
      assert style.fg_color == :red
    end

    test "accepts RGB color values" do
      style = Style.new(fg_color: {255, 0, 0})
      assert style.fg_color == {255, 0, 0}
    end

    test "accepts all style attributes" do
      style =
        Style.new(
          fg_color: :red,
          bg_color: :blue,
          bold: true,
          italic: true,
          underline: true,
          reverse: true,
          strikethrough: true
        )

      assert style.fg_color == :red
      assert style.bg_color == :blue
      assert style.bold == true
      assert style.italic == true
      assert style.underline == true
      assert style.reverse == true
      assert style.strikethrough == true
    end
  end

  describe "merge/2" do
    test "merges two styles with second taking precedence" do
      style1 = Style.new(bold: true, fg_color: :red)
      style2 = Style.new(fg_color: :blue, italic: true)

      merged = Style.merge(style1, style2)

      assert merged.bold == true
      assert merged.fg_color == :blue
      assert merged.italic == true
    end

    test "preserves attributes from first style when not overridden" do
      style1 = Style.new(bold: true, underline: true)
      style2 = Style.new(italic: true)

      merged = Style.merge(style1, style2)

      assert merged.bold == true
      assert merged.underline == true
      assert merged.italic == true
    end

    test "handles nil color values correctly" do
      style1 = Style.new(fg_color: :red)
      style2 = Style.new(italic: true)

      merged = Style.merge(style1, style2)

      assert merged.fg_color == :red
      assert merged.italic == true
    end
  end

  describe "rgb/3" do
    test "creates RGB color tuple" do
      color = Style.rgb(255, 128, 64)
      assert color == {255, 128, 64}
    end

    test "accepts valid RGB component range" do
      assert Style.rgb(0, 0, 0) == {0, 0, 0}
      assert Style.rgb(255, 255, 255) == {255, 255, 255}
      assert Style.rgb(128, 64, 32) == {128, 64, 32}
    end
  end

  describe "color_256/1" do
    test "returns color code" do
      color = Style.color_256(42)
      assert is_integer(color)
      assert color == 42
    end

    test "accepts valid color code range" do
      assert Style.color_256(0) == 0
      assert Style.color_256(255) == 255
      assert Style.color_256(128) == 128
    end
  end

  describe "named_color/1" do
    test "returns named color atoms" do
      assert Style.named_color(:red) == :red
      assert Style.named_color(:blue) == :blue
      assert Style.named_color(:bright_red) == :bright_red
    end

    test "supports all basic colors" do
      basic_colors = [
        :black,
        :red,
        :green,
        :yellow,
        :blue,
        :magenta,
        :cyan,
        :white
      ]

      for color <- basic_colors do
        assert Style.named_color(color) == color
      end
    end

    test "supports all bright colors" do
      bright_colors = [
        :bright_black,
        :bright_red,
        :bright_green,
        :bright_yellow,
        :bright_blue,
        :bright_magenta,
        :bright_cyan,
        :bright_white
      ]

      for color <- bright_colors do
        assert Style.named_color(color) == color
      end
    end
  end

  describe "to_ansi/1" do
    test "returns empty string for default style" do
      style = Style.new()
      ansi = Style.to_ansi(style)
      assert ansi == ""
    end

    test "generates ANSI codes for bold" do
      style = Style.new(bold: true)
      ansi = Style.to_ansi(style)
      assert ansi == "\e[1m"
    end

    test "generates ANSI codes for italic" do
      style = Style.new(italic: true)
      ansi = Style.to_ansi(style)
      assert ansi == "\e[3m"
    end

    test "generates ANSI codes for underline" do
      style = Style.new(underline: true)
      ansi = Style.to_ansi(style)
      assert ansi == "\e[4m"
    end

    test "generates ANSI codes for named foreground colors" do
      style = Style.new(fg_color: :red)
      ansi = Style.to_ansi(style)
      assert ansi == "\e[31m"
    end

    test "generates ANSI codes for bright colors" do
      style = Style.new(fg_color: :bright_red)
      ansi = Style.to_ansi(style)
      assert ansi == "\e[91m"
    end

    test "generates ANSI codes for background colors" do
      style = Style.new(bg_color: :blue)
      ansi = Style.to_ansi(style)
      assert ansi == "\e[44m"
    end

    test "generates RGB color codes" do
      style = Style.new(fg_color: {255, 128, 0})
      ansi = Style.to_ansi(style)
      assert ansi == "\e[38;2;255;128;0m"
    end

    test "generates 256-color codes" do
      style = Style.new(fg_color: 42)
      ansi = Style.to_ansi(style)
      assert ansi == "\e[38;5;42m"
    end

    test "combines multiple attributes" do
      style = Style.new(bold: true, italic: true, fg_color: :red)
      ansi = Style.to_ansi(style)
      assert String.contains?(ansi, "1")
      assert String.contains?(ansi, "3")
      assert String.contains?(ansi, "31")
    end

    test "handles foreground and background colors together" do
      style = Style.new(fg_color: :red, bg_color: :blue)
      ansi = Style.to_ansi(style)
      assert String.contains?(ansi, "31")
      assert String.contains?(ansi, "44")
    end

    test "handles all attributes together" do
      style =
        Style.new(
          bold: true,
          italic: true,
          underline: true,
          reverse: true,
          strikethrough: true,
          fg_color: :red,
          bg_color: :blue
        )

      ansi = Style.to_ansi(style)
      assert is_binary(ansi)
      assert String.starts_with?(ansi, "\e[")
      assert String.ends_with?(ansi, "m")
    end
  end
end
