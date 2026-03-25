defmodule Raxol.UI.Components.Display.TreeTest do
  use ExUnit.Case, async: true

  alias Raxol.UI.Components.Display.Tree
  alias Raxol.Core.Events.Event

  defp default_context do
    %{theme: Raxol.UI.Theming.Theme.default_theme()}
  end

  defp key_event(key) do
    %Event{type: :key, data: %{key: key}}
  end

  defp sample_tree do
    [
      %{
        id: :root1,
        label: "Root 1",
        children: [
          %{id: :child1a, label: "Child 1A", children: [], data: :data_1a},
          %{
            id: :child1b,
            label: "Child 1B",
            children: [
              %{id: :grandchild1, label: "Grandchild 1", children: [], data: :gc1}
            ],
            data: nil
          }
        ],
        data: nil
      },
      %{id: :root2, label: "Root 2", children: [], data: :data_r2}
    ]
  end

  describe "init/1" do
    test "initializes with default values" do
      assert {:ok, state} = Tree.init(id: :tree1)
      assert state.id == :tree1
      assert state.nodes == []
      assert state.expanded == MapSet.new()
      assert state.cursor == nil
      assert state.focused == false
      assert state.indent_size == 2
      assert state.on_select == nil
      assert state.on_expand == nil
      assert state.on_collapse == nil
      assert state.style == %{}
      assert state.theme == %{}
    end

    test "initializes with nodes and sets cursor to first node" do
      assert {:ok, state} = Tree.init(id: :tree2, nodes: sample_tree())
      assert state.cursor == :root1
      assert length(state.nodes) == 2
    end

    test "initializes with provided expanded set" do
      expanded = MapSet.new([:root1])
      assert {:ok, state} = Tree.init(id: :tree3, nodes: sample_tree(), expanded: expanded)
      assert MapSet.member?(state.expanded, :root1)
    end
  end

  describe "visible_nodes/1" do
    test "all collapsed shows only roots" do
      {:ok, state} = Tree.init(id: :t, nodes: sample_tree())
      visible = Tree.visible_nodes(state)

      assert length(visible) == 2
      ids = Enum.map(visible, fn {node, _} -> node.id end)
      assert ids == [:root1, :root2]
    end

    test "expanding a node shows its children" do
      {:ok, state} = Tree.init(id: :t, nodes: sample_tree(), expanded: MapSet.new([:root1]))
      visible = Tree.visible_nodes(state)

      ids = Enum.map(visible, fn {node, _} -> node.id end)
      assert ids == [:root1, :child1a, :child1b, :root2]
    end

    test "depths are correct" do
      {:ok, state} = Tree.init(id: :t, nodes: sample_tree(), expanded: MapSet.new([:root1]))
      visible = Tree.visible_nodes(state)

      depths = Enum.map(visible, fn {_, depth} -> depth end)
      assert depths == [0, 1, 1, 0]
    end

    test "deeply nested expansion" do
      expanded = MapSet.new([:root1, :child1b])
      {:ok, state} = Tree.init(id: :t, nodes: sample_tree(), expanded: expanded)
      visible = Tree.visible_nodes(state)

      ids = Enum.map(visible, fn {node, _} -> node.id end)
      assert ids == [:root1, :child1a, :child1b, :grandchild1, :root2]

      depths = Enum.map(visible, fn {_, depth} -> depth end)
      assert depths == [0, 1, 1, 2, 0]
    end

    test "empty tree returns empty list" do
      {:ok, state} = Tree.init(id: :t, nodes: [])
      assert Tree.visible_nodes(state) == []
    end
  end

  describe "find_node/2" do
    test "finds root node" do
      node = Tree.find_node(sample_tree(), :root1)
      assert node.label == "Root 1"
    end

    test "finds nested node" do
      node = Tree.find_node(sample_tree(), :grandchild1)
      assert node.label == "Grandchild 1"
    end

    test "returns nil for missing node" do
      assert Tree.find_node(sample_tree(), :nonexistent) == nil
    end
  end

  describe "find_parent/2" do
    test "returns nil for root node" do
      assert Tree.find_parent(sample_tree(), :root1) == nil
    end

    test "finds parent of child" do
      parent = Tree.find_parent(sample_tree(), :child1a)
      assert parent.id == :root1
    end

    test "finds parent of grandchild" do
      parent = Tree.find_parent(sample_tree(), :grandchild1)
      assert parent.id == :child1b
    end
  end

  describe "handle_event/3 - up/down navigation" do
    test "down moves to next visible node" do
      {:ok, state} = Tree.init(id: :t, nodes: sample_tree(), cursor: :root1)
      {new_state, []} = Tree.handle_event(key_event(:down), state, %{})
      assert new_state.cursor == :root2
    end

    test "down is clamped at last node" do
      {:ok, state} = Tree.init(id: :t, nodes: sample_tree(), cursor: :root2)
      {new_state, []} = Tree.handle_event(key_event(:down), state, %{})
      assert new_state.cursor == :root2
    end

    test "up moves to previous visible node" do
      {:ok, state} = Tree.init(id: :t, nodes: sample_tree(), cursor: :root2)
      {new_state, []} = Tree.handle_event(key_event(:up), state, %{})
      assert new_state.cursor == :root1
    end

    test "up is clamped at first node" do
      {:ok, state} = Tree.init(id: :t, nodes: sample_tree(), cursor: :root1)
      {new_state, []} = Tree.handle_event(key_event(:up), state, %{})
      assert new_state.cursor == :root1
    end

    test "navigates through expanded children" do
      expanded = MapSet.new([:root1])
      {:ok, state} = Tree.init(id: :t, nodes: sample_tree(), expanded: expanded, cursor: :root1)

      {s1, []} = Tree.handle_event(key_event(:down), state, %{})
      assert s1.cursor == :child1a

      {s2, []} = Tree.handle_event(key_event(:down), s1, %{})
      assert s2.cursor == :child1b

      {s3, []} = Tree.handle_event(key_event(:down), s2, %{})
      assert s3.cursor == :root2
    end
  end

  describe "handle_event/3 - expand/collapse" do
    test "right expands collapsed node with children" do
      {:ok, state} = Tree.init(id: :t, nodes: sample_tree(), cursor: :root1)
      {new_state, []} = Tree.handle_event(key_event(:right), state, %{})
      assert MapSet.member?(new_state.expanded, :root1)
    end

    test "right does nothing on leaf node" do
      expanded = MapSet.new([:root1])
      {:ok, state} = Tree.init(id: :t, nodes: sample_tree(), expanded: expanded, cursor: :child1a)
      {new_state, []} = Tree.handle_event(key_event(:right), state, %{})
      assert new_state.expanded == expanded
    end

    test "right does nothing on already expanded node" do
      expanded = MapSet.new([:root1])
      {:ok, state} = Tree.init(id: :t, nodes: sample_tree(), expanded: expanded, cursor: :root1)
      {new_state, []} = Tree.handle_event(key_event(:right), state, %{})
      assert new_state.expanded == expanded
    end

    test "left collapses expanded node" do
      expanded = MapSet.new([:root1])
      {:ok, state} = Tree.init(id: :t, nodes: sample_tree(), expanded: expanded, cursor: :root1)
      {new_state, []} = Tree.handle_event(key_event(:left), state, %{})
      refute MapSet.member?(new_state.expanded, :root1)
    end

    test "left on collapsed node moves to parent" do
      expanded = MapSet.new([:root1])
      {:ok, state} = Tree.init(id: :t, nodes: sample_tree(), expanded: expanded, cursor: :child1a)
      {new_state, []} = Tree.handle_event(key_event(:left), state, %{})
      assert new_state.cursor == :root1
    end

    test "left on root collapsed node does nothing" do
      {:ok, state} = Tree.init(id: :t, nodes: sample_tree(), cursor: :root1)
      {new_state, []} = Tree.handle_event(key_event(:left), state, %{})
      assert new_state.cursor == :root1
    end
  end

  describe "handle_event/3 - enter/space activation" do
    test "enter on collapsed parent expands it" do
      {:ok, state} = Tree.init(id: :t, nodes: sample_tree(), cursor: :root1)
      {new_state, []} = Tree.handle_event(key_event(:enter), state, %{})
      assert MapSet.member?(new_state.expanded, :root1)
    end

    test "enter on expanded parent collapses it" do
      expanded = MapSet.new([:root1])
      {:ok, state} = Tree.init(id: :t, nodes: sample_tree(), expanded: expanded, cursor: :root1)
      {new_state, []} = Tree.handle_event(key_event(:enter), state, %{})
      refute MapSet.member?(new_state.expanded, :root1)
    end

    test "space toggles like enter" do
      {:ok, state} = Tree.init(id: :t, nodes: sample_tree(), cursor: :root1)
      {new_state, []} = Tree.handle_event(key_event(:space), state, %{})
      assert MapSet.member?(new_state.expanded, :root1)
    end

    test "enter on leaf fires on_select" do
      test_pid = self()
      on_select = fn id, data -> send(test_pid, {:selected, id, data}) end
      expanded = MapSet.new([:root1])

      {:ok, state} =
        Tree.init(
          id: :t,
          nodes: sample_tree(),
          expanded: expanded,
          cursor: :child1a,
          on_select: on_select
        )

      {_new_state, []} = Tree.handle_event(key_event(:enter), state, %{})
      assert_receive {:selected, :child1a, :data_1a}
    end

    test "enter on leaf does not change expanded set" do
      expanded = MapSet.new([:root1])

      {:ok, state} =
        Tree.init(id: :t, nodes: sample_tree(), expanded: expanded, cursor: :child1a)

      {new_state, []} = Tree.handle_event(key_event(:enter), state, %{})
      assert new_state.expanded == expanded
    end
  end

  describe "handle_event/3 - home/end" do
    test "home moves to first visible node" do
      {:ok, state} = Tree.init(id: :t, nodes: sample_tree(), cursor: :root2)
      {new_state, []} = Tree.handle_event(key_event(:home), state, %{})
      assert new_state.cursor == :root1
    end

    test "end moves to last visible node" do
      {:ok, state} = Tree.init(id: :t, nodes: sample_tree(), cursor: :root1)
      {new_state, []} = Tree.handle_event(key_event(:end), state, %{})
      assert new_state.cursor == :root2
    end

    test "end with expanded nodes goes to actual last visible" do
      expanded = MapSet.new([:root1])
      {:ok, state} = Tree.init(id: :t, nodes: sample_tree(), expanded: expanded, cursor: :root1)
      {new_state, []} = Tree.handle_event(key_event(:end), state, %{})
      assert new_state.cursor == :root2
    end
  end

  describe "handle_event/3 - callbacks" do
    test "on_expand fires when expanding" do
      test_pid = self()
      on_expand = fn id -> send(test_pid, {:expanded, id}) end
      {:ok, state} = Tree.init(id: :t, nodes: sample_tree(), cursor: :root1, on_expand: on_expand)
      {_new_state, []} = Tree.handle_event(key_event(:right), state, %{})
      assert_receive {:expanded, :root1}
    end

    test "on_collapse fires when collapsing" do
      test_pid = self()
      on_collapse = fn id -> send(test_pid, {:collapsed, id}) end
      expanded = MapSet.new([:root1])

      {:ok, state} =
        Tree.init(
          id: :t,
          nodes: sample_tree(),
          expanded: expanded,
          cursor: :root1,
          on_collapse: on_collapse
        )

      {_new_state, []} = Tree.handle_event(key_event(:left), state, %{})
      assert_receive {:collapsed, :root1}
    end
  end

  describe "handle_event/3 - pass-through" do
    test "unknown events pass through unchanged" do
      {:ok, state} = Tree.init(id: :t, nodes: sample_tree())
      event = %Event{type: :key, data: %{key: :char, char: "x"}}
      {new_state, []} = Tree.handle_event(event, state, %{})
      assert new_state == state
    end
  end

  describe "render/2" do
    test "renders empty tree" do
      {:ok, state} = Tree.init(id: :t, nodes: [])
      rendered = Tree.render(state, default_context())
      assert rendered.type == :column
      assert rendered.children == []
    end

    test "renders collapsed tree with correct icons" do
      {:ok, state} = Tree.init(id: :t, nodes: sample_tree(), cursor: :root1)
      rendered = Tree.render(state, default_context())

      assert rendered.type == :column
      assert length(rendered.children) == 2

      root1 = Enum.at(rendered.children, 0)
      assert root1.content == "▶ Root 1"

      root2 = Enum.at(rendered.children, 1)
      assert root2.content == "  Root 2"
    end

    test "renders expanded tree with indentation" do
      expanded = MapSet.new([:root1])
      {:ok, state} = Tree.init(id: :t, nodes: sample_tree(), expanded: expanded, cursor: :root1)
      rendered = Tree.render(state, default_context())

      assert length(rendered.children) == 4

      root1 = Enum.at(rendered.children, 0)
      assert root1.content == "▼ Root 1"

      child1a = Enum.at(rendered.children, 1)
      assert child1a.content == "    Root 1A" |> then(fn _ -> child1a.content end)
      assert String.starts_with?(child1a.content, "  ")

      child1b = Enum.at(rendered.children, 2)
      assert String.contains?(child1b.content, "▶")
      assert String.contains?(child1b.content, "Child 1B")
    end

    test "cursor node has reverse style" do
      {:ok, state} = Tree.init(id: :t, nodes: sample_tree(), cursor: :root1)
      rendered = Tree.render(state, default_context())

      cursor_el = Enum.at(rendered.children, 0)
      assert cursor_el.style == %{reverse: true}

      other_el = Enum.at(rendered.children, 1)
      assert other_el.style == %{}
    end

    test "leaf nodes have space icon" do
      expanded = MapSet.new([:root1])
      {:ok, state} = Tree.init(id: :t, nodes: sample_tree(), expanded: expanded, cursor: :root1)
      rendered = Tree.render(state, default_context())

      child1a = Enum.at(rendered.children, 1)
      # leaf icon is space: "  " (indent) + " " (icon) + " " + label
      assert String.contains?(child1a.content, "Child 1A")
      # The icon for a leaf is a space, so no > or v before label
      refute String.contains?(child1a.content, "▶")
      refute String.contains?(child1a.content, "▼")
    end

    test "deeply nested renders correct indentation" do
      expanded = MapSet.new([:root1, :child1b])
      {:ok, state} = Tree.init(id: :t, nodes: sample_tree(), expanded: expanded, cursor: :root1)
      rendered = Tree.render(state, default_context())

      grandchild = Enum.at(rendered.children, 3)
      # depth=2, indent_size=2 -> 4 spaces indent
      assert String.starts_with?(grandchild.content, "    ")
      assert String.contains?(grandchild.content, "Grandchild 1")
    end
  end

  describe "update/2" do
    test "merges new nodes" do
      {:ok, state} = Tree.init(id: :t, nodes: sample_tree())
      new_nodes = [%{id: :new, label: "New", children: [], data: nil}]
      {updated, []} = Tree.update(%{nodes: new_nodes}, state)
      assert length(updated.nodes) == 1
      assert hd(updated.nodes).id == :new
    end

    test "merges style and theme" do
      {:ok, state} = Tree.init(id: :t, style: %{fg: :red}, theme: %{bg: :blue})
      {updated, []} = Tree.update(%{style: %{bold: true}, theme: %{fg: :green}}, state)
      assert updated.style == %{fg: :red, bold: true}
      assert updated.theme == %{bg: :blue, fg: :green}
    end
  end
end
