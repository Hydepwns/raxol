defmodule Raxol.UI.Components.Input.MultiLineInput.RenderHelperTest do
  use ExUnit.Case, async: true

  # @tag :skip # Skip: Tests call RenderHelper.render_view/2 which does not exist
  alias Raxol.UI.Components.Input.MultiLineInput
  alias Raxol.UI.Components.Input.MultiLineInput.RenderHelper
  # alias Raxol.UI.Style
  # alias Raxol.Terminal.Cell

  # Helper to create a minimal state for testing
  defp create_state(
         lines,
         cursor_pos,
         scroll_offset \\ {0, 0},
         selection \\ nil,
         show_line_numbers \\ false
       ) do
    sel_start = if selection, do: elem(selection, 0), else: nil
    sel_end = if selection, do: elem(selection, 1), else: nil

    %Raxol.UI.Components.Input.MultiLineInput{
      lines: lines,
      cursor_pos: cursor_pos,
      selection_start: sel_start,
      selection_end: sel_end,
      scroll_offset: scroll_offset,
      theme: mock_theme(),
      id: "test_input"
      # Add other required fields if RenderHelper depends on them
      # value: Enum.join(lines, "\n"), # Might be needed if helpers rely on it
      # theme: test_theme(%{...}) # Add a mock theme if needed
    }
  end

  # Helper to create a mock theme
  defp mock_theme do
    %Raxol.UI.Theming.Theme{
      component_styles: %{
        multi_line_input: %{
          text_color: :cyan,
          selection_color: :magenta,
          line_number_color: :yellow
        }
        # Add other component styles if needed by RenderHelper
      },
      # Add other theme fields if needed
      colors: %{foreground: :white, background: :black}
    }
  end

  # Helper to extract style from attrs (handles both map and keyword list)
  defp extract_style(attrs) do
    cond do
      is_list(attrs) -> Keyword.get(attrs, :style)
      is_map(attrs) -> Map.get(attrs, :style)
      true -> nil
    end
  end

  # Helper to assert rendered line segments and styles
  defp assert_rendered_segments(result, expected) do
    Enum.zip(result, expected)
    |> Enum.each(fn {seg, {content, style}} ->
      assert seg.content == content
      assert extract_style(seg.attrs) == style
    end)
  end

  describe "Render Helper Functions" do
    test "render_line/4 applies default style" do
      state = create_state(["hi"], {1, 1})
      line_index = 0
      line_content = "hi"
      theme = %{
        components: %{
          multi_line_input: %{
            text_style: %{color: :white}
          }
        }
      }
      rendered = RenderHelper.render_line(line_index, line_content, state, theme)
      assert Enum.at(rendered, 0).content == "hi"
      assert extract_style(Enum.at(rendered, 0).attrs) == %{color: :white}
    end

    # Remove or update all tests that use render_line/3 or expect .style on state
    # The following tests are now commented out or marked for rewrite:
    # test "render_line/3 applies default style" ...
    # test "applies selection style from component theme" ...
    # test "applies cursor style from component theme (overrides selection)" ...
    # test "handles scroll offset correctly" ...
    # test "render_line/3 applies selection style from component theme" ...
    # test "render_line/3 applies cursor style when focused and no selection" ...
    # These are replaced by the edge-case tests below.
  end

  describe "render_line/4 edge cases" do
    setup do
      # Minimal theme for direct style mapping
      theme = %{
        components: %{
          multi_line_input: %{
            selection_style: %{background: :blue},
            cursor_style: %{background: :red},
            text_style: %{color: :white}
          }
        }
      }
      %{theme: theme}
    end

    test "cursor at start of line", %{theme: theme} do
      state = create_state(["abc"], {0, 0}) |> Map.put(:focused, true)
      line = "abc"
      result = Raxol.UI.Components.Input.MultiLineInput.RenderHelper.render_line(0, line, state, theme)
      # Should render: [cursor 'a', 'bc']
      assert Enum.at(result, 0).content == "a"
      assert extract_style(Enum.at(result, 0).attrs) == %{background: :red}
      assert Enum.at(result, 1).content == "bc"
    end

    test "cursor at end of line", %{theme: theme} do
      state = create_state(["abc"], {0, 3}) |> Map.put(:focused, true)
      line = "abc"
      result = Raxol.UI.Components.Input.MultiLineInput.RenderHelper.render_line(0, line, state, theme)
      # Should render: ["abc"] (no cursor, since it's after the end)
      assert Enum.count(result) == 1
      assert Enum.at(result, 0).content == "abc"
    end

    test "selection within single line", %{theme: theme} do
      state = create_state(["abcdef"], {0, 0}, {0, 0}, {{0, 1}, {0, 3}})
      line = "abcdef"
      result = Raxol.UI.Components.Input.MultiLineInput.RenderHelper.render_line(0, line, state, theme)
      assert Enum.at(result, 0).content == "a"
      assert Enum.at(result, 1).content == "bc"
      assert extract_style(Enum.at(result, 1).attrs) == %{background: :blue}
      assert Enum.at(result, 2).content == "def"
    end

    test "selection across multiple lines, only highlights this line's part", %{theme: theme} do
      state = create_state(["abcdef"], {1, 0}, {0, 0}, {{0, 2}, {2, 1}})
      line = "abcdef"
      # This is line 0, so selection from col 2 to end
      result = Raxol.UI.Components.Input.MultiLineInput.RenderHelper.render_line(0, line, state, theme)
      assert Enum.at(result, 0).content == "ab"
      assert extract_style(Enum.at(result, 0).attrs)[:background] == :blue
      assert Enum.at(result, 1).content == "cdef"
    end

    test "empty line with cursor", %{theme: theme} do
      state = create_state([""], {0, 0}) |> Map.put(:focused, true)
      line = ""
      result = Raxol.UI.Components.Input.MultiLineInput.RenderHelper.render_line(0, line, state, theme)
      # Should render nothing or a single label with empty content
      # NOTE: This test may fail if implementation does not handle empty lines gracefully
      assert Enum.count(result) == 0 or Enum.at(result, 0).content == ""
    end

    test "out-of-bounds cursor/selection does not crash", %{theme: theme} do
      state = create_state(["abc"], {0, 10}, {0, 0}, {{0, 20}, {0, 25}}) |> Map.put(:focused, true)
      line = "abc"
      result = Raxol.UI.Components.Input.MultiLineInput.RenderHelper.render_line(0, line, state, theme)
      # Should not raise, should render the line as-is
      # NOTE: This test may fail if implementation does not guard against out-of-bounds
      assert Enum.at(result, 0).content == "abc"
    end

    test "selection within single line, inspect second label", %{theme: theme} do
      state = create_state(["abcdef"], {0, 0}, {0, 0}, {{0, 1}, {0, 3}})
      line = "abcdef"
      result = Raxol.UI.Components.Input.MultiLineInput.RenderHelper.render_line(0, line, state, theme)
      assert_rendered_segments(result, [
        {"a", nil},
        {"bc", %{background: :blue}},
        {"def", nil}
      ])
    end
  end
end
