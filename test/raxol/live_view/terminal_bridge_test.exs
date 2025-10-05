defmodule Raxol.LiveView.TerminalBridgeTest do
  use ExUnit.Case, async: true

  alias Raxol.Core.{Buffer, Style}
  alias Raxol.LiveView.TerminalBridge

  describe "buffer_to_html/2" do
    test "converts empty buffer to HTML" do
      buffer = Buffer.create_blank_buffer(10, 3)
      html = TerminalBridge.buffer_to_html(buffer)

      assert html =~ ~s(<pre class="raxol-terminal")
      assert html =~ ~s(role="log")
      assert html =~ ~s(aria-live="polite")
      assert html =~ ~s(</pre>)
    end

    test "converts buffer with text to HTML" do
      buffer = Buffer.create_blank_buffer(20, 5)
      buffer = Buffer.write_at(buffer, 0, 0, "Hello")

      html = TerminalBridge.buffer_to_html(buffer)

      # Each character is wrapped in a span
      assert html =~ ">H</span>"
      assert html =~ ">e</span>"
      assert html =~ ">l</span>"
      assert html =~ ">o</span>"
      assert html =~ ~s(class="raxol-cell")
    end

    test "applies theme class" do
      buffer = Buffer.create_blank_buffer(10, 3)

      html = TerminalBridge.buffer_to_html(buffer, theme: :nord)
      assert html =~ "raxol-theme-nord"

      html = TerminalBridge.buffer_to_html(buffer, theme: :dracula)
      assert html =~ "raxol-theme-dracula"
    end

    test "uses custom CSS prefix" do
      buffer = Buffer.create_blank_buffer(10, 3)
      html = TerminalBridge.buffer_to_html(buffer, css_prefix: "custom")

      assert html =~ ~s(class="custom-terminal")
      assert html =~ ~s(class="custom-line")
      assert html =~ ~s(class="custom-cell")
    end

    test "shows cursor when enabled" do
      buffer = Buffer.create_blank_buffer(10, 3)

      html =
        TerminalBridge.buffer_to_html(buffer,
          show_cursor: true,
          cursor_position: {5, 2},
          cursor_style: :block
        )

      assert html =~ "raxol-cursor"
      assert html =~ "raxol-cursor-block"
    end

    test "renders different cursor styles" do
      buffer = Buffer.create_blank_buffer(10, 3)

      html =
        TerminalBridge.buffer_to_html(buffer,
          show_cursor: true,
          cursor_position: {0, 0},
          cursor_style: :underline
        )

      assert html =~ "raxol-cursor-underline"

      html =
        TerminalBridge.buffer_to_html(buffer,
          show_cursor: true,
          cursor_position: {0, 0},
          cursor_style: :bar
        )

      assert html =~ "raxol-cursor-bar"
    end
  end

  describe "buffer_diff_to_html/3" do
    test "highlights changed cells" do
      old_buffer = Buffer.create_blank_buffer(20, 5)
      new_buffer = Buffer.write_at(old_buffer, 0, 0, "Changed")

      html = TerminalBridge.buffer_diff_to_html(old_buffer, new_buffer)

      assert html =~ "raxol-diff"
      assert html =~ "raxol-diff-changed"
    end

    test "does not highlight unchanged cells" do
      buffer = Buffer.create_blank_buffer(20, 5)
      buffer = Buffer.write_at(buffer, 0, 0, "Same")

      html = TerminalBridge.buffer_diff_to_html(buffer, buffer)

      # Should have diff container but no changed cells
      assert html =~ "raxol-diff"
      refute html =~ "raxol-diff-changed"
    end
  end

  describe "style_to_classes/2" do
    test "converts bold to CSS class" do
      style = %{bold: true}
      classes = TerminalBridge.style_to_classes(style)

      assert classes =~ "raxol-bold"
    end

    test "converts italic to CSS class" do
      style = %{italic: true}
      classes = TerminalBridge.style_to_classes(style)

      assert classes =~ "raxol-italic"
    end

    test "converts underline to CSS class" do
      style = %{underline: true}
      classes = TerminalBridge.style_to_classes(style)

      assert classes =~ "raxol-underline"
    end

    test "converts named foreground color to CSS class" do
      style = %{fg_color: :blue}
      classes = TerminalBridge.style_to_classes(style)

      assert classes =~ "raxol-fg-blue"
    end

    test "converts named background color to CSS class" do
      style = %{bg_color: :red}
      classes = TerminalBridge.style_to_classes(style)

      assert classes =~ "raxol-bg-red"
    end

    test "combines multiple style attributes" do
      style = %{bold: true, italic: true, fg_color: :green, bg_color: :black}
      classes = TerminalBridge.style_to_classes(style)

      assert classes =~ "raxol-bold"
      assert classes =~ "raxol-italic"
      assert classes =~ "raxol-fg-green"
      assert classes =~ "raxol-bg-black"
    end

    test "uses custom CSS prefix" do
      style = %{bold: true, fg_color: :blue}
      classes = TerminalBridge.style_to_classes(style, "custom")

      assert classes =~ "custom-bold"
      assert classes =~ "custom-fg-blue"
    end

    test "returns empty string for empty style" do
      style = %{}
      classes = TerminalBridge.style_to_classes(style)

      assert classes == ""
    end
  end

  describe "style_to_inline/1" do
    test "converts bold to inline style" do
      style = %{bold: true}
      inline = TerminalBridge.style_to_inline(style)

      assert inline =~ "font-weight: bold"
    end

    test "converts italic to inline style" do
      style = %{italic: true}
      inline = TerminalBridge.style_to_inline(style)

      assert inline =~ "font-style: italic"
    end

    test "converts underline to inline style" do
      style = %{underline: true}
      inline = TerminalBridge.style_to_inline(style)

      assert inline =~ "text-decoration: underline"
    end

    test "converts RGB foreground color to inline style" do
      style = %{fg_color: {255, 128, 64}}
      inline = TerminalBridge.style_to_inline(style)

      assert inline =~ "color: rgb(255, 128, 64)"
    end

    test "converts RGB background color to inline style" do
      style = %{bg_color: {64, 128, 255}}
      inline = TerminalBridge.style_to_inline(style)

      assert inline =~ "background-color: rgb(64, 128, 255)"
    end

    test "converts named foreground color to hex" do
      style = %{fg_color: :red}
      inline = TerminalBridge.style_to_inline(style)

      assert inline =~ "color: #ff0000"
    end

    test "converts named background color to hex" do
      style = %{bg_color: :blue}
      inline = TerminalBridge.style_to_inline(style)

      assert inline =~ "background-color: #0000ff"
    end

    test "converts 256-color index to RGB" do
      style = %{fg_color: 196}
      inline = TerminalBridge.style_to_inline(style)

      # Color 196 should be bright red
      assert inline =~ "color: rgb("
    end

    test "combines multiple inline styles" do
      style = %{bold: true, italic: true, fg_color: {255, 0, 0}, bg_color: {0, 0, 255}}
      inline = TerminalBridge.style_to_inline(style)

      assert inline =~ "font-weight: bold"
      assert inline =~ "font-style: italic"
      assert inline =~ "color: rgb(255, 0, 0)"
      assert inline =~ "background-color: rgb(0, 0, 255)"
    end

    test "returns empty string for empty style" do
      style = %{}
      inline = TerminalBridge.style_to_inline(style)

      assert inline == ""
    end
  end

  describe "HTML safety" do
    test "escapes HTML special characters" do
      buffer = Buffer.create_blank_buffer(20, 3)
      buffer = Buffer.write_at(buffer, 0, 0, "<script>")

      html = TerminalBridge.buffer_to_html(buffer)

      # Each character is escaped and wrapped in spans
      assert html =~ "&lt;"
      assert html =~ "&gt;"
      # Should not have raw < or > from user input
      refute html =~ "<script>"
    end

    test "escapes ampersands" do
      buffer = Buffer.create_blank_buffer(20, 3)
      buffer = Buffer.write_at(buffer, 0, 0, "A & B")

      html = TerminalBridge.buffer_to_html(buffer)

      assert html =~ "&amp;"
    end

    test "converts spaces to nbsp" do
      buffer = Buffer.create_blank_buffer(20, 3)
      buffer = Buffer.write_at(buffer, 0, 0, " ")

      html = TerminalBridge.buffer_to_html(buffer)

      assert html =~ "&nbsp;"
    end
  end

  describe "performance" do
    test "renders 80x24 buffer quickly" do
      buffer = Buffer.create_blank_buffer(80, 24)

      # Fill with some content
      buffer =
        Enum.reduce(0..23, buffer, fn y, acc ->
          Buffer.write_at(acc, 0, y, "Line #{y}")
        end)

      {time_us, _html} =
        :timer.tc(fn ->
          TerminalBridge.buffer_to_html(buffer)
        end)

      # Should be well under 16ms (16000μs) for 60fps
      assert time_us < 16000, "Rendering took #{time_us}μs (target: < 16000μs)"
    end

    test "diff rendering is efficient" do
      old_buffer = Buffer.create_blank_buffer(80, 24)

      new_buffer =
        Enum.reduce(0..23, old_buffer, fn y, acc ->
          Buffer.write_at(acc, 0, y, "Line #{y}")
        end)

      {time_us, _html} =
        :timer.tc(fn ->
          TerminalBridge.buffer_diff_to_html(old_buffer, new_buffer)
        end)

      # Diff should also be fast
      assert time_us < 16000, "Diff rendering took #{time_us}μs (target: < 16000μs)"
    end
  end
end
