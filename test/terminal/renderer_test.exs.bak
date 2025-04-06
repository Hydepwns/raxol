defmodule Raxol.Terminal.RendererTest do
  use ExUnit.Case
  alias Raxol.Terminal.{Renderer, ScreenBuffer, Cell}

  describe "new/1" do
    test "creates a new renderer with default options" do
      renderer = Renderer.new()
      assert renderer.theme.background == "#000000"
      assert renderer.theme.foreground == "#ffffff"
      assert renderer.font_family == "Fira Code"
      assert renderer.font_size == 14
      assert renderer.line_height == 1.2
      assert renderer.cursor_style == :block
      assert renderer.cursor_blink == true
      assert renderer.cursor_color == "#ffffff"
      assert renderer.selection_color == "rgba(255, 255, 255, 0.2)"
      assert renderer.scrollback_limit == 1000
      assert renderer.batch_size == 100
      assert renderer.virtual_scroll == true
      assert renderer.visible_rows == 24
    end

    test "creates a new renderer with custom options" do
      theme = %{
        background: "#111111",
        foreground: "#eeeeee",
        red: "#ff0000"
      }

      renderer = Renderer.new(
        theme: theme,
        font_family: "Courier New",
        font_size: 16,
        line_height: 1.5,
        cursor_style: :underline,
        cursor_blink: false,
        cursor_color: "#ff0000",
        selection_color: "rgba(255, 0, 0, 0.2)",
        scrollback_limit: 500,
        batch_size: 200,
        virtual_scroll: false,
        visible_rows: 30
      )

      assert renderer.theme.background == "#111111"
      assert renderer.theme.foreground == "#eeeeee"
      assert renderer.theme.red == "#ff0000"
      assert renderer.theme.green == "#00cd00" # Default value preserved
      assert renderer.font_family == "Courier New"
      assert renderer.font_size == 16
      assert renderer.line_height == 1.5
      assert renderer.cursor_style == :underline
      assert renderer.cursor_blink == false
      assert renderer.cursor_color == "#ff0000"
      assert renderer.selection_color == "rgba(255, 0, 0, 0.2)"
      assert renderer.scrollback_limit == 500
      assert renderer.batch_size == 200
      assert renderer.virtual_scroll == false
      assert renderer.visible_rows == 30
    end
  end

  describe "render/2" do
    test "renders empty screen buffer" do
      buffer = ScreenBuffer.new(80, 24)
      renderer = Renderer.new()
      html = Renderer.render(buffer, renderer)

      assert html =~ ~s(<div class="terminal">)
      assert html =~ ~s(style="width: 80ch; height: 24ch; font-family: Fira Code; font-size: 14px; line-height: 1.2;">)
      assert html =~ ~s(<div class="screen">)
    end

    test "renders screen buffer with content" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ScreenBuffer.write_char(buffer, "Hello")
      renderer = Renderer.new()

      html = Renderer.render(buffer, renderer)

      assert html =~ "Hello"
      assert html =~ ~s(<div class="cell">)
    end

    test "renders scrollback buffer" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ScreenBuffer.write_char(buffer, "Line 1\nLine 2\nLine 3\nLine 4")
      renderer = Renderer.new()

      html = Renderer.render(buffer, renderer)

      assert html =~ ~s(<div class="scrollback">)
      assert html =~ "Line 1"
    end

    test "renders cursor" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ScreenBuffer.move_cursor(buffer, 5, 3)
      renderer = Renderer.new()

      html = Renderer.render(buffer, renderer)

      assert html =~ ~s(<div class="cursor-block">)
      assert html =~ ~s(style="left: 5ch; top: 3ch; background-color: #ffffff; animation: blink 1s step-end infinite;">)
    end

    test "renders selection" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ScreenBuffer.set_selection(buffer, 0, 0, 5, 0)
      renderer = Renderer.new()

      html = Renderer.render(buffer, renderer)

      assert html =~ ~s(<div class="selection">)
      assert html =~ ~s(style="left: 0ch; top: 0ch; width: 5ch; height: 0ch; background-color: rgba(255, 255, 255, 0.2);">)
    end
  end

  describe "render_screen/2" do
    test "renders empty screen" do
      buffer = ScreenBuffer.new(80, 24)
      renderer = Renderer.new()
      html = Renderer.render_screen(buffer, renderer)

      assert html =~ ~s(<div class="screen">)
    end

    test "renders screen with content" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ScreenBuffer.write_char(buffer, "Hello")
      renderer = Renderer.new()

      html = Renderer.render_screen(buffer, renderer)

      assert html =~ "Hello"
      assert html =~ ~s(<div class="row">)
    end

    test "uses virtual scrolling when enabled" do
      buffer = ScreenBuffer.new(80, 24)
      # Fill buffer with 50 rows
      buffer = Enum.reduce(41..50, buffer, fn i, acc ->
        ScreenBuffer.append_line(acc, "Line #{i}")
      end)

      renderer = Renderer.new(visible_rows: 10, virtual_scroll: true)
      html = Renderer.render_screen(buffer, renderer)

      # Should only render the last 10 rows
      assert html =~ "Line 41"
      assert html =~ "Line 50"
      refute html =~ "Line 40"
    end

    test "renders all rows when virtual scrolling is disabled" do
      buffer = ScreenBuffer.new(80, 24)
      # Fill buffer with 50 rows
      buffer = Enum.reduce(41..50, buffer, fn i, acc ->
        ScreenBuffer.append_line(acc, "Line #{i}")
      end)

      renderer = Renderer.new(virtual_scroll: false)
      html = Renderer.render_screen(buffer, renderer)

      # Should render all rows
      assert html =~ "Line 41"
      assert html =~ "Line 50"
    end
  end

  describe "render_scrollback/2" do
    test "renders empty scrollback" do
      buffer = ScreenBuffer.new(80, 24)
      renderer = Renderer.new()
      html = Renderer.render_scrollback(buffer, renderer)

      assert html == ""
    end

    test "renders scrollback with content" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ScreenBuffer.write_char(buffer, "Line 1\nLine 2\nLine 3\nLine 4")
      renderer = Renderer.new()

      html = Renderer.render_scrollback(buffer, renderer)

      assert html =~ ~s(<div class="scrollback">)
      assert html =~ "Line 1"
    end

    test "limits scrollback size" do
      buffer = ScreenBuffer.new(80, 24)
      # Fill buffer with 2000 rows
      buffer = Enum.reduce(1..2000, buffer, fn i, acc ->
        ScreenBuffer.write_char(acc, "Line #{i}\n")
      end)

      renderer = Renderer.new(scrollback_limit: 1000)
      html = Renderer.render_scrollback(buffer, renderer)

      # Should only render the first 1000 rows
      assert html =~ "Line 1"
      assert html =~ "Line 1000"
      refute html =~ "Line 1001"
      refute html =~ "Line 2000"
    end

    test "uses virtual scrolling for scrollback when enabled" do
      buffer = ScreenBuffer.new(80, 24)
      # Fill buffer with 2000 rows
      buffer = Enum.reduce(1..2000, buffer, fn i, acc ->
        ScreenBuffer.write_char(acc, "Line #{i}\n")
      end)

      renderer = Renderer.new(scrollback_limit: 1000, visible_rows: 10, virtual_scroll: true)
      html = Renderer.render_scrollback(buffer, renderer)

      # Should only render the last 10 rows of the first 1000
      assert html =~ "Line 991"
      assert html =~ "Line 1000"
      refute html =~ "Line 1"
      refute html =~ "Line 990"
    end
  end

  describe "render_cursor/2" do
    test "renders block cursor" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ScreenBuffer.move_cursor(buffer, 10, 5)
      renderer = Renderer.new(cursor_style: :block)

      html = Renderer.render_cursor(buffer, renderer)

      assert html =~ ~s(<div class="cursor-block">)
      assert html =~ ~s(style="left: 10ch; top: 5ch; background-color: #ffffff; animation: blink 1s step-end infinite;">)
    end

    test "renders underline cursor" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ScreenBuffer.move_cursor(buffer, 10, 5)
      renderer = Renderer.new(cursor_style: :underline)

      html = Renderer.render_cursor(buffer, renderer)

      assert html =~ ~s(<div class="cursor-underline">)
      assert html =~ ~s(style="left: 10ch; top: 5ch; background-color: #ffffff; animation: blink 1s step-end infinite;">)
    end

    test "renders bar cursor" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ScreenBuffer.move_cursor(buffer, 10, 5)
      renderer = Renderer.new(cursor_style: :bar)

      html = Renderer.render_cursor(buffer, renderer)

      assert html =~ ~s(<div class="cursor-bar">)
      assert html =~ ~s(style="left: 10ch; top: 5ch; background-color: #ffffff; animation: blink 1s step-end infinite;">)
    end

    test "renders non-blinking cursor" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ScreenBuffer.move_cursor(buffer, 10, 5)
      renderer = Renderer.new(cursor_blink: false)

      html = Renderer.render_cursor(buffer, renderer)

      assert html =~ ~s(<div class="cursor-block">)
      assert html =~ ~s(style="left: 10ch; top: 5ch; background-color: #ffffff;">)
      refute html =~ "animation: blink"
    end

    test "renders cursor with custom color" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ScreenBuffer.move_cursor(buffer, 10, 5)
      renderer = Renderer.new(cursor_color: "#ff0000")

      html = Renderer.render_cursor(buffer, renderer)

      assert html =~ ~s(style="left: 10ch; top: 5ch; background-color: #ff0000;">)
    end
  end

  describe "render_selection/2" do
    test "renders no selection" do
      buffer = ScreenBuffer.new(80, 24)
      renderer = Renderer.new()
      html = Renderer.render_selection(buffer, renderer)

      assert html == ""
    end

    test "renders selection area" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ScreenBuffer.set_selection(buffer, 0, 0, 10, 2)
      renderer = Renderer.new()

      html = Renderer.render_selection(buffer, renderer)

      assert html =~ ~s(<div class="selection">)
      assert html =~ ~s(style="left: 0ch; top: 0ch; width: 10ch; height: 2ch; background-color: rgba(255, 255, 255, 0.2);">)
    end

    test "renders selection with custom color" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ScreenBuffer.set_selection(buffer, 0, 0, 10, 2)
      renderer = Renderer.new(selection_color: "rgba(255, 0, 0, 0.2)")

      html = Renderer.render_selection(buffer, renderer)

      assert html =~ ~s(style="left: 0ch; top: 0ch; width: 10ch; height: 2ch; background-color: rgba(255, 0, 0, 0.2);">)
    end
  end

  describe "render_row/5" do
    test "renders empty row" do
      buffer = ScreenBuffer.new(80, 24)
      row = List.first(buffer.buffer)
      renderer = Renderer.new()
      html = Renderer.render_row(row, 0, buffer, renderer)

      assert html =~ ~s(<div class="row screen">)
      assert html =~ ~s(data-y="0">)
    end

    test "renders row with content" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ScreenBuffer.write_char(buffer, "Hello")
      row = List.first(buffer.buffer)
      renderer = Renderer.new()
      html = Renderer.render_row(row, 0, buffer, renderer)

      assert html =~ "Hello"
      assert html =~ ~s(<div class="cell">)
    end

    test "renders row in scrollback" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ScreenBuffer.write_char(buffer, "Line 1\nLine 2")
      row = List.first(buffer.scrollback)
      renderer = Renderer.new()
      html = Renderer.render_row(row, 0, buffer, renderer)

      assert html =~ "Line 1"
      assert html =~ ~s(<div class="row scrollback">)
    end

    test "batches cells for better performance" do
      buffer = ScreenBuffer.new(80, 24)
      buffer = ScreenBuffer.write_char(buffer, String.duplicate("A", 80))
      row = List.first(buffer.buffer)
      renderer = Renderer.new(batch_size: 20)
      html = Renderer.render_row(row, 0, buffer, renderer)

      # Should have 4 batches of 20 cells each
      assert length(String.split(html, "batch")) == 5
    end
  end

  describe "render_cell/4" do
    test "renders empty cell" do
      buffer = ScreenBuffer.new(80, 24)
      cell = Cell.new(" ")
      renderer = Renderer.new()
      html = Renderer.render_cell(cell, 0, 0, renderer)

      assert html =~ ~s(<div class="cell">)
      assert html =~ ~s(data-x="0">)
      assert html =~ ~s(data-y="0">)
    end

    test "renders cell with content" do
      cell = Cell.new("A")
      renderer = Renderer.new()
      html = Renderer.render_cell(cell, 0, 0, renderer)

      assert html =~ "A"
      assert html =~ ~s(<div class="cell">)
    end

    test "renders cell with styles" do
      cell = Cell.new("A", %{foreground: :red, background: :black})
      renderer = Renderer.new()
      html = Renderer.render_cell(cell, 0, 0, renderer)

      assert html =~ ~s(style="color: #cd0000; background-color: #000000;">)
    end

    test "renders cell with custom styles" do
      cell = Cell.new("A", %{foreground: "#ff0000", background: "#000000"})
      renderer = Renderer.new()
      html = Renderer.render_cell(cell, 0, 0, renderer)

      assert html =~ ~s(style="color: #ff0000; background-color: #000000;">)
    end

    test "renders cell with 256-color mode" do
      buffer = ScreenBuffer.new(80, 24)
      cell = Cell.new("A", %{foreground: 196}) # Bright red
      renderer = Renderer.new()
      html = Renderer.render_cell(cell, 0, 0, renderer)

      assert html =~ ~s(color: rgb(255, 0, 0))
    end

    test "renders cell with RGB color" do
      buffer = ScreenBuffer.new(80, 24)
      cell = Cell.new("A", %{foreground: {255, 0, 0}})
      renderer = Renderer.new()
      html = Renderer.render_cell(cell, 0, 0, renderer)

      assert html =~ ~s(color: rgb(255, 0, 0))
    end

    test "uses theme colors" do
      buffer = ScreenBuffer.new(80, 24)
      cell = Cell.new("A", %{foreground: :red})
      theme = %{red: "#ff0000"}
      renderer = Renderer.new(theme: theme)
      html = Renderer.render_cell(cell, 0, 0, renderer)

      assert html =~ ~s(color: #ff0000)
    end
  end

  describe "set_theme/2" do
    test "sets theme colors" do
      renderer = Renderer.new()
      theme = %{
        background: "#111111",
        foreground: "#eeeeee",
        red: "#ff0000"
      }

      renderer = Renderer.set_theme(renderer, theme)

      assert renderer.theme.background == "#111111"
      assert renderer.theme.foreground == "#eeeeee"
      assert renderer.theme.red == "#ff0000"
      assert renderer.theme.green == "#00cd00" # Default value preserved
    end
  end

  describe "set_font/4" do
    test "sets font settings" do
      renderer = Renderer.new()
      renderer = Renderer.set_font(renderer, "Courier New", 16, 1.5)

      assert renderer.font_family == "Courier New"
      assert renderer.font_size == 16
      assert renderer.line_height == 1.5
    end
  end

  describe "set_cursor/4" do
    test "sets cursor settings" do
      renderer = Renderer.new()
      renderer = Renderer.set_cursor(renderer, :underline, false, "#ff0000")

      assert renderer.cursor_style == :underline
      assert renderer.cursor_blink == false
      assert renderer.cursor_color == "#ff0000"
    end
  end

  describe "set_performance/5" do
    test "sets performance settings" do
      renderer = Renderer.new()
      renderer = Renderer.set_performance(renderer, 200, 500, false, 30)

      assert renderer.batch_size == 200
      assert renderer.scrollback_limit == 500
      assert renderer.virtual_scroll == false
      assert renderer.visible_rows == 30
    end
  end
end
