defmodule Raxol.Components.Progress.ProgressBarTest do
  use ExUnit.Case
  alias Raxol.Components.Progress.ProgressBar

  describe "init/1" do
    test "initializes with default values when no props provided" do
      state = ProgressBar.init(%{})
      assert state.value == 0
      assert state.width == 20
      assert state.style == :basic
      assert state.color == :blue
      assert state.gradient == nil
      assert state.characters == nil
      assert state.show_percentage == true
      assert state.label == nil
    end

    test "initializes with provided values" do
      props = %{
        value: 50,
        width: 30,
        style: :block,
        color: :green,
        gradient: [:red, :yellow, :green],
        characters: %{filled: "#", empty: "."},
        show_percentage: false,
        label: "Progress"
      }

      state = ProgressBar.init(props)
      assert state.value == 50
      assert state.width == 30
      assert state.style == :block
      assert state.color == :green
      assert state.gradient == [:red, :yellow, :green]
      assert state.characters == %{filled: "#", empty: "."}
      assert state.show_percentage == false
      assert state.label == "Progress"
    end
  end

  describe "update/2" do
    setup do
      {:ok, state: ProgressBar.init(%{})}
    end

    test "updates progress value", %{state: state} do
      new_state = ProgressBar.update({:set_progress, 75}, state)
      assert new_state.value == 75
    end

    test "updates style", %{state: state} do
      new_state = ProgressBar.update({:set_style, :block}, state)
      assert new_state.style == :block
    end

    test "updates color and clears gradient", %{state: state} do
      state_with_gradient = %{state | gradient: [:red, :green]}
      new_state = ProgressBar.update({:set_color, :red}, state_with_gradient)
      assert new_state.color == :red
      assert new_state.gradient == nil
    end

    test "updates gradient and clears color", %{state: state} do
      gradient = [:red, :yellow, :green]
      new_state = ProgressBar.update({:set_gradient, gradient}, state)
      assert new_state.gradient == gradient
      assert new_state.color == nil
    end

    test "updates custom characters", %{state: state} do
      chars = %{filled: "#", empty: "."}
      new_state = ProgressBar.update({:set_characters, chars}, state)
      assert new_state.characters == chars
    end

    test "ignores invalid progress values", %{state: state} do
      assert state == ProgressBar.update({:set_progress, 101}, state)
      assert state == ProgressBar.update({:set_progress, -1}, state)
    end
  end

  describe "handle_event/2" do
    setup do
      {:ok, state: ProgressBar.init(%{})}
    end

    test "handles progress update events", %{state: state} do
      event = %Raxol.Core.Events.Event{type: :progress_update, value: 60}
      {new_state, _commands} = ProgressBar.handle_event(event, state)
      assert new_state.value == 60
    end
  end

  describe "public API" do
    test "set_progress/1 returns correct message" do
      assert ProgressBar.set_progress(50) == {:progress_update, 50}
    end

    test "set_style/1 returns correct message" do
      assert ProgressBar.set_style(:block) == {:set_style, :block}
      assert ProgressBar.set_style(:custom) == {:set_style, :custom}
    end

    test "set_color/1 returns correct message" do
      assert ProgressBar.set_color(:red) == {:set_color, :red}
    end

    test "set_gradient/1 returns correct message" do
      gradient = [:red, :yellow, :green]
      assert ProgressBar.set_gradient(gradient) == {:set_gradient, gradient}
    end

    test "set_characters/2 returns correct message" do
      assert ProgressBar.set_characters("#", ".") ==
               {:set_characters, %{filled: "#", empty: "."}}
    end
  end
end
