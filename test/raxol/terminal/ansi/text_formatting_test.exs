defmodule Raxol.Terminal.ANSI.TextFormattingTest do
  use ExUnit.Case
  alias Raxol.Terminal.ANSI.TextFormatting

  describe "new/0" do
    test "creates a new text style with default values" do
      style = TextFormatting.new()
      assert style.foreground == :default
      assert style.background == :default
      assert MapSet.size(style.attributes) == 0
      assert MapSet.size(style.decorations) == 0
      assert style.double_width == false
      assert style.double_height == false
    end
  end

  describe "set_attribute/2" do
    test "adds a text attribute to the style" do
      style = TextFormatting.new()
      style = TextFormatting.set_attribute(style, :bold)
      assert MapSet.member?(style.attributes, :bold)
    end

    test "can add multiple attributes" do
      style = TextFormatting.new()

      style =
        style
        |> TextFormatting.set_attribute(:bold)
        |> TextFormatting.set_attribute(:italic)
        |> TextFormatting.set_attribute(:underline)

      assert MapSet.member?(style.attributes, :bold)
      assert MapSet.member?(style.attributes, :italic)
      assert MapSet.member?(style.attributes, :underline)
    end
  end

  describe "remove_attribute/2" do
    test "removes a text attribute from the style" do
      style = TextFormatting.new()

      style =
        style
        |> TextFormatting.set_attribute(:bold)
        |> TextFormatting.remove_attribute(:bold)

      refute MapSet.member?(style.attributes, :bold)
    end
  end

  describe "set_decoration/2" do
    test "adds a text decoration to the style" do
      style = TextFormatting.new()
      style = TextFormatting.set_decoration(style, :underline)
      assert MapSet.member?(style.decorations, :underline)
    end

    test "can add multiple decorations" do
      style = TextFormatting.new()

      style =
        style
        |> TextFormatting.set_decoration(:underline)
        |> TextFormatting.set_decoration(:overline)

      assert MapSet.member?(style.decorations, :underline)
      assert MapSet.member?(style.decorations, :overline)
    end
  end

  describe "remove_decoration/2" do
    test "removes a text decoration from the style" do
      style = TextFormatting.new()

      style =
        style
        |> TextFormatting.set_decoration(:underline)
        |> TextFormatting.remove_decoration(:underline)

      refute MapSet.member?(style.decorations, :underline)
    end
  end

  describe "set_foreground/2" do
    test "sets a named color as foreground" do
      style = TextFormatting.new()
      style = TextFormatting.set_foreground(style, :red)
      assert style.foreground == :red
    end

    test "sets an RGB color as foreground" do
      style = TextFormatting.new()
      style = TextFormatting.set_foreground(style, {255, 0, 0})
      assert style.foreground == {255, 0, 0}
    end
  end

  describe "set_background/2" do
    test "sets a named color as background" do
      style = TextFormatting.new()
      style = TextFormatting.set_background(style, :blue)
      assert style.background == :blue
    end

    test "sets an RGB color as background" do
      style = TextFormatting.new()
      style = TextFormatting.set_background(style, {0, 0, 255})
      assert style.background == {0, 0, 255}
    end
  end

  describe "set_double_width/2" do
    test "enables double-width mode" do
      style = TextFormatting.new()
      style = TextFormatting.set_double_width(style, true)
      assert style.double_width == true
    end

    test "disables double-width mode" do
      style = TextFormatting.new()

      style =
        style
        |> TextFormatting.set_double_width(true)
        |> TextFormatting.set_double_width(false)

      assert style.double_width == false
    end
  end

  describe "set_double_height/2" do
    test "enables double-height mode" do
      style = TextFormatting.new()
      style = TextFormatting.set_double_height(style, true)
      assert style.double_height == true
    end

    test "disables double-height mode" do
      style = TextFormatting.new()

      style =
        style
        |> TextFormatting.set_double_height(true)
        |> TextFormatting.set_double_height(false)

      assert style.double_height == false
    end
  end

  describe "reset/1" do
    test "resets all formatting to default values" do
      style = TextFormatting.new()

      style =
        style
        |> TextFormatting.set_attribute(:bold)
        |> TextFormatting.set_decoration(:underline)
        |> TextFormatting.set_foreground(:red)
        |> TextFormatting.set_background(:blue)
        |> TextFormatting.set_double_width(true)
        |> TextFormatting.set_double_height(true)
        |> TextFormatting.reset()

      assert style.foreground == :default
      assert style.background == :default
      assert MapSet.size(style.attributes) == 0
      assert MapSet.size(style.decorations) == 0
      assert style.double_width == false
      assert style.double_height == false
    end
  end

  describe "merge/2" do
    test "merges two styles with second style taking precedence" do
      style1 =
        TextFormatting.new()
        |> TextFormatting.set_attribute(:bold)
        |> TextFormatting.set_foreground(:red)
        |> TextFormatting.set_double_width(true)

      style2 =
        TextFormatting.new()
        |> TextFormatting.set_attribute(:italic)
        |> TextFormatting.set_foreground(:blue)
        |> TextFormatting.set_double_width(false)

      merged = TextFormatting.merge(style1, style2)

      assert MapSet.member?(merged.attributes, :bold)
      assert MapSet.member?(merged.attributes, :italic)
      assert merged.foreground == :blue
      assert merged.double_width == false
    end
  end
end
