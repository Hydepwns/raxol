defmodule Raxol.UI.Components.Selection.DropdownTest do
  use ExUnit.Case, async: true

  alias Raxol.UI.Components.Selection.Dropdown
  alias Raxol.UI.Components.Selection.List
  alias Raxol.Core.Events.Event

  describe "init/1" do
    test "initializes with default values when no props provided" do
      state = Dropdown.init(%{id: :dd1})
      assert Map.get(state, :id) == :dd1
      assert Map.get(state, :options) == []
      assert Map.get(state, :selected_option) == nil
      assert Map.get(state, :expanded) == false
      assert Map.get(state, :width) == 20
      assert Map.get(state, :list_height) == 5
      assert Map.get(state, :style) == %{}
      assert Map.get(state, :focused) == false
      assert Map.get(state, :on_change) == nil
      # Check list state initialized
      assert is_struct(Map.get(state, :list_state), List)
      assert Map.get(Map.get(state, :list_state), :items) == []
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
      assert Map.get(state, :id) == :my_dd
      assert Map.get(state, :options) == options
      assert Map.get(state, :selected_option) == "two"
      assert Map.get(state, :expanded) == false
      assert Map.get(state, :width) == 40
      assert Map.get(state, :list_height) == 10
      assert Map.get(state, :style) == %{color: :red}
      assert Map.get(state, :focused) == false
      assert Map.get(state, :on_change) == on_change_func
      assert Map.get(Map.get(state, :list_state), :items) == options
      assert Map.get(Map.get(state, :list_state), :height) == 10
    end
  end

  describe "update/2" do
    setup do
      state = Dropdown.init(%{id: :dd_update, options: ["a", "b", "c"]})
      {:ok, state: state}
    end

    test "updates selected option on :list_item_selected message", %{
      state: state
    } do
      on_change_func = fn _value -> :ok end
      state_with_cb = %{state | on_change: on_change_func}

      {new_state, commands} =
        Dropdown.update({:list_item_selected, "b"}, state_with_cb)

      assert Map.get(new_state, :selected_option) == "b"
      # Should close on selection
      assert Map.get(new_state, :expanded) == false
      # Check on_change command
      assert [{^on_change_func, "b"}] = commands
    end

    test "toggles expansion on :toggle_expand message", %{state: state} do
      # Expand
      {expanded_state, _} = Dropdown.update(:toggle_expand, state)
      assert Map.get(expanded_state, :expanded) == true
      assert Map.get(Map.get(expanded_state, :list_state), :focused) == true

      # Collapse
      {collapsed_state, _} = Dropdown.update(:toggle_expand, expanded_state)
      assert Map.get(collapsed_state, :expanded) == false
      assert Map.get(Map.get(collapsed_state, :list_state), :focused) == false
    end

    test "handles focus and blur", %{state: state} do
      # Focus
      {focused_state, _} = Dropdown.update(:focus, state)
      assert Map.get(focused_state, :focused) == true

      # Blur (should also collapse)
      state_expanded = %{focused_state | expanded: true}
      {blurred_state, _} = Dropdown.update(:blur, state_expanded)
      assert Map.get(blurred_state, :focused) == false
      assert Map.get(blurred_state, :expanded) == false
    end
  end

  describe "handle_event/3" do
    setup do
      state =
        Dropdown.init(%{id: :dd_event, options: ["Apple", "Banana", "Cherry"]})

      {:ok, state: state}
    end

    test "toggles on Enter key when collapsed", %{state: state} do
      event = %Event{type: :key, data: %{key: "Enter", modifiers: []}}
      {new_state, _} = Dropdown.handle_event(event, %{}, state)
      assert Map.get(new_state, :expanded) == true
    end

    test "closes on Escape key when expanded", %{state: state} do
      state_expanded = %{state | expanded: true}
      event = %Event{type: :key, data: %{key: "Escape", modifiers: []}}
      {new_state, _} = Dropdown.handle_event(event, %{}, state_expanded)
      assert Map.get(new_state, :expanded) == false
    end

    test "delegates list events when expanded", %{state: state} do
      state_expanded = %{state | expanded: true}
      # Simulate Down Arrow key
      event = %Event{type: :key, data: %{key: "Down", modifiers: []}}
      {new_state, _} = Dropdown.handle_event(event, %{}, state_expanded)
      # Check if list state selected_index changed
      # Assuming List handles Down key
      assert Map.get(new_state, :list_state)[:selected_index] == 1
    end

    test "handles mouse click to toggle", %{state: state} do
      event = %Event{type: :mouse, data: %{button: :left, action: :press}}
      # Expand
      {expanded_state, _} = Dropdown.handle_event(event, %{}, state)
      assert Map.get(expanded_state, :expanded) == true
      # Collapse
      {collapsed_state, _} = Dropdown.handle_event(event, %{}, expanded_state)
      assert Map.get(collapsed_state, :expanded) == false
    end

    test "handles blur via :blur message", %{state: state} do
      state_expanded_focused = %{state | expanded: true, focused: true}
      {blurred_state, _} = Dropdown.update(:blur, state_expanded_focused)
      assert Map.get(blurred_state, :focused) == false
      # Should close on blur
      assert Map.get(blurred_state, :expanded) == false
    end
  end
end
