defmodule Raxol.Terminal.Style.ManagerTest do
  use ExUnit.Case, async: true
  alias Raxol.Terminal.Style.Manager

  describe "StyleManager" do
    test ~c"new/0 creates a new text style with default values" do
      style = Manager.new()
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

    test ~c"get_current_style/1 returns the current style" do
      style = Manager.new()
      assert Manager.get_current_style(style) == style
    end

    test ~c"set_style/2 updates the style" do
      initial_style = Manager.new()
      new_style = Manager.apply_style(initial_style, :bold)
      assert Manager.set_style(initial_style, new_style) == new_style
    end

    test ~c"apply_style/2 adds a text attribute" do
      style = Manager.new()
      style = Manager.apply_style(style, :bold)
      assert style.bold == true
    end

    test ~c"reset_style/1 resets all attributes to default" do
      style = Manager.new()
      style = Manager.apply_style(style, :bold)
      style = Manager.apply_style(style, :underline)
      style = Manager.set_foreground(style, :red)
      style = Manager.set_background(style, :blue)

      reset_style = Manager.reset_style(style)
      assert reset_style == Manager.new()
    end

    test ~c"set_foreground/2 and get_foreground/1 work correctly" do
      style = Manager.new()
      style = Manager.set_foreground(style, :red)
      assert Manager.get_foreground(style) == :red
    end

    test ~c"set_background/2 and get_background/1 work correctly" do
      style = Manager.new()
      style = Manager.set_background(style, :blue)
      assert Manager.get_background(style) == :blue
    end

    test ~c"double width and height functions work correctly" do
      style = Manager.new()

      # Test double width
      style = Manager.set_double_width(style)
      assert style.double_width == true
      assert style.double_height == :none

      # Test double height top
      style = Manager.set_double_height_top(style)
      assert style.double_width == true
      assert style.double_height == :top

      # Test double height bottom
      style = Manager.set_double_height_bottom(style)
      assert style.double_width == true
      assert style.double_height == :bottom

      # Test reset size
      style = Manager.reset_size(style)
      assert style.double_width == false
      assert style.double_height == :none
    end

    test ~c"hyperlink functions work correctly" do
      style = Manager.new()
      url = "https://example.com"

      style = Manager.set_hyperlink(style, url)
      assert Manager.get_hyperlink(style) == url

      style = Manager.set_hyperlink(style, nil)
      assert Manager.get_hyperlink(style) == nil
    end

    test ~c"ansi_code_to_color_name/1 converts codes correctly" do
      assert Manager.ansi_code_to_color_name(31) == :red
      assert Manager.ansi_code_to_color_name(44) == :blue
      assert Manager.ansi_code_to_color_name(99) == nil
    end

    test ~c"format_sgr_params/1 formats parameters correctly" do
      style = Manager.new()
      style = Manager.apply_style(style, :bold)
      style = Manager.apply_style(style, :underline)
      style = Manager.set_foreground(style, :red)
      style = Manager.set_background(style, :blue)

      params = Manager.format_sgr_params(style)
      # The exact format may vary, but it should contain the relevant codes
      # bold
      assert String.contains?(params, "1")
      # underline
      assert String.contains?(params, "4")
      # red foreground
      assert String.contains?(params, "31")
      # blue background
      assert String.contains?(params, "44")
    end
  end
end
