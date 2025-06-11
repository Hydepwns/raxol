defmodule Raxol.Terminal.RendererTest do
  use ExUnit.Case
  alias Raxol.Terminal.{Renderer, ScreenBuffer}

  defp default_buffer(width \\ 80, height \\ 24) do
    ScreenBuffer.new(width, height)
  end

  describe "new/1" do
    test "creates a new renderer with a screen buffer" do
      buffer = default_buffer()
      renderer = Renderer.new(buffer)
      assert renderer.screen_buffer == buffer
      assert renderer.cursor == nil
      assert renderer.theme == %{}
      assert renderer.font_settings == %{}
    end

    test "creates a new renderer with theme and font settings" do
      buffer = default_buffer()
      theme = %{foreground: :blue}
      font_settings = %{size: 12}
      renderer = Renderer.new(buffer, theme, font_settings)
      assert renderer.screen_buffer == buffer
      assert renderer.theme == theme
      assert renderer.font_settings == font_settings
    end
  end

  describe "render/1" do
    test "renders empty screen buffer" do
      buffer = default_buffer(10, 1)
      renderer = Renderer.new(buffer)
      output = Renderer.render(renderer)
      expected_span = "<span style=\"\"> </span>"
      assert output == String.duplicate(expected_span, 10)
    end

    test "renders screen buffer with content" do
      buffer = default_buffer(5, 1)
      buffer = ScreenBuffer.write_char(buffer, 0, 0, "H", %{foreground: :red})
      buffer = ScreenBuffer.write_char(buffer, 1, 0, "i")

      renderer =
        Renderer.new(buffer, %{foreground: %{default: "#FFF", red: "#F00"}})

      output = Renderer.render(renderer)

      expected_output =
        "<span style=\"color: #F00\">H</span><span style=\"color: #FFF\">i</span>" <>
          String.duplicate("<span style=\"color: #FFF\"> </span>", 3)

      assert output == expected_output
    end

    test "renders multiple rows" do
      buffer = default_buffer(3, 2)
      buffer = ScreenBuffer.write_char(buffer, 0, 0, "A")
      buffer = ScreenBuffer.write_char(buffer, 1, 1, "B")

      renderer = Renderer.new(buffer, %{foreground: %{default: "#CCC"}})
      output = Renderer.render(renderer)

      expected_row1 =
        "<span style=\"color: #CCC\">A</span>" <>
          String.duplicate("<span style=\"color: #CCC\"> </span>", 2)

      expected_row2 =
        "<span style=\"color: #CCC\"> </span><span style=\"color: #CCC\">B</span><span style=\"color: #CCC\"> </span>"

      assert output == expected_row1 <> "\n" <> expected_row2
    end
  end

  describe "set_cursor/2" do
    test "sets the cursor position" do
      buffer = default_buffer()
      renderer = Renderer.new(buffer)
      renderer = Renderer.set_cursor(renderer, {10, 5})
      assert renderer.cursor == {10, 5}
    end
  end

  describe "clear_cursor/1" do
    test "clears the cursor position" do
      buffer = default_buffer()
      renderer = Renderer.new(buffer)
      renderer = Renderer.set_cursor(renderer, {10, 5})
      renderer = Renderer.clear_cursor(renderer)
      assert renderer.cursor == nil
    end
  end

  describe "set_theme/2" do
    test "updates the theme" do
      buffer = default_buffer()
      renderer = Renderer.new(buffer)
      theme = %{foreground: %{default: "#ABC"}}
      renderer = Renderer.set_theme(renderer, theme)
      assert renderer.theme == theme
    end
  end

  describe "set_font_settings/2" do
    test "updates the font settings" do
      buffer = default_buffer()
      renderer = Renderer.new(buffer)
      settings = %{family: "Fira Code"}
      renderer = Renderer.set_font_settings(renderer, settings)
      assert renderer.font_settings == settings
    end
  end

  describe "render_cell (via render)" do
    test "renders basic cell" do
      buffer = ScreenBuffer.new(1, 1) |> ScreenBuffer.write_char(0, 0, "X")
      renderer = Renderer.new(buffer, %{foreground: %{default: "#FFF"}})
      output = Renderer.render(renderer)
      assert output == "<span style=\"color: #FFF\">X</span>"
    end

    test "renders cell with foreground color" do
      style = %{foreground: :red}

      buffer =
        ScreenBuffer.new(1, 1) |> ScreenBuffer.write_char(0, 0, "X", style)

      theme = %{foreground: %{red: "#FF0000"}}
      renderer = Renderer.new(buffer, theme)
      output = Renderer.render(renderer)
      assert output == "<span style=\"color: #FF0000\">X</span>"
    end

    test "renders cell with background color" do
      style = %{background: :blue}

      buffer =
        ScreenBuffer.new(1, 1) |> ScreenBuffer.write_char(0, 0, "X", style)

      theme = %{background: %{blue: "#0000FF"}}
      renderer = Renderer.new(buffer, theme)
      output = Renderer.render(renderer)
      assert output == "<span style=\"background-color: #0000FF\">X</span>"
    end

    test "renders cell with bold style" do
      style = %{bold: true}

      buffer =
        ScreenBuffer.new(1, 1) |> ScreenBuffer.write_char(0, 0, "X", style)

      renderer = Renderer.new(buffer)
      output = Renderer.render(renderer)
      assert output == "<span style=\"font-weight: bold\">X</span>"
    end

    test "renders cell with underline style" do
      style = %{underline: true}

      buffer =
        ScreenBuffer.new(1, 1) |> ScreenBuffer.write_char(0, 0, "X", style)

      renderer = Renderer.new(buffer)
      output = Renderer.render(renderer)
      assert output == "<span style=\"text-decoration: underline\">X</span>"
    end

    test "renders cell with italic style" do
      style = %{italic: true}

      buffer =
        ScreenBuffer.new(1, 1) |> ScreenBuffer.write_char(0, 0, "X", style)

      renderer = Renderer.new(buffer)
      output = Renderer.render(renderer)
      assert output == "<span style=\"font-style: italic\">X</span>"
    end

    test "renders cell with multiple styles" do
      style = %{
        foreground: :green,
        background: :black,
        bold: true,
        italic: true
      }

      buffer =
        ScreenBuffer.new(1, 1) |> ScreenBuffer.write_char(0, 0, "X", style)

      theme = %{foreground: %{green: "#0F0"}, background: %{black: "#000"}}
      renderer = Renderer.new(buffer, theme)
      output = Renderer.render(renderer)

      assert String.contains?(output, "<span style=\"")
      assert String.contains?(output, "color: #0F0")
      assert String.contains?(output, "background-color: #000")
      assert String.contains?(output, "font-weight: bold")
      assert String.contains?(output, "font-style: italic")
      assert String.contains?(output, "\">X</span>")
    end

    test "uses default theme colors when cell style is nil" do
      buffer = ScreenBuffer.new(1, 1) |> ScreenBuffer.write_char(0, 0, "X", %{})
      theme = %{foreground: %{default: "#ABC"}, background: %{default: "#DEF"}}
      renderer = Renderer.new(buffer, theme)
      output = Renderer.render(renderer)

      assert String.contains?(output, "<span style=\"")
      assert String.contains?(output, "color: #ABC")
      assert String.contains?(output, "background-color: #DEF")
      assert String.contains?(output, "\">X</span>")
      refute String.contains?(output, "font-weight")
      refute String.contains?(output, "font-style")
      refute String.contains?(output, "text-decoration")
    end

    test "handles missing theme colors gracefully" do
      buffer =
        ScreenBuffer.new(1, 1)
        |> ScreenBuffer.write_char(0, 0, "X", %{foreground: :red})

      renderer = Renderer.new(buffer, %{})
      output = Renderer.render(renderer)
      assert output == "<span style=\"\">X</span>"
    end
  end
end
