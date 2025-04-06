defmodule Raxol.Terminal.PlatformSpecificTest do
  use ExUnit.Case
  alias Raxol.Terminal.{Renderer, ScreenBuffer}

  describe "platform-specific terminal features" do
    test "terminal type detection" do
      term = System.get_env("TERM")
      assert term != nil
      assert is_binary(term)
    end

    test "color support detection" do
      colors = System.get_env("COLORTERM")
      assert colors != nil
      assert is_binary(colors)
    end

    test "terminal size detection" do
      {width, height} = :io.columns()
      assert width > 0
      assert height > 0
    end

    test "UTF-8 support" do
      lang = System.get_env("LANG")
      assert lang != nil
      assert String.contains?(lang, "UTF-8")
    end

    test "graphics support detection" do
      term_program = System.get_env("TERM_PROGRAM")
      assert term_program != nil
      assert is_binary(term_program)
    end
  end

  describe "platform-specific rendering" do
    test "renders with platform-specific colors" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ScreenBuffer.write_char(buffer, "Hello")
      renderer = Renderer.new()

      html = Renderer.render(buffer, renderer)

      assert html =~ "Hello"
      assert html =~ ~s(<div class="cell">)
    end

    test "handles platform-specific terminal features" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ScreenBuffer.write_char(buffer, "Hello")
      renderer = Renderer.new()

      html = Renderer.render(buffer, renderer)

      assert html =~ ~s(<div class="terminal">)
      assert html =~ ~s(style="width: 80ch; height: 24ch;)
    end
  end

  describe "platform-specific input handling" do
    test "handles platform-specific key codes" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ScreenBuffer.write_char(buffer, "Hello")
      renderer = Renderer.new()

      html = Renderer.render(buffer, renderer)

      assert html =~ ~s(<div class="terminal">)
      assert html =~ ~s(data-platform="#{System.get_env("PLATFORM")}")
    end

    test "handles platform-specific mouse events" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ScreenBuffer.write_char(buffer, "Hello")
      renderer = Renderer.new()

      html = Renderer.render(buffer, renderer)

      assert html =~ ~s(<div class="terminal">)
      assert html =~ ~s(data-mouse-support="true")
    end
  end
end
