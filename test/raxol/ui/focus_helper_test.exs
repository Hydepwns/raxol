defmodule Raxol.UI.FocusHelperTest do
  use ExUnit.Case, async: true

  alias Raxol.UI.FocusHelper

  describe "focused?/2" do
    test "returns true when widget ID matches focused_element" do
      assert FocusHelper.focused?("input_1", %{focused_element: "input_1"}) == true
    end

    test "returns false when widget ID does not match" do
      assert FocusHelper.focused?("input_1", %{focused_element: "input_2"}) == false
    end

    test "returns false when focused_element is nil" do
      assert FocusHelper.focused?("input_1", %{focused_element: nil}) == false
    end

    test "returns false when context has no focused_element key" do
      assert FocusHelper.focused?("input_1", %{}) == false
    end

    test "returns false when widget ID is nil" do
      assert FocusHelper.focused?(nil, %{focused_element: "input_1"}) == false
    end

    test "returns false for non-map context" do
      assert FocusHelper.focused?("input_1", nil) == false
    end

    test "works with atom IDs" do
      assert FocusHelper.focused?(:my_input, %{focused_element: :my_input}) == true
      assert FocusHelper.focused?(:my_input, %{focused_element: :other}) == false
    end
  end

  describe "focus_style/1" do
    test "adds border styles to a map" do
      style = %{fg: :white, bg: :black}
      result = FocusHelper.focus_style(style)
      assert result.border == :single
      assert result.border_fg == :cyan
      assert result.fg == :white
      assert result.bg == :black
    end

    test "handles empty style" do
      result = FocusHelper.focus_style(%{})
      assert result.border == :single
      assert result.border_fg == :cyan
    end

    test "passes through non-map values" do
      assert FocusHelper.focus_style(nil) == nil
    end
  end

  describe "maybe_focus_style/3" do
    test "applies focus style when widget is focused" do
      context = %{focused_element: "field_1"}
      style = %{fg: :white}
      result = FocusHelper.maybe_focus_style("field_1", context, style)
      assert result.border == :single
      assert result.fg == :white
    end

    test "returns base style when widget is not focused" do
      context = %{focused_element: "field_2"}
      style = %{fg: :white}
      result = FocusHelper.maybe_focus_style("field_1", context, style)
      assert result == %{fg: :white}
      refute Map.has_key?(result, :border)
    end

    test "returns base style when no focus context" do
      style = %{fg: :white}
      result = FocusHelper.maybe_focus_style("field_1", %{}, style)
      assert result == style
    end
  end

  describe "widget integration" do
    test "TextInput render sets focused from context" do
      alias Raxol.UI.Components.Input.TextInput
      {:ok, state} = TextInput.init(%{id: "my_input", value: "hello"})

      # Without focus context - not focused
      rendered_unfocused = TextInput.render(state, %{})
      assert rendered_unfocused.focused == false

      # With focus context matching this widget
      rendered_focused = TextInput.render(state, %{focused_element: "my_input"})
      assert rendered_focused.focused == true
    end

    test "TextInput without ID ignores focus context" do
      alias Raxol.UI.Components.Input.TextInput
      {:ok, state} = TextInput.init(%{value: "hello"})

      rendered = TextInput.render(state, %{focused_element: "something"})
      assert rendered.focused == false
    end

    test "Viewport render reads focus from context" do
      alias Raxol.UI.Components.Display.Viewport
      {:ok, state} = Viewport.init(id: "vp1", children: [], visible_height: 5)

      # Render with focus - doesn't crash
      rendered = Viewport.render(state, %{focused_element: "vp1"})
      assert rendered.id == "vp1"
    end
  end
end
