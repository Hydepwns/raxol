defmodule Raxol.Components.Selection.ListTest do
  use ExUnit.Case
  alias Raxol.Components.Selection.List
  alias Raxol.Core.Events.Event

  describe "init/1" do
    test "initializes with default values when no props provided" do
      state = List.init(%{})
      assert state.items == []
      assert state.filtered_items == []
      assert state.selected_index == 0
      assert state.height == 10
      assert state.width == 40
      assert state.filter == ""
      assert state.scroll_offset == 0
      assert state.focused == false
      assert state.on_select == nil
      assert state.on_submit == nil
      assert is_function(state.render_item)
      assert is_function(state.filter_item)
    end

    test "initializes with provided values" do
      on_select = fn _ -> nil end
      on_submit = fn _ -> nil end
      render_item = fn item -> "Item: #{item}" end
      filter_item = fn item, filter -> String.starts_with?(item, filter) end
      
      props = %{
        items: ["one", "two", "three"],
        selected_index: 1,
        height: 5,
        width: 30,
        style: %{text_color: :red},
        filter: "t",
        render_item: render_item,
        filter_item: filter_item,
        on_select: on_select,
        on_submit: on_submit
      }

      state = List.init(props)
      assert state.items == ["one", "two", "three"]
      assert state.filtered_items == ["two", "three"]
      assert state.selected_index == 1
      assert state.height == 5
      assert state.width == 30
      assert state.style.text_color == :red
      assert state.filter == "t"
      assert state.render_item == render_item
      assert state.filter_item == filter_item
      assert state.on_select == on_select
      assert state.on_submit == on_submit
    end
  end

  describe "update/2" do
    setup do
      state = List.init(%{
        items: ["one", "two", "three"],
        selected_index: 1
      })
      {:ok, state: state}
    end

    test "sets items and resets selection", %{state: state} do
      new_state = List.update({:set_items, ["four", "five"]}, state)
      assert new_state.items == ["four", "five"]
      assert new_state.filtered_items == ["four", "five"]
      assert new_state.selected_index == 0
      assert new_state.scroll_offset == 0
    end

    test "sets filter and updates filtered items", %{state: state} do
      new_state = List.update({:set_filter, "t"}, state)
      assert new_state.filter == "t"
      assert new_state.filtered_items == ["two", "three"]
      assert new_state.selected_index == 0
      assert new_state.scroll_offset == 0
    end

    test "selects index within bounds", %{state: state} do
      new_state = List.update({:select_index, 2}, state)
      assert new_state.selected_index == 2

      new_state = List.update({:select_index, -1}, state)
      assert new_state.selected_index == 0

      new_state = List.update({:select_index, 100}, state)
      assert new_state.selected_index == 2
    end

    test "handles scrolling", %{state: state} do
      # Set up state with scroll offset
      state = %{state | scroll_offset: 5}
      
      # Scroll up
      new_state = List.update(:scroll_up, state)
      assert new_state.scroll_offset == 4

      # Scroll down
      new_state = List.update(:scroll_down, state)
      assert new_state.scroll_offset == 5
    end

    test "handles focus and blur", %{state: state} do
      new_state = List.update(:focus, state)
      assert new_state.focused == true

      new_state = List.update(:blur, new_state)
      assert new_state.focused == false
    end

    test "calls on_select when selecting item", %{state: state} do
      test_pid = self()
      state = %{state | on_select: fn item -> send(test_pid, {:selected, item}) end}
      
      List.update({:select_index, 2}, state)
      assert_received {:selected, "three"}
    end
  end

  describe "handle_event/2" do
    setup do
      state = List.init(%{
        items: ["one", "two", "three"],
        selected_index: 1
      })
      {:ok, state: %{state | focused: true}}
    end

    test "handles arrow keys", %{state: state} do
      # Up
      event = %Event{type: :key, key: "ArrowUp"}
      {new_state, _} = List.handle_event(event, state)
      assert new_state.selected_index == 0

      # Down
      event = %Event{type: :key, key: "ArrowDown"}
      {new_state, _} = List.handle_event(event, state)
      assert new_state.selected_index == 2
    end

    test "handles page navigation", %{state: state} do
      # PageUp
      event = %Event{type: :key, key: "PageUp"}
      {new_state, _} = List.handle_event(event, state)
      assert new_state.selected_index == 0

      # PageDown
      event = %Event{type: :key, key: "PageDown"}
      {new_state, _} = List.handle_event(event, state)
      assert new_state.selected_index == 2

      # Home
      event = %Event{type: :key, key: "Home"}
      {new_state, _} = List.handle_event(event, state)
      assert new_state.selected_index == 0

      # End
      event = %Event{type: :key, key: "End"}
      {new_state, _} = List.handle_event(event, state)
      assert new_state.selected_index == 2
    end

    test "handles Enter key", %{state: state} do
      test_pid = self()
      state = %{state | on_submit: fn item -> send(test_pid, {:submitted, item}) end}
      
      event = %Event{type: :key, key: "Enter"}
      List.handle_event(event, state)
      
      assert_received {:submitted, "two"}
    end

    test "handles type-ahead search", %{state: state} do
      # Type 't'
      event = %Event{type: :key, key: "t"}
      {new_state, _} = List.handle_event(event, state)
      assert new_state.filter == "t"
      assert new_state.filtered_items == ["two", "three"]
      assert new_state.selected_index == 0

      # Backspace
      event = %Event{type: :key, key: "Backspace"}
      {new_state, _} = List.handle_event(event, new_state)
      assert new_state.filter == ""
      assert new_state.filtered_items == ["one", "two", "three"]
      assert new_state.selected_index == 0
    end

    test "handles scroll events", %{state: state} do
      # Scroll up
      event = %Event{type: :scroll, direction: :up}
      {new_state, _} = List.handle_event(event, %{state | scroll_offset: 1})
      assert new_state.scroll_offset == 0

      # Scroll down
      event = %Event{type: :scroll, direction: :down}
      {new_state, _} = List.handle_event(event, state)
      assert new_state.scroll_offset == 1
    end
  end

  describe "filtering" do
    test "uses custom filter function" do
      filter_fn = fn item, filter -> String.starts_with?(item, filter) end
      
      state = List.init(%{
        items: ["one", "two", "three"],
        filter: "t",
        filter_item: filter_fn
      })

      assert state.filtered_items == ["two", "three"]
    end

    test "uses default case-insensitive filter" do
      state = List.init(%{
        items: ["One", "Two", "Three"],
        filter: "t"
      })

      assert state.filtered_items == ["Two", "Three"]
    end
  end

  describe "rendering" do
    test "uses custom render function" do
      render_fn = fn item -> "Item: #{item}" end
      
      state = List.init(%{
        items: ["one"],
        render_item: render_fn
      })

      assert state.render_item.("test") == "Item: test"
    end

    test "uses default to_string rendering" do
      state = List.init(%{items: [1, :two, "three"]})
      
      assert state.render_item.(1) == "1"
      assert state.render_item.(:two) == "two"
      assert state.render_item.("three") == "three"
    end
  end
end 