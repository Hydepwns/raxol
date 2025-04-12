defmodule Raxol.Components.Selection.DropdownTest do
  use ExUnit.Case
  alias Raxol.Components.Selection.Dropdown
  alias Raxol.Core.Events.Event

  describe "init/1" do
    test "initializes with default values when no props provided" do
      state = Dropdown.init(%{})
      assert state.items == []
      assert state.selected_item == nil
      assert state.placeholder == "Select..."
      assert state.width == 30
      assert state.max_height == 10
      assert state.is_open == false
      assert state.filter == ""
      assert state.focused == false
      assert state.on_change == nil
      assert is_function(state.render_item)
      assert is_function(state.filter_item)
      assert state.list_state != nil
    end

    test "initializes with provided values" do
      on_change = fn _ -> nil end
      render_item = fn item -> "Item: #{item}" end
      filter_item = fn item, filter -> String.starts_with?(item, filter) end

      props = %{
        items: ["one", "two", "three"],
        selected_item: "two",
        placeholder: "Choose...",
        width: 40,
        max_height: 5,
        style: %{text_color: :red},
        render_item: render_item,
        filter_item: filter_item,
        on_change: on_change
      }

      state = Dropdown.init(props)
      assert state.items == ["one", "two", "three"]
      assert state.selected_item == "two"
      assert state.placeholder == "Choose..."
      assert state.width == 40
      assert state.max_height == 5
      assert state.style.text_color == :red
      assert state.render_item == render_item
      assert state.filter_item == filter_item
      assert state.on_change == on_change

      # Check that list state was initialized correctly
      assert state.list_state.items == ["one", "two", "three"]
      # width - 2 for borders
      assert state.list_state.width == 38
      assert state.list_state.height == 5
    end
  end

  describe "update/2" do
    setup do
      state =
        Dropdown.init(%{
          items: ["one", "two", "three"],
          selected_item: "two"
        })

      {:ok, state: state}
    end

    test "sets items", %{state: state} do
      new_state = Dropdown.update({:set_items, ["four", "five"]}, state)
      assert new_state.items == ["four", "five"]
      assert new_state.list_state.items == ["four", "five"]
    end

    test "selects item", %{state: state} do
      test_pid = self()

      state = %{
        state
        | on_change: fn item -> send(test_pid, {:changed, item}) end
      }

      new_state = Dropdown.update({:select_item, "three"}, state)
      assert new_state.selected_item == "three"
      assert new_state.is_open == false
      assert new_state.filter == ""
      assert_received {:changed, "three"}
    end

    test "sets filter", %{state: state} do
      new_state = Dropdown.update({:set_filter, "t"}, state)
      assert new_state.filter == "t"
      assert new_state.list_state.filter == "t"
    end

    test "toggles dropdown", %{state: state} do
      new_state = Dropdown.update(:toggle, state)
      assert new_state.is_open == true
      assert new_state.filter == ""
      assert new_state.focused == true

      new_state = Dropdown.update(:toggle, new_state)
      assert new_state.is_open == false
      assert new_state.filter == ""
    end

    test "closes dropdown", %{state: state} do
      state = %{state | is_open: true, filter: "test"}
      new_state = Dropdown.update(:close, state)
      assert new_state.is_open == false
      assert new_state.filter == ""
    end

    test "handles focus and blur", %{state: state} do
      new_state = Dropdown.update(:focus, state)
      assert new_state.focused == true

      new_state = Dropdown.update(:blur, new_state)
      assert new_state.focused == false
      assert new_state.is_open == false
    end
  end

  describe "handle_event/2" do
    setup do
      state =
        Dropdown.init(%{
          items: ["one", "two", "three"],
          selected_item: "two"
        })

      {:ok, state: %{state | focused: true}}
    end

    test "toggles on space key", %{state: state} do
      event = %Event{type: :key, key: " "}
      {new_state, _} = Dropdown.handle_event(event, state)
      assert new_state.is_open == true

      {new_state, _} =
        Dropdown.handle_event(event, %{new_state | is_open: true})

      # Space only opens, doesn't close
      assert new_state.is_open == true
    end

    test "closes on escape key", %{state: state} do
      state = %{state | is_open: true}
      event = %Event{type: :key, key: "Escape"}
      {new_state, _} = Dropdown.handle_event(event, state)
      assert new_state.is_open == false
    end

    test "handles type-ahead search when open", %{state: state} do
      state = %{state | is_open: true}

      # Type 't'
      event = %Event{type: :key, key: "t"}
      {new_state, _} = Dropdown.handle_event(event, state)
      assert new_state.filter == "t"
      assert new_state.list_state.filter == "t"

      # Backspace
      event = %Event{type: :key, key: "Backspace"}
      {new_state, _} = Dropdown.handle_event(event, new_state)
      assert new_state.filter == ""
      assert new_state.list_state.filter == ""
    end

    test "delegates list events when open", %{state: state} do
      state = %{state | is_open: true}

      # Arrow down should be handled by list component
      event = %Event{type: :key, key: "ArrowDown"}
      {new_state, _} = Dropdown.handle_event(event, state)
      assert new_state.list_state.selected_index == 1
    end

    test "handles click events", %{state: state} do
      event = %Event{type: :click}
      {new_state, _} = Dropdown.handle_event(event, state)
      assert new_state.is_open == true
      assert new_state.focused == true

      {new_state, _} = Dropdown.handle_event(event, new_state)
      assert new_state.is_open == false
    end

    test "handles blur events", %{state: state} do
      state = %{state | is_open: true}
      event = %Event{type: :blur}
      {new_state, _} = Dropdown.handle_event(event, state)
      assert new_state.focused == false
      assert new_state.is_open == false
    end
  end

  describe "filtering" do
    test "uses custom filter function" do
      filter_fn = fn item, filter -> String.starts_with?(item, filter) end

      state =
        Dropdown.init(%{
          items: ["one", "two", "three"],
          filter_item: filter_fn
        })

      state = Dropdown.update({:set_filter, "t"}, state)
      assert state.list_state.filtered_items == ["two", "three"]
    end

    test "uses default case-insensitive filter" do
      state =
        Dropdown.init(%{
          items: ["One", "Two", "Three"]
        })

      state = Dropdown.update({:set_filter, "t"}, state)
      assert state.list_state.filtered_items == ["Two", "Three"]
    end
  end

  describe "rendering" do
    test "uses custom render function" do
      render_fn = fn item -> "Item: #{item}" end

      state =
        Dropdown.init(%{
          items: ["one"],
          selected_item: "one",
          render_item: render_fn
        })

      assert state.render_item.("test") == "Item: test"
    end

    test "uses default to_string rendering" do
      state =
        Dropdown.init(%{
          items: [1, :two, "three"],
          selected_item: :two
        })

      assert state.render_item.(1) == "1"
      assert state.render_item.(:two) == "two"
      assert state.render_item.("three") == "three"
    end
  end
end
