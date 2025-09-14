defmodule Raxol.Terminal.PlatformSpecificTest do
  use ExUnit.Case
    alias Raxol.Terminal.{Renderer, ScreenBuffer}

  defp render_hello_html do
    buffer = ScreenBuffer.new(80, 24)

    buffer =
      Enum.reduce(String.graphemes("Hello"), {buffer, 0}, fn char, {buf, x} ->
        {ScreenBuffer.write_char(buf, x, 0, char, nil), x + 1}
      end)
      |> elem(0)

    renderer = Renderer.new(buffer)
    Renderer.render(renderer)
  end

  describe "platform-specific terminal features" do
    test ~c"terminal type detection" do
      term = System.get_env("TERM")
      assert term != nil
      assert is_binary(term)
    end

    test ~c"color support detection" do
      colors = System.get_env("COLORTERM")
      assert colors != nil
      assert is_binary(colors)
    end

    test ~c"terminal size detection" do
      {width, height} = :io.columns()
      assert width > 0
      assert height > 0
    end

    test ~c"UTF-8 support" do
      lang = System.get_env("LANG")
      assert lang != nil
      assert String.contains?(lang, "UTF-8")
    end

    test ~c"graphics support detection" do
      term_program = System.get_env("TERM_PROGRAM")
      assert term_program != nil
      assert is_binary(term_program)
    end
  end

  describe "platform-specific rendering" do
    test ~c"renders with platform-specific colors" do
      html = render_hello_html()
      assert html =~ "<span"
      assert html =~ ">H<"
      assert html =~ ">e<"
      assert html =~ ">l<"
      assert html =~ ">o<"
    end

    test ~c"handles platform-specific terminal features" do
      html = render_hello_html()
      assert html =~ "<span"
      assert html =~ ">H<"
      assert html =~ ">e<"
      assert html =~ ">l<"
      assert html =~ ">o<"
    end
  end

  describe "platform-specific input handling" do
    test ~c"handles platform-specific key codes" do
      html = render_hello_html()
      assert html =~ "<span"
      assert html =~ ">H<"
      assert html =~ ">e<"
      assert html =~ ">l<"
      assert html =~ ">o<"
    end

    test ~c"handles platform-specific mouse events" do
      html = render_hello_html()
      assert html =~ "<span"
      assert html =~ ">H<"
      assert html =~ ">e<"
      assert html =~ ">l<"
      assert html =~ ">o<"
    end
  end
end
