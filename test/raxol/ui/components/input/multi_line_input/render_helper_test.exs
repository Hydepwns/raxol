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
  state = create_state(lines: ["hello"], selection_start: {0, 1}, selection_end: {0, 3}, cursor_pos: {0, 4})
  theme = theme_with_component_style()
  # Call render/3 with state, theme
  cells = RenderHelper.render(state, %{}, theme)

  # Cell 0,0 should have default style
  # ... existing code ...
end

test "render_visible_lines/1 applies cursor style from component theme (overrides selection)" do
  state = create_state(lines: ["hello"], selection_start: {0, 1}, selection_end: {0, 3}, cursor_pos: {0, 2})
  theme = theme_with_component_style()
  # Call render/3 with state, theme
  cells = RenderHelper.render(state, %{}, theme)

  # Cell 0,2 (cursor pos) should have cursor style
  # ... existing code ...
end

test "render_visible_lines/1 handles scroll offset correctly" do
  state = create_state(lines: ["line 0", "line 1", "line 2", "line 3"], scroll_offset: {1, 0}, cursor_pos: {2, 1})
  theme = theme_with_component_style()
  # Call render/3 with state, theme
  cells = RenderHelper.render(state, %{}, theme)

  # Check number of lines rendered matches height
  # ... existing code ...
end

# Helper function to create default state
defp create_state(opts \\ []) do
  default_opts = %{id: "test_input"}
  all_opts = Map.merge(default_opts, Keyword.to_map(opts))
  {:ok, state} = Raxol.Components.Input.MultiLineInput.init(all_opts)
  state
end

# Helper function to create default theme
defp default_theme do
  # ... existing theme setup ...
end

# Helper function to create theme with component style
defp theme_with_component_style do
  # ... existing theme setup ...
end
end
