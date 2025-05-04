defmodule Raxol.Terminal.ANSI.WindowManipulationTest do
  use ExUnit.Case
  alias Raxol.Terminal.ANSI.WindowManipulation

  describe "new/0" do
    test "creates a new window state with default values" do
      state = WindowManipulation.new()

      assert state.title == ""
      assert state.icon_name == ""
      assert state.size == {80, 24}
      assert state.position == {0, 0}
      assert state.stacking_order == :normal
    end
  end

  describe "process_sequence/2" do
    test "handles window move operation" do
      state = WindowManipulation.new()

      {new_state, response} =
        WindowManipulation.process_sequence(state, "\e[3;10t")

      assert new_state.position == {10, 3}
      assert response == ""
    end

    test "handles window resize operation" do
      state = WindowManipulation.new()

      {new_state, response} =
        WindowManipulation.process_sequence(state, "\e[8;30;100t")

      assert new_state.size == {100, 30}
      assert response == ""
    end

    test "handles window maximize operation" do
      state = WindowManipulation.new()

      {new_state, response} =
        WindowManipulation.process_sequence(state, "\e[1;1t")

      assert new_state.size == {9999, 9999}
      assert response == ""
    end

    test "handles window restore operation" do
      state = %{WindowManipulation.new() | size: {100, 50}}

      {new_state, response} =
        WindowManipulation.process_sequence(state, "\e[1;0t")

      assert new_state.size == {80, 24}
      assert response == ""
    end

    test "handles window raise operation" do
      state = WindowManipulation.new()

      {new_state, response} =
        WindowManipulation.process_sequence(state, "\e[5t")

      assert new_state.stacking_order == :above
      assert response == ""
    end

    test "handles window lower operation" do
      state = WindowManipulation.new()

      {new_state, response} =
        WindowManipulation.process_sequence(state, "\e[6t")

      assert new_state.stacking_order == :below
      assert response == ""
    end

    test "handles window title setting" do
      state = WindowManipulation.new()

      {new_state, response} =
        WindowManipulation.process_sequence(state, "\e]0;New Title\a")

      assert new_state.title == "New Title"
      assert response == ""
    end

    test "handles window icon setting" do
      state = WindowManipulation.new()

      {new_state, response} =
        WindowManipulation.process_sequence(state, "\e]1;New Icon\a")

      assert new_state.icon_name == "New Icon"
      assert response == ""
    end

    test "handles window query operation" do
      state = %{WindowManipulation.new() | size: {100, 50}, position: {10, 5}}

      {new_state, response} =
        WindowManipulation.process_sequence(state, "\e[13t")

      assert new_state == state
      assert response == "\e[8;50;100t\e[3;5;10t"
    end

    test "handles invalid sequence" do
      state = WindowManipulation.new()

      {new_state, response} =
        WindowManipulation.process_sequence(state, "\e[invalid")

      assert new_state == state
      assert response == ""
    end
  end
end
