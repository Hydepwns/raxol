defmodule Raxol.UI.Components.Input.MultiLineInput.RenderHelperTest do
  use ExUnit.Case, async: true

  alias Raxol.Components.Input.MultiLineInput
  alias Raxol.Components.Input.MultiLineInput.RenderHelper
  alias Raxol.UI.Style
  alias Raxol.Terminal.Cell

  # Helper to create a minimal state for testing
  defp create_state(lines, cursor_pos, scroll_offset \\ {0, 0}, selection \\ nil, show_line_numbers \\ false) do
    sel_start = if selection, do: elem(selection, 0), else: nil
    sel_end = if selection, do: elem(selection, 1), else: nil

    %MultiLineInput{
      lines: lines,
      cursor_pos: cursor_pos,
      selection_start: sel_start,
      selection_end: sel_end,
      scroll_offset: scroll_offset,
      style: %{
        text_color: :white,
        placeholder_color: :gray,
        selection_color: :blue,
        cursor_color: :white,
        line_numbers: false, # Default
        line_number_color: :gray
      } |> Map.put(:line_numbers, show_line_numbers),
      id: "test_input"
      # Add other required fields if RenderHelper depends on them
      # value: Enum.join(lines, "\n"), # Might be needed if helpers rely on it
      # theme: %Raxol.UI.Theming.Theme{...} # Add a mock theme if needed
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

  describe "render_visible_lines/1" do
    test "renders visible lines within dimensions" do
      state = create_state(["line 0", "line 1", "line 2", "line 3"], {1, 2}, {0, 0}, {8, 3}) # 8x3 viewport
      theme = mock_theme()
      cells = RenderHelper.render_view(state, theme)

      # Expect 3 lines (height) of 8 cells each (width)
      assert length(cells) == 3
      assert Enum.all?(cells, fn row -> length(row) == 8 end)

      # Check content of the first visible line ("line 0")
      first_line_content = Enum.map(cells |> Enum.at(0) |> Enum.take(6), & &1.char) |> to_string()
      assert first_line_content == "line 0"

      # Check padding for the first line
      assert Enum.at(cells, 0) |> Enum.at(6) == Cell.new(" ")
      assert Enum.at(cells, 0) |> Enum.at(7) == Cell.new(" ")


      # Check content of the second visible line ("line 1")
      second_line_content = Enum.map(cells |> Enum.at(1) |> Enum.take(6), & &1.char) |> to_string()
      assert second_line_content == "line 1"

    end

    test "applies default style" do
       state = create_state(["hi"], {0, 0}, {0, 0}, {5, 1})
       theme = mock_theme()
       cells = RenderHelper.render_view(state, theme)
       default_style = Map.get(theme.styles, :default)

       assert Enum.at(cells, 0) |> Enum.at(0) |> Map.get(:style) == default_style
       assert Enum.at(cells, 0) |> Enum.at(1) |> Map.get(:style) == default_style
       # Check padding style
       assert Enum.at(cells, 0) |> Enum.at(2) |> Map.get(:style) == default_style
    end

    test "applies selection style from component theme" do
       state = create_state(["hello"], {0, 4}, {0, 0}, {5, 1}, {{0, 1}, {0, 3}}) # Select "ell"
       theme = mock_theme()
       cells = RenderHelper.render_view(state, theme)
       selection_style = theme.component_styles["MultiLineInput"].selection

       # 'h' (not selected)
       assert Enum.at(cells, 0) |> Enum.at(0) |> Map.get(:style) != selection_style
       # 'e', 'l', 'l' (selected)
       assert Enum.at(cells, 0) |> Enum.at(1) |> Map.get(:style) == selection_style
       assert Enum.at(cells, 0) |> Enum.at(2) |> Map.get(:style) == selection_style
       assert Enum.at(cells, 0) |> Enum.at(3) |> Map.get(:style) == selection_style
       # 'o' (not selected)
       assert Enum.at(cells, 0) |> Enum.at(4) |> Map.get(:style) != selection_style
    end

     test "applies cursor style from component theme (overrides selection)" do
       # Cursor at {0, 2} ('l'), selection {0, 1} to {0, 3} ("ell")
       state = create_state(["hello"], {0, 2}, {0, 0}, {5, 1}, {{0, 1}, {0, 3}})
       theme = mock_theme()
       cells = RenderHelper.render_view(state, theme)
       cursor_style = theme.component_styles["MultiLineInput"].cursor
       selection_style = theme.component_styles["MultiLineInput"].selection

       # 'h'
       assert Enum.at(cells, 0) |> Enum.at(0) |> Map.get(:style) != cursor_style
       assert Enum.at(cells, 0) |> Enum.at(0) |> Map.get(:style) != selection_style
       # 'e' (selected only)
       assert Enum.at(cells, 0) |> Enum.at(1) |> Map.get(:style) == selection_style
       assert Enum.at(cells, 0) |> Enum.at(1) |> Map.get(:style) != cursor_style
       # 'l' (cursor position, should have cursor style)
       assert Enum.at(cells, 0) |> Enum.at(2) |> Map.get(:style) == cursor_style
       # 'l' (selected only)
       assert Enum.at(cells, 0) |> Enum.at(3) |> Map.get(:style) == selection_style
       assert Enum.at(cells, 0) |> Enum.at(3) |> Map.get(:style) != cursor_style
        # 'o'
       assert Enum.at(cells, 0) |> Enum.at(4) |> Map.get(:style) != cursor_style
       assert Enum.at(cells, 0) |> Enum.at(4) |> Map.get(:style) != selection_style

     end

    test "handles scroll offset correctly" do
      state = create_state(["line 0", "line 1", "line 2", "line 3"], {2, 1}, {1, 0}, {8, 2}) # Scroll down 1 line
      theme = mock_theme()
      cells = RenderHelper.render_view(state, theme)

      # Viewport is 8x2, scroll offset is {1, 0}
      # Should render lines 1 and 2

      assert length(cells) == 2 # Height

      # Check content of the first visible line (should be "line 1")
      first_line_content = Enum.map(cells |> Enum.at(0) |> Enum.take(6), & &1.char) |> to_string()
      assert first_line_content == "line 1"

       # Check content of the second visible line (should be "line 2")
      second_line_content = Enum.map(cells |> Enum.at(1) |> Enum.take(6), & &1.char) |> to_string()
      assert second_line_content == "line 2"

      # Cursor is at {2, 1} (relative to document), which is {1, 1} relative to viewport start (due to scroll)
      # Check cursor style at cell {1, 1} in the output grid
       cursor_style = theme.component_styles["MultiLineInput"].cursor
       assert Enum.at(cells, 1) |> Enum.at(1) |> Map.get(:style) == cursor_style

    end

    # TODO: Add tests for horizontal scroll offset
    # TODO: Add tests for line wrapping (if applicable to RenderHelper)
    # TODO: Add tests for edge cases (empty lines, empty document)
  end

end
