defmodule Raxol.Terminal.ANSI.TextFormattingTest do
  use ExUnit.Case
  doctest Raxol.Terminal.ANSI.TextFormatting

  alias Raxol.Terminal.ANSI.TextFormatting

  # Test new/0
  test "new/0 creates a new text style with default values" do
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
    test "adds a text attribute to the style" do
      style = TextFormatting.new()
      style = TextFormatting.apply_attribute(style, :bold)
      assert style.bold == true
    end

    test "can add multiple attributes" do
      style = TextFormatting.new()
      style = TextFormatting.apply_attribute(style, :bold)
      style = TextFormatting.apply_attribute(style, :italic)
      assert style.bold == true
      assert style.italic == true
    end

    test "removes a text attribute using its 'no_' counterpart" do
      style = TextFormatting.new()
      # Add bold
      style = TextFormatting.apply_attribute(style, :bold)
      assert style.bold == true
      # Remove bold using :normal_intensity (SGR 22)
      style = TextFormatting.apply_attribute(style, :normal_intensity)
      assert style.bold == false
    end

    test "adds a text decoration" do
      style = TextFormatting.new()
      style = TextFormatting.apply_attribute(style, :underline)
      assert style.underline == true
    end

    test "can add multiple decorations" do
      style = TextFormatting.new()
      style = TextFormatting.apply_attribute(style, :underline)
      style = TextFormatting.apply_attribute(style, :blink)
      assert style.underline == true
      assert style.blink == true
    end

    test "removes a text decoration using its 'no_' counterpart" do
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

    test "resets all formatting to default values with :reset" do
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
    test "sets foreground color" do
      style = TextFormatting.new()
      style = TextFormatting.apply_color(style, :foreground, :red)
      assert style.foreground == :red
    end

    test "sets background color" do
      style = TextFormatting.new()
      style = TextFormatting.apply_color(style, :background, :blue)
      assert style.background == :blue
    end

    test "resets foreground color with :default_fg via apply_attribute" do
      style =
        TextFormatting.new() |> TextFormatting.apply_color(:foreground, :red)

      style = TextFormatting.apply_attribute(style, :default_fg)
      assert style.foreground == nil
    end

    test "resets background color with :default_bg via apply_attribute" do
      style =
        TextFormatting.new() |> TextFormatting.apply_color(:background, :blue)

      style = TextFormatting.apply_attribute(style, :default_bg)
      assert style.background == nil
    end
  end

  # Test size functions
  describe "size functions" do
    test "set_double_width/1 enables double-width mode" do
      style = TextFormatting.new()
      style = TextFormatting.set_double_width(style)
      assert style.double_width == true
      # Side effect
      assert style.double_height == :none
    end

    test "disables double-width mode via apply_attribute" do
      style = TextFormatting.new() |> TextFormatting.set_double_width()
      style = TextFormatting.apply_attribute(style, :no_double_width)
      assert style.double_width == false
    end

    test "set_double_height_top/1 enables double-height top mode" do
      style = TextFormatting.new()
      style = TextFormatting.set_double_height_top(style)
      assert style.double_height == :top
      # Side effect
      assert style.double_width == true
    end

    test "set_double_height_bottom/1 enables double-height bottom mode" do
      style = TextFormatting.new()
      style = TextFormatting.set_double_height_bottom(style)
      assert style.double_height == :bottom
      # Side effect
      assert style.double_width == true
    end

    test "disables double-height mode via apply_attribute" do
      style = TextFormatting.new() |> TextFormatting.set_double_height_top()
      style = TextFormatting.apply_attribute(style, :no_double_height)
      assert style.double_height == :none
    end

    test "reset_size/1 resets both double width and height" do
      style = TextFormatting.new()
      style = TextFormatting.set_double_height_top(style)
      style = TextFormatting.reset_size(style)
      assert style.double_width == false
      assert style.double_height == :none
    end
  end

  # Test effective_width/2
  describe "effective_width/2" do
    test "returns 2 for double-width characters" do
      style = TextFormatting.new() |> TextFormatting.set_double_width()
      assert TextFormatting.effective_width(style, "A") == 2
    end

    test "returns 2 for wide Unicode characters" do
      style = TextFormatting.new()
      # Example: Chinese character (often wide)
      assert TextFormatting.effective_width(style, "你") == 2
    end

    test "returns 1 for standard ASCII characters" do
      style = TextFormatting.new()
      assert TextFormatting.effective_width(style, "A") == 1
    end
  end

  # Test needs_paired_line?/1 and paired_line_type/1
  describe "double-height line pairing" do
    test "needs_paired_line? returns true for double-height top" do
      style = TextFormatting.new() |> TextFormatting.set_double_height_top()
      assert TextFormatting.needs_paired_line?(style) == true
    end

    test "needs_paired_line? returns true for double-height bottom" do
      style = TextFormatting.new() |> TextFormatting.set_double_height_bottom()
      assert TextFormatting.needs_paired_line?(style) == true
    end

    test "needs_paired_line? returns false for single height" do
      style = TextFormatting.new()
      assert TextFormatting.needs_paired_line?(style) == false
    end

    test "paired_line_type returns :bottom for :top" do
      style = TextFormatting.new() |> TextFormatting.set_double_height_top()
      assert TextFormatting.get_paired_line_type(style) == :bottom
    end

    test "paired_line_type returns :top for :bottom" do
      style = TextFormatting.new() |> TextFormatting.set_double_height_bottom()
      assert TextFormatting.get_paired_line_type(style) == :top
    end

    test "paired_line_type returns nil for :none" do
      style = TextFormatting.new()
      assert TextFormatting.get_paired_line_type(style) == nil
    end

    test "double-height line pairing get_paired_line_type returns :top for :bottom", %{style: style} do
      style = Map.put(style, :double_height, :bottom)
      assert TextFormatting.get_paired_line_type(style) == :top
    end

    test "double-height line pairing get_paired_line_type returns nil for :none", %{style: style} do
      style = Map.put(style, :double_height, :none)
      assert TextFormatting.get_paired_line_type(style) == nil
    end

    test "apply_attribute/2 adds a text attribute to the style", %{style: style} do
      style = TextFormatting.apply_attribute(style, :bold)
      assert style.bold == true
    end
  end

  # Note: Tests for merge/2 and other functions that might have existed before
  # are removed as they are not present in the current text_formatting.ex
end
