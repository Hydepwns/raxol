defmodule Raxol.UI.Components.Progress.ProgressBarTest do
  use ExUnit.Case, async: true

  alias Raxol.UI.Components.Progress.ProgressBar
  alias Raxol.Core.Events.Event

  describe "init/1" do
    test "initializes with default values when no props provided" do
      state = ProgressBar.init(%{})
      assert state.value == 0
      assert state.max == 100
      assert state.width == 20
      assert Map.has_key?(state, :style)
      assert state.style == %{}
      assert state.label == nil
      assert state.label_position == :below
      assert state.show_percentage == false
    end

    test "initializes with provided values" do
      props = %{
        id: :my_bar,
        value: 50,
        max: 200,
        width: 30,
        style: %{filled: %{bg: :blue}},
        label: "Loading...",
        label_position: :above,
        show_percentage: true
      }

      state = ProgressBar.init(props)
      assert state.id == :my_bar
      assert state.value == 50
      assert state.max == 200
      assert state.width == 30
      assert state.style == %{filled: %{bg: :blue}}
      assert state.label == "Loading..."
      assert state.label_position == :above
      assert state.show_percentage == true
    end
  end

  describe "update/2" do
    setup do
      state = ProgressBar.init(%{value: 10})
      {:ok, state: state}
    end

    test "updates progress value", %{state: state} do
      {new_state, _} = ProgressBar.update({:set_value, 75}, state)
      assert new_state.value == 75
    end

    test "clamps progress value to max", %{state: state} do
      {new_state, _} = ProgressBar.update({:set_value, 150}, state)
      # Clamped to max (default 100)
      assert new_state.value == 100
    end

    test "clamps progress value to min", %{state: state} do
      {new_state, _} = ProgressBar.update({:set_value, -10}, state)
      # Clamped to min 0
      assert new_state.value == 0
    end

    test "ignores non-numeric progress values", %{state: state} do
      {new_state, _} = ProgressBar.update({:set_value, "invalid"}, state)
      # Should ignore and return original state
      assert new_state == state
    end
  end

  describe "handle_event/3" do
    setup do
      state = ProgressBar.init(%{})
      {:ok, state: state}
    end

    test "ignores events", %{state: state} do
      event = %Event{type: :key, data: %{key: "a"}}
      {new_state, commands} = ProgressBar.handle_event(event, %{}, state)
      assert new_state == state
      assert commands == []
    end
  end
end
