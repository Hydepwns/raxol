defmodule Raxol.Terminal.ANSI.TextFormattingTest do
  use ExUnit.Case
  doctest Raxol.Terminal.ANSI.TextFormatting

  alias Raxol.Terminal.ANSI.TextFormatting

  # Test new/0
  test ~c"new/0 creates a new text style with default values" do
    style = TextFormatting.new()
    # Check default boolean attributes
    assert style.bold == false
    assert style.italic == false
    assert style.underline == false
    assert style.blink == false
    assert style.reverse == false
    assert style.conceal == false
    assert style.strikethrough == false
    assert style.fraktur == false
    assert style.double_underline == false
    assert style.double_width == false
    assert style.double_height == :none
    # Check default colors
    assert style.foreground == nil
    assert style.background == nil
    assert style.hyperlink == nil
  end

  # Test apply_attribute/2
  describe "apply_attribute/2" do
    test ~c"adds a text attribute to the style" do
      style = TextFormatting.new()
      style = TextFormatting.apply_attribute(style, :bold)
      assert style.bold == true
    end

    test ~c"can add multiple attributes" do
      style = TextFormatting.new()
      style = TextFormatting.apply_attribute(style, :bold)
      style = TextFormatting.apply_attribute(style, :italic)
      assert style.bold == true
      assert style.italic == true
    end

    test "removes a text attribute using its \"no_\" counterpart" do
      style = TextFormatting.new()
      # Add bold
      style = TextFormatting.apply_attribute(style, :bold)
      assert style.bold == true
      # Remove bold using :normal_intensity (SGR 22)
      style = TextFormatting.apply_attribute(style, :normal_intensity)
      assert style.bold == false
    end

    test ~c"adds a text decoration" do
      style = TextFormatting.new()
      style = TextFormatting.apply_attribute(style, :underline)
      assert style.underline == true
    end

    test ~c"adds framed, encircled, and overlined attributes" do
      style = TextFormatting.new()
      style = TextFormatting.apply_attribute(style, :framed)
      assert style.framed == true
      style = TextFormatting.apply_attribute(style, :encircled)
      assert style.encircled == true
      style = TextFormatting.apply_attribute(style, :overlined)
      assert style.overlined == true
    end

    test ~c"removes framed, encircled, and overlined attributes" do
      style = TextFormatting.new()
      style = TextFormatting.apply_attribute(style, :framed)
      style = TextFormatting.apply_attribute(style, :encircled)
      style = TextFormatting.apply_attribute(style, :overlined)
      assert style.framed == true
      assert style.encircled == true
      assert style.overlined == true
      style = TextFormatting.apply_attribute(style, :not_framed_encircled)
      assert style.framed == false
      assert style.encircled == false
      style = TextFormatting.apply_attribute(style, :not_overlined)
      assert style.overlined == false
    end

    test ~c"can add multiple decorations" do
      style = TextFormatting.new()
      style = TextFormatting.apply_attribute(style, :underline)
      style = TextFormatting.apply_attribute(style, :blink)
      assert style.underline == true
      assert style.blink == true
    end

    test "removes a text decoration using its \"no_\" counterpart" do
      style = TextFormatting.new()
      # Add underline
      style = TextFormatting.apply_attribute(style, :underline)
      assert style.underline == true
      # Remove underline
      style = TextFormatting.apply_attribute(style, :no_underline)
      assert style.underline == false
      # SGR 24 removes both
      assert style.double_underline == false
    end

    test ~c"resets all formatting to default values with :reset" do
      style = TextFormatting.new()
      # Apply various attributes
      style = TextFormatting.apply_attribute(style, :bold)
      style = TextFormatting.apply_attribute(style, :underline)
      style = TextFormatting.apply_color(style, :foreground, :red)
      style = TextFormatting.apply_color(style, :background, :blue)

      # Reset
      style = TextFormatting.apply_attribute(style, :reset)
      assert style == TextFormatting.new()
    end
  end

  # Test apply_color/3
  describe "apply_color/3" do
    test ~c"sets foreground color" do
      style = TextFormatting.new()
      style = TextFormatting.apply_color(style, :foreground, :red)
      assert style.foreground == :red
    end

    test ~c"sets background color" do
      style = TextFormatting.new()
      style = TextFormatting.apply_color(style, :background, :blue)
      assert style.background == :blue
    end

    test ~c"resets foreground color with :default_fg via apply_attribute" do
      style =
        TextFormatting.new() |> TextFormatting.apply_color(:foreground, :red)

      style = TextFormatting.apply_attribute(style, :default_fg)
      assert style.foreground == nil
    end

    test ~c"resets background color with :default_bg via apply_attribute" do
      style =
        TextFormatting.new() |> TextFormatting.apply_color(:background, :blue)

      style = TextFormatting.apply_attribute(style, :default_bg)
      assert style.background == nil
    end
  end

  # Test size functions
  describe "size functions" do
    test ~c"set_double_width/1 enables double-width mode" do
      style = TextFormatting.new()
      style = TextFormatting.set_double_width(style)
      assert style.double_width == true
      # Side effect
      assert style.double_height == :none
    end

    test ~c"disables double-width mode via apply_attribute" do
      style = TextFormatting.new() |> TextFormatting.set_double_width()
      style = TextFormatting.apply_attribute(style, :no_double_width)
      assert style.double_width == false
    end

    test ~c"set_double_height_top/1 enables double-height top mode" do
      style = TextFormatting.new()
      style = TextFormatting.set_double_height_top(style)
      assert style.double_height == :top
      # Side effect
      assert style.double_width == true
    end

    test ~c"set_double_height_bottom/1 enables double-height bottom mode" do
      style = TextFormatting.new()
      style = TextFormatting.set_double_height_bottom(style)
      assert style.double_height == :bottom
      # Side effect
      assert style.double_width == true
    end

    test ~c"disables double-height mode via apply_attribute" do
      style = TextFormatting.new() |> TextFormatting.set_double_height_top()
      style = TextFormatting.apply_attribute(style, :no_double_height)
      assert style.double_height == :none
    end

    test ~c"reset_size/1 resets both double width and height" do
      style = TextFormatting.new()
      style = TextFormatting.set_double_height_top(style)
      style = TextFormatting.reset_size(style)
      assert style.double_width == false
      assert style.double_height == :none
    end
  end

  # Test effective_width/2
  describe "effective_width/2" do
    test ~c"returns 2 for double-width characters" do
      style = TextFormatting.new() |> TextFormatting.set_double_width()
      assert TextFormatting.effective_width(style, "A") == 2
    end

    test ~c"returns 2 for wide Unicode characters" do
      style = TextFormatting.new()
      # Example: Chinese character (often wide)
      assert TextFormatting.effective_width(style, "你") == 2
    end

    test ~c"returns 1 for standard ASCII characters" do
      style = TextFormatting.new()
      assert TextFormatting.effective_width(style, "A") == 1
    end
  end

  # Test needs_paired_line?/1 and paired_line_type/1
  describe "double-height line pairing" do
    test ~c"needs_paired_line? returns true for double-height top" do
      style = TextFormatting.new() |> TextFormatting.set_double_height_top()
      assert TextFormatting.needs_paired_line?(style) == true
    end

    test ~c"needs_paired_line? returns true for double-height bottom" do
      style = TextFormatting.new() |> TextFormatting.set_double_height_bottom()
      assert TextFormatting.needs_paired_line?(style) == true
    end

    test ~c"needs_paired_line? returns false for single height" do
      style = TextFormatting.new()
      assert TextFormatting.needs_paired_line?(style) == false
    end

    test ~c"paired_line_type returns :bottom for :top" do
      style = TextFormatting.new() |> TextFormatting.set_double_height_top()
      assert TextFormatting.get_paired_line_type(style) == :bottom
    end

    test ~c"paired_line_type returns :top for :bottom" do
      style = TextFormatting.new() |> TextFormatting.set_double_height_bottom()
      assert TextFormatting.get_paired_line_type(style) == :top
    end

    test ~c"paired_line_type returns nil for :none" do
      style = TextFormatting.new()
      assert TextFormatting.get_paired_line_type(style) == nil
    end

    test ~c"double-height line pairing get_paired_line_type returns :top for :bottom" do
      style = TextFormatting.new() |> TextFormatting.set_double_height_bottom()
      assert TextFormatting.get_paired_line_type(style) == :top
    end

    test ~c"double-height line pairing get_paired_line_type returns nil for :none" do
      style = TextFormatting.new()
      assert TextFormatting.get_paired_line_type(style) == nil
    end

    test ~c"apply_attribute/2 adds a text attribute to the style" do
      style = TextFormatting.new()
      style = TextFormatting.apply_attribute(style, :bold)
      assert style.bold == true
    end
  end

  # Note: Tests for merge/2 and other functions that might have existed before
  # are removed as they are not present in the current text_formatting.ex

  describe "parse_sgr_param/2 (test-only public)" do
    test ~c"parses attribute SGR code (bold)" do
      style = TextFormatting.new()
      style = TextFormatting.parse_sgr_param(1, style)
      assert style.bold == true
    end

    test ~c"parses color SGR code (foreground red)" do
      style = TextFormatting.new()
      style = TextFormatting.parse_sgr_param(31, style)
      assert style.foreground == :red
    end

    test ~c"parses bright color SGR code (bright blue foreground)" do
      style = TextFormatting.new()
      style = TextFormatting.parse_sgr_param(94, style)
      assert style.foreground == :blue or style.foreground == :bright_blue
    end

    test ~c"parses 8-bit foreground color SGR code" do
      style = TextFormatting.new()
      style = TextFormatting.parse_sgr_param({:fg_8bit, 42}, style)
      assert style.foreground == {:index, 42}
    end

    test ~c"parses 24-bit RGB background color SGR code" do
      style = TextFormatting.new()
      style = TextFormatting.parse_sgr_param({:bg_rgb, 10, 20, 30}, style)
      assert style.background == {:rgb, 10, 20, 30}
    end

    test ~c"returns unchanged style for unknown code" do
      style = TextFormatting.new()
      style2 = TextFormatting.parse_sgr_param(999, style)
      assert style2 == style
    end

    test ~c"parses SGR 51-55 (framed, encircled, overlined, not_framed_encircled, not_overlined)" do
      style = TextFormatting.new()
      style = TextFormatting.parse_sgr_param(51, style)
      assert style.framed == true
      style = TextFormatting.parse_sgr_param(52, style)
      assert style.encircled == true
      style = TextFormatting.parse_sgr_param(53, style)
      assert style.overlined == true
      style = TextFormatting.parse_sgr_param(54, style)
      assert style.framed == false
      assert style.encircled == false
      style = TextFormatting.parse_sgr_param(55, style)
      assert style.overlined == false
    end
  end
end
