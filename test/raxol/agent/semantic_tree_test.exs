defmodule Raxol.Agent.SemanticTreeTest do
  use ExUnit.Case, async: true

  alias Raxol.Agent.SemanticTree

  @raw_tree %{
    type: :box,
    padding: 1,
    border: :single,
    style: %{fg: :cyan},
    margin: 0,
    gap: 1,
    children: [
      %{type: :text, content: "Status: scanning", fg: :green, style: [:bold]},
      %{
        type: :list,
        id: "files",
        items: ["a.ex", "b.ex"],
        selected: 1,
        style: %{},
        on_change: :noop
      },
      %{
        type: :checkbox,
        id: "toggle",
        checked: true,
        label: "Enable",
        padding: 2,
        on_toggle: :noop
      }
    ]
  }

  describe "from_view_tree/2" do
    test "strips layout keys and keeps semantic keys" do
      result = SemanticTree.from_view_tree(@raw_tree)

      assert result.type == :box
      refute Map.has_key?(result, :padding)
      refute Map.has_key?(result, :border)
      refute Map.has_key?(result, :style)
      refute Map.has_key?(result, :margin)
      refute Map.has_key?(result, :gap)
      assert length(result.children) == 3
    end

    test "recursively transforms children" do
      result = SemanticTree.from_view_tree(@raw_tree)
      [text, list, checkbox] = result.children

      assert text.type == :text
      assert text.content == "Status: scanning"
      refute Map.has_key?(text, :fg)
      refute Map.has_key?(text, :style)

      assert list.type == :list
      assert list.items == ["a.ex", "b.ex"]
      assert list.selected == 1
      refute Map.has_key?(list, :style)
      refute Map.has_key?(list, :on_change)

      assert checkbox.type == :checkbox
      assert checkbox.checked == true
      assert checkbox.label == "Enable"
      refute Map.has_key?(checkbox, :padding)
      refute Map.has_key?(checkbox, :on_toggle)
    end

    test "returns nil for nil input" do
      assert SemanticTree.from_view_tree(nil) == nil
    end

    test "handles tree with no children" do
      result = SemanticTree.from_view_tree(%{type: :text, content: "hello", style: %{}})
      assert result == %{type: :text, content: "hello"}
    end

    test "adds focused flag when focused_id matches" do
      result = SemanticTree.from_view_tree(@raw_tree, focused_id: "files")
      [_text, list, checkbox] = result.children

      assert list.focused == true
      assert checkbox.focused == false
    end

    test "does not add focused key when no focused_id given" do
      result = SemanticTree.from_view_tree(@raw_tree)
      [text | _] = result.children
      refute Map.has_key?(text, :focused)
    end

    test "preserves interactive widget state" do
      tree = %{
        type: :form,
        children: [
          %{type: :text_input, id: "name", value: "Alice", placeholder: "Name", style: %{}},
          %{type: :select, id: "role", options: ["admin", "user"], selected: 0, style: %{}}
        ]
      }

      result = SemanticTree.from_view_tree(tree)
      [input, select] = result.children

      assert input.value == "Alice"
      assert input.placeholder == "Name"
      assert select.options == ["admin", "user"]
      assert select.selected == 0
    end
  end

  describe "find/2" do
    test "locates node by id" do
      tree = SemanticTree.from_view_tree(@raw_tree)
      node = SemanticTree.find(tree, "files")

      assert node.type == :list
      assert node.items == ["a.ex", "b.ex"]
    end

    test "returns nil on miss" do
      tree = SemanticTree.from_view_tree(@raw_tree)
      assert SemanticTree.find(tree, "nonexistent") == nil
    end

    test "returns nil for nil tree" do
      assert SemanticTree.find(nil, "anything") == nil
    end
  end

  describe "find_by_type/2" do
    test "collects all nodes matching type" do
      tree = SemanticTree.from_view_tree(@raw_tree)
      texts = SemanticTree.find_by_type(tree, :text)

      assert length(texts) == 1
      assert hd(texts).content == "Status: scanning"
    end

    test "returns empty list on no match" do
      tree = SemanticTree.from_view_tree(@raw_tree)
      assert SemanticTree.find_by_type(tree, :table) == []
    end

    test "returns empty list for nil tree" do
      assert SemanticTree.find_by_type(nil, :text) == []
    end
  end

  describe "text_content/1" do
    test "flattens nested text content" do
      tree = %{
        type: :box,
        children: [
          %{type: :text, content: "Hello"},
          %{type: :box, children: [
            %{type: :text, content: "World"}
          ]}
        ]
      }

      result = SemanticTree.text_content(tree)
      assert result == "Hello World"
    end

    test "returns empty string for nil" do
      assert SemanticTree.text_content(nil) == ""
    end

    test "returns content for a single text node" do
      assert SemanticTree.text_content(%{type: :text, content: "solo"}) == "solo"
    end
  end
end
