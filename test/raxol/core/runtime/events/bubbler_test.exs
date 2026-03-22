defmodule Raxol.Core.Runtime.Events.BubblerTest do
  use ExUnit.Case, async: true

  alias Raxol.Core.Runtime.Events.Bubbler
  alias Raxol.Core.Events.Event

  # --- Test Helpers ---

  defp key_event(key, opts \\ []) do
    %Event{
      type: :key,
      data: %{key: key, modifiers: Keyword.get(opts, :modifiers, [])}
    }
  end

  defp click_event do
    %Event{type: :click, data: %{}}
  end

  defp mouse_event do
    %Event{
      type: :mouse,
      data: %{button: :left, state: :pressed, x: 0, y: 0}
    }
  end

  # --- find_ancestor_path tests ---

  describe "find_ancestor_path/2" do
    test "finds element at root" do
      tree = %{type: :box, id: :root, children: []}
      path = Bubbler.find_ancestor_path(tree, :root)
      assert [%{id: :root}] = path
    end

    test "finds nested element and returns bottom-up path" do
      tree = %{
        type: :column,
        id: :root,
        children: [
          %{type: :row, id: :row1, children: [
            %{type: :button, id: :btn1},
            %{type: :button, id: :btn2}
          ]}
        ]
      }

      path = Bubbler.find_ancestor_path(tree, :btn2)
      ids = Enum.map(path, & &1.id)
      assert ids == [:btn2, :row1, :root]
    end

    test "returns nil when element not found" do
      tree = %{type: :box, id: :root, children: []}
      assert Bubbler.find_ancestor_path(tree, :nonexistent) == nil
    end

    test "handles single child map (not list)" do
      tree = %{
        type: :box,
        id: :root,
        children: %{type: :text, id: :label}
      }

      path = Bubbler.find_ancestor_path(tree, :label)
      ids = Enum.map(path, & &1.id)
      assert ids == [:label, :root]
    end

    test "handles deeply nested elements" do
      tree = %{
        type: :column,
        id: :root,
        children: [
          %{type: :box, id: :level1, children: [
            %{type: :row, id: :level2, children: [
              %{type: :column, id: :level3, children: [
                %{type: :button, id: :deep_btn}
              ]}
            ]}
          ]}
        ]
      }

      path = Bubbler.find_ancestor_path(tree, :deep_btn)
      ids = Enum.map(path, & &1.id)
      assert ids == [:deep_btn, :level3, :level2, :level1, :root]
    end

    test "handles elements without id" do
      tree = %{
        type: :column,
        id: :root,
        children: [
          %{type: :box, children: [
            %{type: :button, id: :btn}
          ]}
        ]
      }

      path = Bubbler.find_ancestor_path(tree, :btn)
      assert length(path) == 3
      assert hd(path).id == :btn
    end

    test "handles leaf elements without children" do
      tree = %{
        type: :column,
        id: :root,
        children: [
          %{type: :text, id: :label, content: "hello"}
        ]
      }

      path = Bubbler.find_ancestor_path(tree, :label)
      ids = Enum.map(path, & &1.id)
      assert ids == [:label, :root]
    end
  end

  # --- Inline handler tests ---

  describe "bubble/4 with inline handlers" do
    test "on_click handler fires on click event" do
      tree = %{
        type: :column,
        id: :root,
        children: [
          %{type: :button, id: :btn, on_click: :increment}
        ]
      }

      result = Bubbler.bubble(click_event(), tree, :btn, %{})
      assert {:handled, {:message, :increment}} = result
    end

    test "on_click handler fires on enter key" do
      tree = %{
        type: :column,
        id: :root,
        children: [
          %{type: :button, id: :btn, on_click: :submit}
        ]
      }

      result = Bubbler.bubble(key_event(:enter), tree, :btn, %{})
      assert {:handled, {:message, :submit}} = result
    end

    test "on_click handler fires on space key" do
      tree = %{
        type: :column,
        id: :root,
        children: [
          %{type: :button, id: :btn, on_click: :submit}
        ]
      }

      result = Bubbler.bubble(key_event(:space), tree, :btn, %{})
      assert {:handled, {:message, :submit}} = result
    end

    test "on_click with tuple message" do
      tree = %{
        type: :column,
        id: :root,
        children: [
          %{type: :button, id: :btn, on_click: {:button_clicked, :btn}}
        ]
      }

      result = Bubbler.bubble(click_event(), tree, :btn, %{})
      assert {:handled, {:message, {:button_clicked, :btn}}} = result
    end

    test "on_click does not fire on unrelated key" do
      tree = %{
        type: :column,
        id: :root,
        children: [
          %{type: :button, id: :btn, on_click: :submit}
        ]
      }

      result = Bubbler.bubble(key_event(:down), tree, :btn, %{})
      # Should passthrough since :down key doesn't trigger on_click
      # and button has no component module match in test context
      assert result in [:passthrough, {:handled, :ok}]
    end
  end

  # --- Bubbling behavior tests ---

  describe "bubble/4 propagation" do
    test "returns passthrough when element not found" do
      tree = %{type: :box, id: :root, children: []}
      result = Bubbler.bubble(click_event(), tree, :nonexistent, %{})
      assert result == :passthrough
    end

    test "returns passthrough when view_tree has no matching handler" do
      tree = %{
        type: :column,
        id: :root,
        children: [
          %{type: :text, id: :label, content: "static"}
        ]
      }

      result = Bubbler.bubble(key_event(:a), tree, :label, %{})
      assert result == :passthrough
    end

    test "bubbles from child to parent on_click" do
      tree = %{
        type: :box,
        id: :parent,
        on_click: :parent_clicked,
        children: [
          %{type: :text, id: :child, content: "hello"}
        ]
      }

      result = Bubbler.bubble(click_event(), tree, :child, %{})
      assert {:handled, {:message, :parent_clicked}} = result
    end

    test "child handler takes priority over parent" do
      tree = %{
        type: :box,
        id: :parent,
        on_click: :parent_clicked,
        children: [
          %{type: :button, id: :child, on_click: :child_clicked}
        ]
      }

      result = Bubbler.bubble(click_event(), tree, :child, %{})
      assert {:handled, {:message, :child_clicked}} = result
    end

    test "skips elements without handlers and continues bubbling" do
      tree = %{
        type: :column,
        id: :root,
        on_click: :root_clicked,
        children: [
          %{type: :row, id: :middle, children: [
            %{type: :text, id: :leaf, content: "text"}
          ]}
        ]
      }

      result = Bubbler.bubble(click_event(), tree, :leaf, %{})
      assert {:handled, {:message, :root_clicked}} = result
    end
  end

  # --- Edge cases ---

  describe "edge cases" do
    test "handles nil on_click gracefully" do
      tree = %{
        type: :column,
        id: :root,
        children: [
          %{type: :button, id: :btn, on_click: nil}
        ]
      }

      result = Bubbler.bubble(click_event(), tree, :btn, %{})
      # nil on_click should not match, falls through
      assert result in [:passthrough, {:handled, :ok}]
    end

    test "handles empty children list" do
      tree = %{type: :box, id: :root, children: []}
      result = Bubbler.bubble(click_event(), tree, :root, %{})
      assert result == :passthrough
    end

    test "handles tree with no children key" do
      tree = %{type: :text, id: :root, content: "hello"}
      path = Bubbler.find_ancestor_path(tree, :root)
      assert [%{id: :root}] = path
    end
  end
end
