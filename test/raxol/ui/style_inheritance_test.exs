defmodule Raxol.UI.StyleInheritanceTest do
  use ExUnit.Case, async: true

  alias Raxol.UI.Layout.Engine, as: LayoutEngine
  alias Raxol.UI.StyleProcessor

  # Helper to extract style from a positioned element.
  # After layout, text elements have style at either :style or :attrs.style
  defp get_style(element) do
    Map.get(element, :style) ||
      get_in(element, [:attrs, :style]) ||
      %{}
  end

  # --- StyleProcessor inheritance ---

  describe "StyleProcessor.flatten_merged_style/3 inheritance" do
    test "child inherits fg/bg from parent when not set" do
      parent_style = %{fg: :blue, bg: :black, bold: true}
      child_element = %{type: :text, style: %{}}

      result = StyleProcessor.flatten_merged_style(parent_style, child_element, nil)

      assert result[:fg] == :blue
      assert result[:bg] == :black
      assert result[:bold] == true
    end

    test "child overrides inherited fg/bg" do
      parent_style = %{fg: :blue, bg: :black}
      child_element = %{type: :text, style: %{fg: :red}}

      result = StyleProcessor.flatten_merged_style(parent_style, child_element, nil)

      assert result[:fg] == :red
      assert result[:bg] == :black
    end

    test "layout properties do NOT inherit from parent" do
      parent_style = %{fg: :blue, padding: 2, border: :single}
      child_element = %{type: :text, style: %{}}

      result = StyleProcessor.flatten_merged_style(parent_style, child_element, nil)

      assert result[:fg] == :blue
      # padding and border should not leak into child
      refute result[:padding]
      refute result[:border]
    end

    test "bold/italic/underline inherit from parent" do
      parent_style = %{bold: true, italic: true, underline: true}
      child_element = %{type: :text, style: %{}}

      result = StyleProcessor.flatten_merged_style(parent_style, child_element, nil)

      assert result[:bold] == true
      assert result[:italic] == true
      assert result[:underline] == true
    end

    test "child can override boolean properties" do
      parent_style = %{bold: true, italic: true}
      child_element = %{type: :text, style: %{bold: false}}

      result = StyleProcessor.flatten_merged_style(parent_style, child_element, nil)

      assert result[:bold] == false
      assert result[:italic] == true
    end

    test "empty parent style does not affect child" do
      parent_style = %{}
      child_element = %{type: :text, style: %{fg: :green, bold: true}}

      result = StyleProcessor.flatten_merged_style(parent_style, child_element, nil)

      assert result[:fg] == :green
      assert result[:bold] == true
    end

    test "parent style from element map with :style key" do
      parent_style = %{style: %{fg: :cyan, bold: true}, padding: 1}
      child_element = %{type: :text, style: %{}}

      result = StyleProcessor.flatten_merged_style(parent_style, child_element, nil)

      assert result[:fg] == :cyan
      assert result[:bold] == true
    end

    test "dim and strikethrough inherit" do
      parent_style = %{dim: true, strikethrough: true}
      child_element = %{type: :text, style: %{}}

      result = StyleProcessor.flatten_merged_style(parent_style, child_element, nil)

      assert result[:dim] == true
      assert result[:strikethrough] == true
    end

    test "reverse inherits from parent" do
      parent_style = %{reverse: true}
      child_element = %{type: :text, style: %{}}

      result = StyleProcessor.flatten_merged_style(parent_style, child_element, nil)

      assert result[:reverse] == true
    end
  end

  # --- Container layout inheritance ---

  describe "layout container style inheritance" do
    test "column propagates fg to children" do
      column = %{
        type: :column,
        style: %{fg: :yellow},
        children: [
          %{type: :text, content: "hello", style: %{}},
          %{type: :text, content: "world", style: %{bold: true}}
        ]
      }

      space = %{x: 0, y: 0, width: 80, height: 24}
      result = LayoutEngine.apply_layout(column, space)

      text_elements = Enum.filter(result, fn e -> e[:type] == :text end)
      assert [_ | _] = text_elements

      for elem <- text_elements do
        style = get_style(elem)
        assert style[:fg] == :yellow, "expected fg: :yellow, got: #{inspect(style)}"
      end
    end

    test "row propagates bold to children" do
      row = %{
        type: :row,
        style: %{bold: true, fg: :red},
        children: [
          %{type: :text, content: "A", style: %{}},
          %{type: :text, content: "B", style: %{fg: :green}}
        ]
      }

      space = %{x: 0, y: 0, width: 80, height: 24}
      result = LayoutEngine.apply_layout(row, space)

      text_elements = Enum.filter(result, fn e -> e[:type] == :text end)
      assert [_ | _] = text_elements

      for elem <- text_elements do
        style = get_style(elem)
        assert style[:bold] == true, "expected bold: true, got: #{inspect(style)}"
      end

      # Second text should have fg: :green (child override)
      green_texts =
        Enum.filter(text_elements, fn e -> get_style(e)[:fg] == :green end)

      assert [_ | _] = green_texts
    end

    test "child style takes precedence over parent" do
      column = %{
        type: :column,
        style: %{fg: :blue, italic: true},
        children: [
          %{type: :text, content: "explicit", style: %{fg: :red, italic: false}}
        ]
      }

      space = %{x: 0, y: 0, width: 80, height: 24}
      result = LayoutEngine.apply_layout(column, space)

      text_elements = Enum.filter(result, fn e -> e[:type] == :text end)
      assert [_ | _] = text_elements

      elem = hd(text_elements)
      style = get_style(elem)
      assert style[:fg] == :red
      assert style[:italic] == false
    end

    test "no inheritance when parent has no style" do
      column = %{
        type: :column,
        children: [
          %{type: :text, content: "plain", style: %{fg: :white}}
        ]
      }

      space = %{x: 0, y: 0, width: 80, height: 24}
      result = LayoutEngine.apply_layout(column, space)

      text_elements = Enum.filter(result, fn e -> e[:type] == :text end)
      assert [_ | _] = text_elements

      elem = hd(text_elements)
      style = get_style(elem)
      assert style[:fg] == :white
    end

    test "nested inheritance cascades through multiple levels" do
      tree = %{
        type: :column,
        style: %{fg: :cyan},
        children: [
          %{
            type: :row,
            style: %{bold: true},
            children: [
              %{type: :text, content: "deep", style: %{}}
            ]
          }
        ]
      }

      space = %{x: 0, y: 0, width: 80, height: 24}
      result = LayoutEngine.apply_layout(tree, space)

      text_elements = Enum.filter(result, fn e -> e[:type] == :text end)
      assert [_ | _] = text_elements

      elem = hd(text_elements)
      style = get_style(elem)
      # Should inherit fg: :cyan from column, bold: true from row
      assert style[:fg] == :cyan
      assert style[:bold] == true
    end

    test "layout properties do not leak to children" do
      column = %{
        type: :column,
        style: %{fg: :blue, padding: 2, border: :double},
        children: [
          %{type: :text, content: "child", style: %{}}
        ]
      }

      space = %{x: 0, y: 0, width: 80, height: 24}
      result = LayoutEngine.apply_layout(column, space)

      text_elements = Enum.filter(result, fn e -> e[:type] == :text end)
      assert [_ | _] = text_elements

      elem = hd(text_elements)
      style = get_style(elem)
      assert style[:fg] == :blue
      refute style[:padding]
      refute style[:border]
    end
  end
end
