defmodule Raxol.UI.Components.Input.MultiLineInput.RenderHelperTest do
  use ExUnit.Case, async: true
  alias Raxol.UI.Components.Input.MultiLineInput
  alias Raxol.UI.Components.Input.MultiLineInput.RenderHelper

  # Test render_view/2 which should now be render/3
  test "render_visible_lines/1 applies default style" do
    state = create_state(lines: ["hi"])
    theme = default_theme()
    # Call render/3 with state, theme
    cells = RenderHelper.render(state, %{}, theme)

    # Assertions focus on the first line, first cell
    # ... existing code ...
  end

  test "render_visible_lines/1 applies selection style from component theme" do
    state =
      create_state(
        lines: ["hello"],
        selection_start: {0, 1},
        selection_end: {0, 3},
        cursor_pos: {0, 4}
      )

    theme = theme_with_component_style()
    # Call render/3 with state, theme
    cells = RenderHelper.render(state, %{}, theme)

    # Cell 0,0 should have default style
    # ... existing code ...
  end

  test "render_visible_lines/1 applies cursor style from component theme (overrides selection)" do
    state =
      create_state(
        lines: ["hello"],
        selection_start: {0, 1},
        selection_end: {0, 3},
        cursor_pos: {0, 2}
      )

    theme = theme_with_component_style()
    # Call render/3 with state, theme
    cells = RenderHelper.render(state, %{}, theme)

    # Cell 0,2 (cursor pos) should have cursor style
    # ... existing code ...
  end

  test "render_visible_lines/1 handles scroll offset correctly" do
    state =
      create_state(
        lines: ["line 0", "line 1", "line 2", "line 3"],
        scroll_offset: {1, 0},
        cursor_pos: {2, 1}
      )

    theme = theme_with_component_style()
    # Call render/3 with state, theme
    cells = RenderHelper.render(state, %{}, theme)

    # Check number of lines rendered matches height
    # ... existing code ...
  end

  # Helper function to create default state
  defp create_state(opts \\ []) do
    # Start with a default state
    state = %Raxol.UI.Components.Input.MultiLineInput{
      value: "",
      placeholder: "",
      width: 40,
      height: 10,
      theme: %{},
      wrap: :word,
      cursor_pos: {0, 0},
      scroll_offset: {0, 0},
      selection_start: nil,
      selection_end: nil,
      history: %Raxol.Terminal.Commands.History{
        commands: [],
        current_index: -1,
        max_size: 100,
        current_input: ""
      },
      shift_held: false,
      focused: false,
      on_change: nil,
      id: "test_input",
      lines: [""]
    }

    # Apply each option from the provided opts list
    Enum.reduce(opts, state, fn {key, value}, acc ->
      Map.put(acc, key, value)
    end)
  end

  # Helper function to create default theme
  defp default_theme do
    %{
      components: %{
        multi_line_input: %{
          text_color: :white,
          selection_color: :blue,
          cursor_color: :white
        }
      }
    }
  end

  # Helper function to create theme with component style
  defp theme_with_component_style do
    %{
      components: %{
        multi_line_input: %{
          text_color: :green,
          selection_color: :blue,
          cursor_color: :red
        }
      }
    }
  end
end
