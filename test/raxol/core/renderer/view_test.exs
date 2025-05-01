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
      view =
        View.new(:box,
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
      view =
        View.flex direction: :row, size: {10, 1} do
          [
            View.text("A", id: :a, size: {1, 1}),
            View.text("B", id: :b, size: {1, 1})
          ]
        end

      # layout/2 returns a flat list of positioned views
      result_list = View.layout(view, {10, 1})

      # Find the children by id (or content/type if no id)
      a = Enum.find(result_list, &(&1.id == :a))
      b = Enum.find(result_list, &(&1.id == :b))

      # Add checks for nil in case find fails
      refute is_nil(a)
      refute is_nil(b)

      assert a.position == {0, 0}
      assert b.position == {1, 0}
    end

    test "grid layout" do
      view =
        View.grid columns: 2, size: {4, 2} do
          [
            View.text("1"),
            View.text("2"),
            View.text("3"),
            View.text("4")
          ]
        end

      result_list = View.layout(view, {4, 2})

      # Find children by content
      one = Enum.find(result_list, &(&1.content == "1"))
      two = Enum.find(result_list, &(&1.content == "2"))
      three = Enum.find(result_list, &(&1.content == "3"))
      four = Enum.find(result_list, &(&1.content == "4"))

      refute is_nil(one)
      refute is_nil(two)
      refute is_nil(three)
      refute is_nil(four)

      assert one.position == {0, 0}
      assert two.position == {2, 0}
      assert three.position == {0, 1}
      assert four.position == {2, 1}
    end

    test "border layout" do
      view =
        View.border :single, size: {4, 3} do
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
      view =
        View.scroll offset: {1, 1} do
          View.text("Content", size: {10, 5})
        end

      result_list = View.layout(view, {8, 4})

      # Find the single child content view
      content = Enum.find(result_list, &(&1.content == "Content"))

      refute is_nil(content)
      assert content.position == {-1, -1}
    end

    test "shadow layout" do
      view =
        View.shadow offset: {1, 1} do
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
      view =
        View.flex direction: :row, wrap: true, size: {3, 2} do
          [
            View.text("A", size: {2, 1}),
            View.text("B", size: {2, 1}),
            View.text("C", size: {2, 1})
          ]
        end

      result_list = View.layout(view, {3, 2})

      # Find children by content
      a = Enum.find(result_list, &(&1.content == "A"))
      b = Enum.find(result_list, &(&1.content == "B"))
      c = Enum.find(result_list, &(&1.content == "C"))

      refute is_nil(a)
      refute is_nil(b)
      refute is_nil(c)

      assert a.position == {0, 0}
      # Wraps to next line
      assert b.position == {0, 1}
      assert c.position == {2, 1} # Note: Check if this position is correct logic for wrapping
    end

    test "wrapping in column direction" do
      view =
        View.flex direction: :column, wrap: true, size: {4, 2} do
          [
            View.text("A", size: {1, 1}),
            View.text("B", size: {1, 1}),
            View.text("C", size: {1, 1})
          ]
        end

      result_list = View.layout(view, {4, 2})

      # Find children by content
      a = Enum.find(result_list, &(&1.content == "A"))
      b = Enum.find(result_list, &(&1.content == "B"))
      c = Enum.find(result_list, &(&1.content == "C"))

      refute is_nil(a)
      refute is_nil(b)
      refute is_nil(c)

      assert a.position == {0, 0}
      assert b.position == {0, 1}
      # Wraps to next column
      assert c.position == {1, 0}
    end
  end
end
