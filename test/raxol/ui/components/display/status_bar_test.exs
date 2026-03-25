defmodule Raxol.UI.Components.Display.StatusBarTest do
  use ExUnit.Case, async: true

  alias Raxol.UI.Components.Display.StatusBar
  alias Raxol.Core.Events.Event

  defp default_context do
    %{theme: Raxol.UI.Theming.Theme.default_theme()}
  end

  describe "init/1" do
    test "initializes with default values" do
      assert {:ok, state} = StatusBar.init(id: :sb1)
      assert state.id == :sb1
      assert state.items == []
      assert state.separator == " | "
      assert state.style == %{}
      assert state.theme == %{}
    end

    test "initializes with provided props" do
      items = [%{key: "Mode", label: "Normal"}, %{key: "File", label: "test.ex"}]

      assert {:ok, state} =
               StatusBar.init(
                 id: :sb2,
                 items: items,
                 separator: " - ",
                 style: %{bg: :blue},
                 theme: %{fg: :white}
               )

      assert state.id == :sb2
      assert state.items == items
      assert state.separator == " - "
      assert state.style == %{bg: :blue}
      assert state.theme == %{fg: :white}
    end
  end

  describe "render/2" do
    test "renders empty status bar" do
      {:ok, state} = StatusBar.init(id: :sb_empty)
      rendered = StatusBar.render(state, default_context())

      assert rendered.type == :row
      assert rendered.children == []
    end

    test "renders single item with bold key" do
      {:ok, state} = StatusBar.init(id: :sb_one, items: [%{key: "Mode", label: "Normal"}])
      rendered = StatusBar.render(state, default_context())

      assert rendered.type == :row
      assert length(rendered.children) == 2

      key_el = Enum.at(rendered.children, 0)
      assert key_el.content == "Mode: "
      assert key_el.style == %{bold: true}

      val_el = Enum.at(rendered.children, 1)
      assert val_el.content == "Normal"
    end

    test "renders multiple items with separators" do
      items = [%{key: "A", label: "1"}, %{key: "B", label: "2"}, %{key: "C", label: "3"}]
      {:ok, state} = StatusBar.init(id: :sb_multi, items: items)
      rendered = StatusBar.render(state, default_context())

      # 3 items * 2 elements each + 2 separators = 8
      assert length(rendered.children) == 8

      # Check separator positions (indices 2, 5)
      sep1 = Enum.at(rendered.children, 2)
      assert sep1.content == " | "

      sep2 = Enum.at(rendered.children, 5)
      assert sep2.content == " | "
    end

    test "uses custom separator" do
      items = [%{key: "A", label: "1"}, %{key: "B", label: "2"}]
      {:ok, state} = StatusBar.init(id: :sb_sep, items: items, separator: " :: ")
      rendered = StatusBar.render(state, default_context())

      sep = Enum.at(rendered.children, 2)
      assert sep.content == " :: "
    end

    test "no trailing separator after last item" do
      items = [%{key: "A", label: "1"}, %{key: "B", label: "2"}]
      {:ok, state} = StatusBar.init(id: :sb_trail, items: items)
      rendered = StatusBar.render(state, default_context())

      last = List.last(rendered.children)
      assert last.content == "2"
    end
  end

  describe "update/2" do
    test "merges new items" do
      {:ok, state} = StatusBar.init(id: :sb_up)
      new_items = [%{key: "X", label: "Y"}]
      {updated, []} = StatusBar.update(%{items: new_items}, state)
      assert updated.items == new_items
    end

    test "merges style and theme" do
      {:ok, state} = StatusBar.init(id: :sb_up2, style: %{fg: :red}, theme: %{bg: :blue})
      {updated, []} = StatusBar.update(%{style: %{bold: true}, theme: %{fg: :green}}, state)
      assert updated.style == %{fg: :red, bold: true}
      assert updated.theme == %{bg: :blue, fg: :green}
    end
  end

  describe "handle_event/3" do
    test "passes through all events unchanged" do
      {:ok, state} = StatusBar.init(id: :sb_evt, items: [%{key: "A", label: "1"}])

      event = %Event{type: :key, data: %{key: :enter}}
      {new_state, []} = StatusBar.handle_event(event, state, %{})
      assert new_state == state
    end
  end
end
