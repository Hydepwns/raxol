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

  describe "focus_style/2 (theme-aware)" do
    test "reads focus config from theme context" do
      context = %{
        theme: %{
          component_styles: %{
            focus: %{border: :double, border_fg: :magenta}
          }
        }
      }

      result = FocusHelper.focus_style(%{fg: :white}, context)
      assert result.border == :double
      assert result.border_fg == :magenta
      assert result.fg == :white
    end

    test "falls back to defaults when no theme present" do
      result = FocusHelper.focus_style(%{fg: :white}, %{})
      assert result.border == :single
      assert result.border_fg == :cyan
    end

    test "falls back when theme has no focus key" do
      context = %{theme: %{component_styles: %{}}}
      result = FocusHelper.focus_style(%{fg: :white}, context)
      assert result.border == :single
      assert result.border_fg == :cyan
    end
  end

  describe "maybe_focus_style/4 (theme-aware)" do
    test "applies theme focus style when widget is focused" do
      context = %{
        focused_element: "f1",
        theme: %{
          component_styles: %{focus: %{border: :rounded, border_fg: :green}}
        }
      }

      result = FocusHelper.maybe_focus_style("f1", context, %{fg: :white}, %{})
      assert result.border == :rounded
      assert result.border_fg == :green
    end

    test "returns base style when not focused" do
      context = %{focused_element: "other", theme: %{component_styles: %{}}}
      result = FocusHelper.maybe_focus_style("f1", context, %{fg: :white}, %{})
      assert result == %{fg: :white}
    end
  end

  describe "widget_state/2" do
    test "returns :disabled when widget is disabled" do
      assert FocusHelper.widget_state(%{disabled: true, id: "x"}, %{focused_element: "x"}) ==
               :disabled
    end

    test "returns :active when widget is active (not disabled)" do
      assert FocusHelper.widget_state(%{active: true, id: "x"}, %{}) == :active
    end

    test "returns :focused when widget is focused (not disabled/active)" do
      assert FocusHelper.widget_state(%{id: "x"}, %{focused_element: "x"}) == :focused
    end

    test "returns :default when no pseudo-state applies" do
      assert FocusHelper.widget_state(%{id: "x"}, %{focused_element: "y"}) == :default
    end

    test "disabled takes priority over active and focused" do
      assert FocusHelper.widget_state(
               %{disabled: true, active: true, id: "x"},
               %{focused_element: "x"}
             ) == :disabled
    end

    test "active takes priority over focused" do
      assert FocusHelper.widget_state(%{active: true, id: "x"}, %{focused_element: "x"}) ==
               :active
    end
  end

  describe "state_style/3" do
    test "returns base style for :default" do
      assert FocusHelper.state_style(:default, %{}, %{fg: :white}) == %{fg: :white}
    end

    test "merges theme pseudo-state style for :focused" do
      context = %{
        theme: %{
          component_styles: %{focused: %{border: :rounded, border_fg: :yellow}}
        }
      }

      result = FocusHelper.state_style(:focused, context, %{fg: :white})
      assert result.border == :rounded
      assert result.fg == :white
    end

    test "uses defaults when theme has no pseudo-state entry" do
      result = FocusHelper.state_style(:disabled, %{}, %{fg: :white})
      assert result.fg == :gray
    end

    test "merges :active style from theme" do
      context = %{
        theme: %{
          component_styles: %{active: %{border: :thick, border_fg: :red}}
        }
      }

      result = FocusHelper.state_style(:active, context, %{fg: :white})
      assert result.border == :thick
      assert result.border_fg == :red
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

    test "SelectList render reads focus from context" do
      alias Raxol.UI.Components.Input.SelectList

      {:ok, state} =
        SelectList.init(%{
          id: "sl1",
          options: [{"Option A", :a}, {"Option B", :b}]
        })

      # Without focus context
      rendered_unfocused = SelectList.render(state, %{})
      refute rendered_unfocused.style[:border]

      # With focus context matching this widget
      rendered_focused = SelectList.render(state, %{focused_element: "sl1"})
      assert rendered_focused.style[:border] == :single
      assert rendered_focused.style[:border_fg] == :cyan
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
