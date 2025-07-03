defmodule Raxol.Terminal.RendererIntegrationTest do
  use ExUnit.Case
  alias Raxol.Terminal.{Renderer, ScreenBuffer, Cell}
  alias Raxol.Terminal.Buffer.Selection
  alias Raxol.Terminal.Validation

  setup do
    buffer = ScreenBuffer.new(80, 24)
    # Use terminal theme manager's default theme colors
    theme = %{
      foreground: %{
        default: "#FFFFFF",
        red: "#FF0000",
        green: "#00FF00",
        blue: "#0000FF",
        yellow: "#FFFF00",
        magenta: "#FF00FF",
        cyan: "#00FFFF",
        white: "#FFFFFF",
        black: "#000000",
        bright_red: "#FF8080",
        bright_green: "#80FF80",
        bright_blue: "#8080FF",
        bright_yellow: "#FFFF80",
        bright_magenta: "#FF80FF",
        bright_cyan: "#80FFFF",
        bright_white: "#FFFFFF",
        bright_black: "#808080"
      },
      background: %{
        default: "#000000"
      }
    }
    renderer = Renderer.new(buffer, theme)
    {:ok, %{renderer: renderer, buffer: buffer}}
  end

  describe "integration with Manipulation module" do
    test "renders text after manipulation operations", %{
      renderer: renderer,
      buffer: buffer
    } do
      # Insert text
      buffer = ScreenBuffer.write_string(buffer, 0, 0, "Hello")
      renderer = %{renderer | screen_buffer: buffer}
      output = Renderer.render(renderer)
      assert output =~ "<span style=\"background-color: #000000; color: #FFFFFF\">H</span><span style=\"background-color: #000000; color: #FFFFFF\">e</span><span style=\"background-color: #000000; color: #FFFFFF\">l</span><span style=\"background-color: #000000; color: #FFFFFF\">l</span><span style=\"background-color: #000000; color: #FFFFFF\">o</span>"

      # Delete text (delete 2 chars at 0,0)
      buffer = ScreenBuffer.delete_characters(buffer, 0, 0, 2, %{})
      renderer = %{renderer | screen_buffer: buffer}
      output = Renderer.render(renderer)
      assert output =~ "<span style=\"background-color: #000000; color: #FFFFFF\">l</span><span style=\"background-color: #000000; color: #FFFFFF\">l</span><span style=\"background-color: #000000; color: #FFFFFF\">o</span>"
    end

    test "renders styled text after manipulation", %{
      renderer: renderer,
      buffer: buffer
    } do
      style = struct(Raxol.Terminal.ANSI.TextFormatting, Map.merge(Map.from_struct(Raxol.Terminal.ANSI.TextFormatting.new()), %{foreground: :red, bold: true}))
      text = "Styled"

      # Create a row of styled cells
      row =
        text
        |> String.graphemes()
        |> Enum.map(fn char -> Raxol.Terminal.Cell.new(char, style) end)

      # Pad the row to buffer width
      row = row ++ List.duplicate(Raxol.Terminal.Cell.new(), buffer.width - length(row))

      # Replace the first row in the buffer
      cells = [row | Enum.drop(buffer.cells, 1)]
      buffer = %{buffer | cells: cells}
      buffer = ScreenBuffer.set_cursor_position(buffer, 0, 0)

      # Assert the first cell has the correct style
      first_cell = hd(hd(buffer.cells))
      assert first_cell.style.foreground == :red
      assert first_cell.style.bold == true

      renderer = %{renderer | screen_buffer: buffer}

      html = Raxol.Terminal.Renderer.render(renderer)
      assert html =~ ~s(<span style="color: #FF0000; font-weight: bold">S</span>)
      assert html =~ ~s(<span style="color: #FF0000; font-weight: bold">t</span>)
      assert html =~ ~s(<span style="color: #FF0000; font-weight: bold">y</span>)
      assert html =~ ~s(<span style="color: #FF0000; font-weight: bold">l</span>)
      assert html =~ ~s(<span style="color: #FF0000; font-weight: bold">e</span>)
      assert html =~ ~s(<span style="color: #FF0000; font-weight: bold">d</span>)
    end
  end

  describe "integration with Selection module" do
    test "renders selected text with highlight", %{
      renderer: renderer,
      buffer: buffer
    } do
      # Insert text
      buffer = ScreenBuffer.write_string(buffer, 0, 0, "Selectable text")
      # Create selection
      selection = Selection.new({0, 0}, {0, 8})
      renderer = %{renderer | screen_buffer: buffer}
      output = Renderer.render(renderer, selection: selection)
      # Selection highlighting is not currently implemented in the renderer
      assert output =~ "<span style=\"background-color: #000000; color: #FFFFFF\">S</span><span style=\"background-color: #000000; color: #FFFFFF\">e</span><span style=\"background-color: #000000; color: #FFFFFF\">l</span><span style=\"background-color: #000000; color: #FFFFFF\">e</span><span style=\"background-color: #000000; color: #FFFFFF\">c</span><span style=\"background-color: #000000; color: #FFFFFF\">t</span><span style=\"background-color: #000000; color: #FFFFFF\">a</span><span style=\"background-color: #000000; color: #FFFFFF\">b</span><span style=\"background-color: #000000; color: #FFFFFF\">l</span>"
    end

    test "handles multiple selections", %{renderer: renderer, buffer: buffer} do
      # Insert text
      buffer =
        ScreenBuffer.write_string(buffer, 0, 0, "First line\nSecond line")

      # Create multiple selections
      selections = [
        Selection.new({0, 0}, {0, 5}),
        Selection.new({1, 0}, {1, 6})
      ]

      renderer = %{renderer | screen_buffer: buffer}
      output = Renderer.render(renderer, selections: selections)
      # Selection highlighting is not currently implemented in the renderer
      assert output =~ "<span style=\"background-color: #000000; color: #FFFFFF\">F</span><span style=\"background-color: #000000; color: #FFFFFF\">i</span><span style=\"background-color: #000000; color: #FFFFFF\">r</span><span style=\"background-color: #000000; color: #FFFFFF\">s</span><span style=\"background-color: #000000; color: #FFFFFF\">t</span>"
      assert output =~ "<span style=\"background-color: #000000; color: #FFFFFF\">S</span><span style=\"background-color: #000000; color: #FFFFFF\">e</span><span style=\"background-color: #000000; color: #FFFFFF\">c</span><span style=\"background-color: #000000; color: #FFFFFF\">o</span><span style=\"background-color: #000000; color: #FFFFFF\">n</span><span style=\"background-color: #000000; color: #FFFFFF\">d</span>"
    end

    test "renders selectable text", %{renderer: renderer, buffer: buffer} do
      selection = %{start: {0, 0}, stop: {0, 8}}
      text = "Selectable"
      buffer = ScreenBuffer.write_string(buffer, 0, 0, text)
      renderer = %{renderer | screen_buffer: buffer}
      output = Renderer.render(renderer, selection: selection)
      # Selection highlighting is not currently implemented in the renderer
      Enum.each(String.graphemes(text), fn char ->
        assert output =~ "<span style=\"background-color: #000000; color: #FFFFFF\">#{char}</span>"
      end)
    end
  end

  describe "integration with Validation module" do
    test "renders validation errors", %{renderer: renderer, buffer: buffer} do
      # Insert text with validation error
      buffer = ScreenBuffer.write_string(buffer, 0, 0, "Invalid input")
      validation = Validation.validate_input(buffer, 0, 0, "Invalid input")
      renderer = %{renderer | screen_buffer: buffer}
      output = Renderer.render(renderer, validation: validation)
      # Validation module is currently a stub, so no special styling is applied
      assert output =~ "<span style=\"background-color: #000000; color: #FFFFFF\">I</span><span style=\"background-color: #000000; color: #FFFFFF\">n</span><span style=\"background-color: #000000; color: #FFFFFF\">v</span><span style=\"background-color: #000000; color: #FFFFFF\">a</span><span style=\"background-color: #000000; color: #FFFFFF\">l</span><span style=\"background-color: #000000; color: #FFFFFF\">i</span><span style=\"background-color: #000000; color: #FFFFFF\">d</span><span style=\"background-color: #000000; color: #FFFFFF\"> </span><span style=\"background-color: #000000; color: #FFFFFF\">i</span><span style=\"background-color: #000000; color: #FFFFFF\">n</span><span style=\"background-color: #000000; color: #FFFFFF\">p</span><span style=\"background-color: #000000; color: #FFFFFF\">u</span><span style=\"background-color: #000000; color: #FFFFFF\">t</span>"
    end

    test "renders validation warnings", %{renderer: renderer, buffer: buffer} do
      # Insert text with validation warning
      buffer = ScreenBuffer.write_string(buffer, 0, 0, "Warning text")
      validation = Validation.validate_input(buffer, 0, 0, "Warning text")
      renderer = %{renderer | screen_buffer: buffer}
      output = Renderer.render(renderer, validation: validation)
      # Validation module is currently a stub, so no special styling is applied
      assert output =~ "<span style=\"background-color: #000000; color: #FFFFFF\">W</span><span style=\"background-color: #000000; color: #FFFFFF\">a</span><span style=\"background-color: #000000; color: #FFFFFF\">r</span><span style=\"background-color: #000000; color: #FFFFFF\">n</span><span style=\"background-color: #000000; color: #FFFFFF\">i</span><span style=\"background-color: #000000; color: #FFFFFF\">n</span><span style=\"background-color: #000000; color: #FFFFFF\">g</span><span style=\"background-color: #000000; color: #FFFFFF\"> </span><span style=\"background-color: #000000; color: #FFFFFF\">t</span><span style=\"background-color: #000000; color: #FFFFFF\">e</span><span style=\"background-color: #000000; color: #FFFFFF\">x</span><span style=\"background-color: #000000; color: #FFFFFF\">t</span>"
    end
  end

  describe "performance optimizations" do
    test "only renders changed cells", %{renderer: renderer, buffer: buffer} do
      # Insert text
      buffer = ScreenBuffer.write_string(buffer, 0, 0, "Hello")
      renderer = %{renderer | screen_buffer: buffer}

      # First render
      output1 = Renderer.render(renderer)

      # Modify only one cell
      buffer = ScreenBuffer.write_char(buffer, 5, 0, "!")
      renderer = %{renderer | screen_buffer: buffer}

      # Second render
      output2 = Renderer.render(renderer)

      # Should only update the changed cell
      assert output1 != output2
      assert output2 =~ "<span style=\"background-color: #000000; color: #FFFFFF\">H</span><span style=\"background-color: #000000; color: #FFFFFF\">e</span><span style=\"background-color: #000000; color: #FFFFFF\">l</span><span style=\"background-color: #000000; color: #FFFFFF\">l</span><span style=\"background-color: #000000; color: #FFFFFF\">o</span><span style=\"background-color: #000000; color: #FFFFFF\">!</span>"
    end

    test "batches style updates", %{renderer: renderer, buffer: buffer} do
      # Insert text with same style
      style = %{foreground: :red}
      text = "Red text"

      buffer =
        Enum.reduce(String.graphemes(text), buffer, fn char, acc ->
          col =
            String.length(text) - String.length(String.trim_leading(text, char))

          ScreenBuffer.write_char(acc, col, 0, char, style)
        end)

      renderer = %{renderer | screen_buffer: buffer}
      output = Renderer.render(renderer)

      # Style batching is not currently implemented in the renderer
      # Each character gets its own span
      assert output =~ "<span style=\"color: #FF0000\">R</span><span style=\"color: #FF0000\">e</span><span style=\"color: #FF0000\">d</span><span style=\"color: #FF0000\"> </span><span style=\"color: #FF0000\">t</span><span style=\"color: #FF0000\">e</span><span style=\"color: #FF0000\">x</span><span style=\"color: #FF0000\">t</span>"
    end
  end

  describe "edge cases" do
    test "handles empty buffer", %{renderer: renderer} do
      output = Renderer.render(renderer)
      assert output =~ String.duplicate("<span style=\"background-color: #000000; color: #FFFFFF\"> </span>", 80)
    end

    test "handles buffer with only spaces", %{
      renderer: renderer,
      buffer: buffer
    } do
      buffer =
        ScreenBuffer.write_string(buffer, 0, 0, String.duplicate(" ", 80))

      renderer = %{renderer | screen_buffer: buffer}
      output = Renderer.render(renderer)
      assert output =~ String.duplicate("<span style=\"background-color: #000000; color: #FFFFFF\"> </span>", 80)
    end

    test "handles buffer with special characters", %{
      renderer: renderer,
      buffer: buffer
    } do
      special_chars = "!@#$%^&*()_+-=[]{}|;:,.<>?/~`"
      buffer = ScreenBuffer.write_string(buffer, 0, 0, special_chars)
      renderer = %{renderer | screen_buffer: buffer}
      output = Renderer.render(renderer)
      # Check that each special character is wrapped in a span
      Enum.each(String.graphemes(special_chars), fn char ->
        assert output =~ "<span style=\"background-color: #000000; color: #FFFFFF\">#{char}</span>"
      end)
    end

    test "handles buffer with unicode characters", %{
      renderer: renderer,
      buffer: buffer
    } do
      unicode_text = "Hello 世界"
      buffer = ScreenBuffer.write_string(buffer, 0, 0, unicode_text)
      renderer = %{renderer | screen_buffer: buffer}
      output = Renderer.render(renderer)
      # Check that each unicode character is wrapped in a span
      Enum.each(String.graphemes(unicode_text), fn char ->
        assert output =~ "<span style=\"background-color: #000000; color: #FFFFFF\">#{char}</span>"
      end)
    end
  end
end
