defmodule Raxol.Terminal.RendererIntegrationTest do
  use ExUnit.Case
  alias Raxol.Terminal.{Renderer, ScreenBuffer, Cell}
  alias Raxol.Terminal.Buffer.Selection
  alias Raxol.Terminal.Validation

  setup do
    buffer = ScreenBuffer.new(80, 24)
    renderer = Renderer.new(buffer)
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
      assert output =~ "Hello"

      # Delete text (delete 2 chars at 0,0)
      buffer = ScreenBuffer.delete_characters(buffer, 0, 0, 2, %{})
      renderer = %{renderer | screen_buffer: buffer}
      output = Renderer.render(renderer)
      assert output =~ "llo"
    end

    test "renders styled text after manipulation", %{
      renderer: renderer,
      buffer: buffer
    } do
      style = %{foreground: :red, bold: true}
      # Write each char with style
      text = "Styled"

      buffer =
        Enum.reduce(String.graphemes(text), buffer, fn char, acc ->
          col =
            String.length(text) - String.length(String.trim_leading(text, char))

          ScreenBuffer.write_char(acc, col, 0, char, style)
        end)

      renderer = %{renderer | screen_buffer: buffer}
      output = Renderer.render(renderer)
      assert output =~ "Styled"
      assert output =~ "color: #FF0000"
      assert output =~ "font-weight: bold"
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
      assert output =~ "Selectable"
      assert output =~ "background-color: #0000FF"
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
      assert output =~ "First"
      assert output =~ "Second"
    end
  end

  describe "integration with Validation module" do
    test "renders validation errors", %{renderer: renderer, buffer: buffer} do
      # Insert text with validation error
      buffer = ScreenBuffer.write_string(buffer, 0, 0, "Invalid input")
      validation = Validation.validate_input(buffer, 0, 0, "Invalid input")
      renderer = %{renderer | screen_buffer: buffer}
      output = Renderer.render(renderer, validation: validation)
      assert output =~ "Invalid input"
      assert output =~ "color: #FF0000"
    end

    test "renders validation warnings", %{renderer: renderer, buffer: buffer} do
      # Insert text with validation warning
      buffer = ScreenBuffer.write_string(buffer, 0, 0, "Warning text")
      validation = Validation.validate_input(buffer, 0, 0, "Warning text")
      renderer = %{renderer | screen_buffer: buffer}
      output = Renderer.render(renderer, validation: validation)
      assert output =~ "Warning text"
      assert output =~ "color: #FFA500"
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
      assert output2 =~ "Hello!"
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

      # Should use a single style span for consecutive cells with same style
      assert output =~ "<span style=\"color: #FF0000\">Red text</span>"
    end
  end

  describe "edge cases" do
    test "handles empty buffer", %{renderer: renderer} do
      output = Renderer.render(renderer)
      assert output =~ String.duplicate("<span style=\"\"> </span>", 80)
    end

    test "handles buffer with only spaces", %{
      renderer: renderer,
      buffer: buffer
    } do
      buffer =
        ScreenBuffer.write_string(buffer, 0, 0, String.duplicate(" ", 80))

      renderer = %{renderer | screen_buffer: buffer}
      output = Renderer.render(renderer)
      assert output =~ String.duplicate("<span style=\"\"> </span>", 80)
    end

    test "handles buffer with special characters", %{
      renderer: renderer,
      buffer: buffer
    } do
      special_chars = "!@#$%^&*()_+-=[]{}|;:,.<>?/~`"
      buffer = ScreenBuffer.write_string(buffer, 0, 0, special_chars)
      renderer = %{renderer | screen_buffer: buffer}
      output = Renderer.render(renderer)
      assert output =~ special_chars
    end

    test "handles buffer with unicode characters", %{
      renderer: renderer,
      buffer: buffer
    } do
      unicode_text = "Hello 世界"
      buffer = ScreenBuffer.write_string(buffer, 0, 0, unicode_text)
      renderer = %{renderer | screen_buffer: buffer}
      output = Renderer.render(renderer)
      assert output =~ unicode_text
    end
  end
end
