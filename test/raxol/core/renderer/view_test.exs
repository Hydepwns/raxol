defmodule Raxol.Core.Renderer.ViewTest do
  use ExUnit.Case, async: true
  alias Raxol.Core.Renderer.View

  describe "new/2" do
    test "creates a basic view" do
      view = View.new(:text, content: "Hello")
      assert view.type == :text
      assert view.content == "Hello"
      assert view.style == []
      assert view.border == :none
    end

    test "applies all options" do
      view = View.new(:box,
        position: {0, 0},
        size: {10, 5},
        style: [:bold],
        fg: :red,
        bg: :blue,
        border: :single,
        padding: 1,
        margin: {2, 2}
      )

      assert view.position == {0, 0}
      assert view.size == {10, 5}
      assert view.style == [:bold]
      assert view.fg == :red
      assert view.bg == :blue
      assert view.border == :single
      assert view.padding == {1, 1, 1, 1}
      assert view.margin == {2, 2, 2, 2}
    end
  end

  describe "layout/2" do
    test "basic text layout" do
      view = View.text("Hello", position: {0, 0})
      result = View.layout(view, {10, 1})
      assert result.position == {0, 0}
      assert result.size == {10, 1}
    end

    test "flex layout with row direction" do
      view = View.flex(direction: :row, size: {10, 1}) do
        [
          View.text("A", size: {1, 1}),
          View.text("B", size: {1, 1})
        ]
      end

      result = View.layout(view, {10, 1})
      [a, b] = result.children

      assert a.position == {0, 0}
      assert b.position == {1, 0}
    end

    test "grid layout" do
      view = View.grid(columns: 2, size: {4, 2}) do
        [
          View.text("1"),
          View.text("2"),
          View.text("3"),
          View.text("4")
        ]
      end

      result = View.layout(view, {4, 2})
      [one, two, three, four] = result.children

      assert one.position == {0, 0}
      assert two.position == {2, 0}
      assert three.position == {0, 1}
      assert four.position == {2, 1}
    end

    test "border layout" do
      view = View.border(:single, size: {4, 3}) do
        View.text("Hi")
      end

      result = View.layout(view, {4, 3})
      
      # Check border characters
      borders = Enum.filter(result, &(&1.type == :text))
      assert Enum.any?(borders, fn v ->
        v.position == {0, 0} and v.content == "┌"
      end)
      assert Enum.any?(borders, fn v ->
        v.position == {3, 0} and v.content == "┐"
      end)

      # Check content position
      content = Enum.find(result, &(&1.content == "Hi"))
      assert content.position == {1, 1}
    end

    test "scroll layout" do
      view = View.scroll(offset: {1, 1}) do
        View.text("Content", size: {10, 5})
      end

      result = View.layout(view, {8, 4})
      [content] = result.children
      assert content.position == {-1, -1}
    end

    test "shadow layout" do
      view = View.shadow(offset: {1, 1}) do
        View.text("Hi", size: {2, 1})
      end

      result = View.layout(view, {3, 2})
      
      # Check shadow cells
      shadows = Enum.filter(result, &(&1.bg == :bright_black))
      assert length(shadows) > 0
      
      # Check content position
      content = Enum.find(result, &(&1.content == "Hi"))
      assert content.position == {0, 0}
    end
  end

  describe "spacing normalization" do
    test "single integer becomes uniform spacing" do
      view = View.new(:box, padding: 2)
      assert view.padding == {2, 2, 2, 2}
    end

    test "horizontal/vertical pair expands correctly" do
      view = View.new(:box, margin: {1, 2})
      assert view.margin == {1, 2, 1, 2}
    end

    test "four values remain unchanged" do
      view = View.new(:box, padding: {1, 2, 3, 4})
      assert view.padding == {1, 2, 3, 4}
    end
  end

  describe "flex layout features" do
    test "wrapping in row direction" do
      view = View.flex(direction: :row, wrap: true, size: {3, 2}) do
        [
          View.text("A", size: {2, 1}),
          View.text("B", size: {2, 1}),
          View.text("C", size: {2, 1})
        ]
      end

      result = View.layout(view, {3, 2})
      [a, b, c] = result.children

      assert a.position == {0, 0}
      assert b.position == {0, 1}  # Wraps to next line
      assert c.position == {2, 1}
    end

    test "wrapping in column direction" do
      view = View.flex(direction: :column, wrap: true, size: {4, 2}) do
        [
          View.text("A", size: {1, 1}),
          View.text("B", size: {1, 1}),
          View.text("C", size: {1, 1})
        ]
      end

      result = View.layout(view, {4, 2})
      [a, b, c] = result.children

      assert a.position == {0, 0}
      assert b.position == {0, 1}
      assert c.position == {1, 0}  # Wraps to next column
    end
  end
end 