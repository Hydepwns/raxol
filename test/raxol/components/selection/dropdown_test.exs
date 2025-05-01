defmodule Raxol.Components.Selection.DropdownTest do
  use ExUnit.Case, async: true

  alias Raxol.Components.Selection.Dropdown
  alias Raxol.Components.Selection.List
  alias Raxol.Core.Events.Event

  describe "init/1" do
    test "initializes with default values when no props provided" do
      state = Dropdown.init(%{id: :dd1})
      assert state.id == :dd1
      assert state.options == []
      assert state.selected_option == nil
      assert state.expanded == false
      assert state.width == 20
      assert state.list_height == 5
      assert state.style == %{}
      assert state.focused == false
      assert state.on_change == nil
      assert is_struct(state.list_state, List) # Check list state initialized
      assert state.list_state.items == []
    end

    test "initializes with provided values" do
      on_change_func = fn _ -> :changed end
      options = ["one", "two", "three"]
      props = %{
        id: :my_dd,
        options: options,
        initial_value: "two",
        width: 40,
        list_height: 10,
        style: %{color: :red},
        on_change: on_change_func
      }

      state = Dropdown.init(props)
      assert state.id == :my_dd
      assert state.options == options
      assert state.selected_option == "two"
      assert state.expanded == false
      assert state.width == 40
      assert state.list_height == 10
      assert state.style == %{color: :red}
      assert state.focused == false
      assert state.on_change == on_change_func
      assert state.list_state.items == options
      assert state.list_state.height == 10
    end
  end

  describe "update/2" do
    setup do
      state = Dropdown.init(%{id: :dd_update, options: ["a", "b", "c"]})
      {:ok, state: state}
    end

    test "updates selected option on :list_item_selected message", %{state: state} do
      change_value = :not_changed
      on_change_func = fn value -> change_value = value end
      state_with_cb = %{state | on_change: on_change_func}

      {new_state, commands} = Dropdown.update({:list_item_selected, "b"}, state_with_cb)
      assert new_state.selected_option == "b"
      assert new_state.expanded == false # Should close on selection
      assert [{^on_change_func, "b"}] = commands # Check on_change command
    end

    test "toggles expansion on :toggle_expand message", %{state: state} do
      # Expand
      {expanded_state, _} = Dropdown.update(:toggle_expand, state)
      assert expanded_state.expanded == true
      assert expanded_state.list_state.focused == true

      # Collapse
      {collapsed_state, _} = Dropdown.update(:toggle_expand, expanded_state)
      assert collapsed_state.expanded == false
      assert collapsed_state.list_state.focused == false
    end

    test "handles focus and blur", %{state: state} do
      # Focus
      {focused_state, _} = Dropdown.update(:focus, state)
      assert focused_state.focused == true

      # Blur (should also collapse)
      state_expanded = %{focused_state | expanded: true}
      {blurred_state, _} = Dropdown.update(:blur, state_expanded)
      assert blurred_state.focused == false
      assert blurred_state.expanded == false
    end
  end

  describe "handle_event/3" do
    setup do
      state = Dropdown.init(%{id: :dd_event, options: ["Apple", "Banana", "Cherry"]})
      {:ok, state: state}
    end

    test "toggles on Enter key when collapsed", %{state: state} do
      event = %Event{type: :key, data: %{key: "Enter", modifiers: []}}
      {new_state, _} = Dropdown.handle_event(event, %{}, state)
      assert new_state.expanded == true
    end

    test "closes on Escape key when expanded", %{state: state} do
      state_expanded = %{state | expanded: true}
      event = %Event{type: :key, data: %{key: "Escape", modifiers: []}}
      {new_state, _} = Dropdown.handle_event(event, %{}, state_expanded)
      assert new_state.expanded == false
    end

    test "delegates list events when expanded", %{state: state} do
       state_expanded = %{state | expanded: true}
       # Simulate Down Arrow key
       event = %Event{type: :key, data: %{key: "Down", modifiers: []}}
       {new_state, _} = Dropdown.handle_event(event, %{}, state_expanded)
       # Check if list state selected_index changed
       assert new_state.list_state.selected_index == 1 # Assuming List handles Down key
    end

    test "handles mouse click to toggle", %{state: state} do
      event = %Event{type: :mouse, data: %{button: :left, action: :press}}
      # Expand
      {expanded_state, _} = Dropdown.handle_event(event, %{}, state)
      assert expanded_state.expanded == true
      # Collapse
      {collapsed_state, _} = Dropdown.handle_event(event, %{}, expanded_state)
       assert collapsed_state.expanded == false
    end

    test "handles blur via :blur message", %{state: state} do
      state_expanded_focused = %{state | expanded: true, focused: true}
      {blurred_state, _} = Dropdown.update(:blur, state_expanded_focused)
      assert blurred_state.focused == false
      assert blurred_state.expanded == false # Should close on blur
    end
  end
end
