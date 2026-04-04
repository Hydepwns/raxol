defmodule Raxol.UI.Components.Input.MenuTest do
  use ExUnit.Case, async: true

  alias Raxol.Core.Events.Event
  alias Raxol.UI.Components.Input.Menu

  defp default_context do
    %{theme: Raxol.UI.Theming.Theme.default_theme()}
  end

  defp key_event(key) do
    %Event{type: :key, data: %{key: key}}
  end

  defp sample_items do
    [
      %{id: :file, label: "File", disabled: false, shortcut: nil, children: [
        %{id: :new, label: "New", disabled: false, shortcut: "Ctrl+N", children: []},
        %{id: :open, label: "Open", disabled: false, shortcut: "Ctrl+O", children: []},
        %{id: :recent, label: "Recent", disabled: false, shortcut: nil, children: [
          %{id: :doc1, label: "doc1.txt", disabled: false, shortcut: nil, children: []},
          %{id: :doc2, label: "doc2.txt", disabled: false, shortcut: nil, children: []}
        ]}
      ]},
      %{id: :edit, label: "Edit", disabled: false, shortcut: nil, children: [
        %{id: :undo, label: "Undo", disabled: false, shortcut: "Ctrl+Z", children: []},
        %{id: :redo, label: "Redo", disabled: true, shortcut: "Ctrl+Y", children: []}
      ]},
      %{id: :help, label: "Help", disabled: false, shortcut: nil, children: []}
    ]
  end

  defp flat_items do
    [
      %{id: :cut, label: "Cut", disabled: false, shortcut: "Ctrl+X", children: []},
      %{id: :copy, label: "Copy", disabled: false, shortcut: "Ctrl+C", children: []},
      %{id: :paste, label: "Paste", disabled: false, shortcut: "Ctrl+V", children: []}
    ]
  end

  describe "init/1" do
    test "initializes with default values" do
      assert {:ok, state} = Menu.init(id: :m)
      assert state.id == :m
      assert state.items == []
      assert state.cursor == nil
      assert state.open_path == []
      assert state.focused == false
      assert state.on_select == nil
      assert state.style == %{}
      assert state.theme == %{}
    end

    test "initializes with provided props" do
      cb = fn _id -> :ok end

      assert {:ok, state} =
               Menu.init(
                 id: :m,
                 items: flat_items(),
                 on_select: cb,
                 focused: true,
                 style: %{bg: :blue},
                 theme: %{fg: :white}
               )

      assert state.items == flat_items()
      assert state.on_select == cb
      assert state.focused == true
    end

    test "cursor defaults to first non-disabled item" do
      items = [
        %{id: :a, label: "A", disabled: true, shortcut: nil, children: []},
        %{id: :b, label: "B", disabled: false, shortcut: nil, children: []}
      ]

      {:ok, state} = Menu.init(id: :m, items: items)
      assert state.cursor == :b
    end
  end

  describe "visible_items/1" do
    test "flat menu shows all top-level items" do
      {:ok, state} = Menu.init(id: :m, items: flat_items())
      visible = Menu.visible_items(state)
      assert length(visible) == 3
      assert Enum.map(visible, fn {item, depth} -> {item.id, depth} end) ==
               [{:cut, 0}, {:copy, 0}, {:paste, 0}]
    end

    test "nested menu with submenu open shows children" do
      {:ok, state} = Menu.init(id: :m, items: sample_items(), open_path: [:file])
      visible = Menu.visible_items(state)
      ids = Enum.map(visible, fn {item, _} -> item.id end)
      assert ids == [:file, :new, :open, :recent, :edit, :help]
    end

    test "deeply nested chain shows full path" do
      {:ok, state} = Menu.init(id: :m, items: sample_items(), open_path: [:file, :recent])
      visible = Menu.visible_items(state)
      ids = Enum.map(visible, fn {item, _} -> item.id end)
      assert ids == [:file, :new, :open, :recent, :doc1, :doc2, :edit, :help]

      depths = Enum.map(visible, fn {_, depth} -> depth end)
      assert depths == [0, 1, 1, 1, 2, 2, 0, 0]
    end
  end

  describe "navigation - up/down" do
    test "down moves to next enabled item" do
      {:ok, state} = Menu.init(id: :m, items: flat_items(), cursor: :cut)
      {new_state, []} = Menu.handle_event(key_event(:down), state, %{})
      assert new_state.cursor == :copy
    end

    test "up moves to previous enabled item" do
      {:ok, state} = Menu.init(id: :m, items: flat_items(), cursor: :paste)
      {new_state, []} = Menu.handle_event(key_event(:up), state, %{})
      assert new_state.cursor == :copy
    end

    test "down skips disabled items" do
      {:ok, state} = Menu.init(id: :m, items: sample_items(),
        open_path: [:edit], cursor: :undo)
      {new_state, []} = Menu.handle_event(key_event(:down), state, %{})
      # :redo is disabled, so should skip to :help
      assert new_state.cursor == :help
    end

    test "down at last item stays clamped" do
      {:ok, state} = Menu.init(id: :m, items: flat_items(), cursor: :paste)
      {new_state, []} = Menu.handle_event(key_event(:down), state, %{})
      assert new_state.cursor == :paste
    end

    test "up at first item stays clamped" do
      {:ok, state} = Menu.init(id: :m, items: flat_items(), cursor: :cut)
      {new_state, []} = Menu.handle_event(key_event(:up), state, %{})
      assert new_state.cursor == :cut
    end

    test "navigation through submenu items" do
      {:ok, state} = Menu.init(id: :m, items: sample_items(),
        open_path: [:file], cursor: :new)
      {s2, []} = Menu.handle_event(key_event(:down), state, %{})
      assert s2.cursor == :open
      {s3, []} = Menu.handle_event(key_event(:down), s2, %{})
      assert s3.cursor == :recent
    end
  end

  describe "submenu - right/left" do
    test "right opens submenu and moves cursor to first child" do
      {:ok, state} = Menu.init(id: :m, items: sample_items(), cursor: :file)
      {new_state, []} = Menu.handle_event(key_event(:right), state, %{})
      assert new_state.open_path == [:file]
      assert new_state.cursor == :new
    end

    test "right on leaf does nothing" do
      {:ok, state} = Menu.init(id: :m, items: flat_items(), cursor: :cut)
      {new_state, []} = Menu.handle_event(key_event(:right), state, %{})
      assert new_state.open_path == []
      assert new_state.cursor == :cut
    end

    test "right on already-open submenu does nothing" do
      {:ok, state} = Menu.init(id: :m, items: sample_items(),
        open_path: [:file], cursor: :file)
      {new_state, []} = Menu.handle_event(key_event(:right), state, %{})
      assert new_state.open_path == [:file]
    end

    test "left closes submenu and returns to parent" do
      {:ok, state} = Menu.init(id: :m, items: sample_items(),
        open_path: [:file], cursor: :new)
      {new_state, []} = Menu.handle_event(key_event(:left), state, %{})
      assert new_state.open_path == []
      assert new_state.cursor == :file
    end

    test "left with no open submenu does nothing" do
      {:ok, state} = Menu.init(id: :m, items: sample_items(), cursor: :file)
      {new_state, []} = Menu.handle_event(key_event(:left), state, %{})
      assert new_state == state
    end

    test "left closes only deepest submenu level" do
      {:ok, state} = Menu.init(id: :m, items: sample_items(),
        open_path: [:file, :recent], cursor: :doc1)
      {new_state, []} = Menu.handle_event(key_event(:left), state, %{})
      assert new_state.open_path == [:file]
      assert new_state.cursor == :recent
    end
  end

  describe "selection - enter/space" do
    test "enter on leaf fires on_select" do
      test_pid = self()
      cb = fn id -> send(test_pid, {:selected, id}) end

      {:ok, state} = Menu.init(id: :m, items: flat_items(),
        cursor: :copy, on_select: cb)
      {_new_state, []} = Menu.handle_event(key_event(:enter), state, %{})
      assert_receive {:selected, :copy}
    end

    test "space on leaf fires on_select" do
      test_pid = self()
      cb = fn id -> send(test_pid, {:selected, id}) end

      {:ok, state} = Menu.init(id: :m, items: flat_items(),
        cursor: :cut, on_select: cb)
      {_new_state, []} = Menu.handle_event(key_event(:space), state, %{})
      assert_receive {:selected, :cut}
    end

    test "enter on submenu parent opens it" do
      {:ok, state} = Menu.init(id: :m, items: sample_items(), cursor: :file)
      {new_state, []} = Menu.handle_event(key_event(:enter), state, %{})
      assert new_state.open_path == [:file]
      assert new_state.cursor == :new
    end

    test "enter on disabled item does nothing" do
      {:ok, state} = Menu.init(id: :m, items: sample_items(),
        open_path: [:edit], cursor: :redo)
      {new_state, []} = Menu.handle_event(key_event(:enter), state, %{})
      assert new_state == state
    end
  end

  describe "escape" do
    test "closes deepest open submenu" do
      {:ok, state} = Menu.init(id: :m, items: sample_items(),
        open_path: [:file, :recent], cursor: :doc1)
      {new_state, []} = Menu.handle_event(key_event(:escape), state, %{})
      assert new_state.open_path == [:file]
      assert new_state.cursor == :recent
    end

    test "does nothing when no submenu is open" do
      {:ok, state} = Menu.init(id: :m, items: sample_items(), cursor: :file)
      {new_state, []} = Menu.handle_event(key_event(:escape), state, %{})
      assert new_state == state
    end
  end

  describe "home/end" do
    test "home jumps to first visible enabled item" do
      {:ok, state} = Menu.init(id: :m, items: flat_items(), cursor: :paste)
      {new_state, []} = Menu.handle_event(key_event(:home), state, %{})
      assert new_state.cursor == :cut
    end

    test "end jumps to last visible enabled item" do
      {:ok, state} = Menu.init(id: :m, items: flat_items(), cursor: :cut)
      {new_state, []} = Menu.handle_event(key_event(:end), state, %{})
      assert new_state.cursor == :paste
    end

    test "home skips disabled first item" do
      items = [
        %{id: :a, label: "A", disabled: true, shortcut: nil, children: []},
        %{id: :b, label: "B", disabled: false, shortcut: nil, children: []},
        %{id: :c, label: "C", disabled: false, shortcut: nil, children: []}
      ]

      {:ok, state} = Menu.init(id: :m, items: items, cursor: :c)
      {new_state, []} = Menu.handle_event(key_event(:home), state, %{})
      assert new_state.cursor == :b
    end

    test "end skips disabled last item" do
      items = [
        %{id: :a, label: "A", disabled: false, shortcut: nil, children: []},
        %{id: :b, label: "B", disabled: false, shortcut: nil, children: []},
        %{id: :c, label: "C", disabled: true, shortcut: nil, children: []}
      ]

      {:ok, state} = Menu.init(id: :m, items: items, cursor: :a)
      {new_state, []} = Menu.handle_event(key_event(:end), state, %{})
      assert new_state.cursor == :b
    end
  end

  describe "render/2" do
    test "renders column layout" do
      {:ok, state} = Menu.init(id: :m, items: flat_items())
      rendered = Menu.render(state, default_context())
      assert rendered.type == :column
      assert length(rendered.children) == 3
    end

    test "cursor item has reverse style" do
      {:ok, state} = Menu.init(id: :m, items: flat_items(), cursor: :copy)
      rendered = Menu.render(state, default_context())

      cursor_child = Enum.at(rendered.children, 1)
      assert cursor_child.style == %{reverse: true}
    end

    test "disabled item has gray fg" do
      items = [
        %{id: :a, label: "A", disabled: false, shortcut: nil, children: []},
        %{id: :b, label: "B", disabled: true, shortcut: nil, children: []}
      ]

      {:ok, state} = Menu.init(id: :m, items: items, cursor: :a)
      rendered = Menu.render(state, default_context())

      disabled_child = Enum.at(rendered.children, 1)
      assert disabled_child.style == %{fg: :gray}
    end

    test "submenu parent shows > indicator" do
      {:ok, state} = Menu.init(id: :m, items: sample_items(), cursor: :edit)
      rendered = Menu.render(state, default_context())

      file_child = Enum.at(rendered.children, 0)
      assert String.contains?(file_child.content, ">")
    end

    test "shortcut text is rendered" do
      {:ok, state} = Menu.init(id: :m, items: flat_items(), cursor: :cut)
      rendered = Menu.render(state, default_context())

      cut_child = Enum.at(rendered.children, 0)
      assert String.contains?(cut_child.content, "Ctrl+X")
    end

    test "indentation increases with depth" do
      {:ok, state} = Menu.init(id: :m, items: sample_items(),
        open_path: [:file], cursor: :file)
      rendered = Menu.render(state, default_context())

      # First child (File) should have no indent
      file_child = Enum.at(rendered.children, 0)
      refute String.starts_with?(file_child.content, "  ")

      # Second child (New) should be indented
      new_child = Enum.at(rendered.children, 1)
      assert String.starts_with?(new_child.content, "  ")
    end

    test "empty menu renders empty column" do
      {:ok, state} = Menu.init(id: :m, items: [])
      rendered = Menu.render(state, default_context())
      assert rendered.type == :column
      assert rendered.children == []
    end
  end

  describe "update/2" do
    test "merges style and theme" do
      {:ok, state} = Menu.init(id: :m, style: %{fg: :red}, theme: %{bg: :blue})
      {updated, []} = Menu.update(%{style: %{bold: true}, theme: %{fg: :green}}, state)
      assert updated.style == %{fg: :red, bold: true}
      assert updated.theme == %{bg: :blue, fg: :green}
    end
  end

  describe "focus/blur" do
    test "focus sets focused to true" do
      {:ok, state} = Menu.init(id: :m, items: flat_items())
      {new_state, []} = Menu.handle_event(%Event{type: :focus}, state, %{})
      assert new_state.focused == true
    end

    test "blur sets focused to false" do
      {:ok, state} = Menu.init(id: :m, items: flat_items(), focused: true)
      {new_state, []} = Menu.handle_event(%Event{type: :blur}, state, %{})
      assert new_state.focused == false
    end
  end

  describe "pass-through" do
    test "unknown events pass through unchanged" do
      {:ok, state} = Menu.init(id: :m, items: flat_items())
      event = %Event{type: :key, data: %{key: :char, char: "x"}}
      {new_state, []} = Menu.handle_event(event, state, %{})
      assert new_state == state
    end
  end
end
