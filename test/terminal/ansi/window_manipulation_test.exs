defmodule Raxol.Terminal.ANSI.WindowManipulationTest do
  use ExUnit.Case
  alias Raxol.Terminal.ANSI.WindowManipulation

  describe "new/0" do
    test ~c"creates a new window state with default values" do
      state = WindowManipulation.new()

      assert state.title == ""
      assert state.icon_name == ""
      assert state.size == {80, 24}
      assert state.position == {0, 0}
      assert state.stacking_order == :normal
    end
  end

  describe "process_sequence/2" do
    test ~c"handles window move operation" do
      state = WindowManipulation.new()

      {new_state, response} =
        WindowManipulation.process_sequence(state, "\e[3;10;3t")

      assert new_state.position == {10, 3}
      assert response == ""
    end

    test ~c"handles window resize operation" do
      state = WindowManipulation.new()

      {new_state, response} =
        WindowManipulation.process_sequence(state, "\e[8;30;100t")

      assert new_state.size == {100, 30}
      assert response == ""
    end

    test ~c"handles window maximize operation" do
      state = WindowManipulation.new()

      {new_state, response} =
        WindowManipulation.process_sequence(state, "\e[9;1t")

      assert new_state.size == {100, 50}
      assert response == ""
    end

    test ~c"handles window restore operation" do
      state = %{WindowManipulation.new() | size: {100, 50}}

      {new_state, response} =
        WindowManipulation.process_sequence(state, "\e[9;0t")

      assert new_state.size == {80, 24}
      assert response == ""
    end

    test ~c"handles window raise operation" do
      state = WindowManipulation.new()

      {new_state, response} =
        WindowManipulation.process_sequence(state, "\e[5t")

      assert new_state.stacking_order == :above
      assert response == ""
    end

    test ~c"handles window lower operation" do
      state = WindowManipulation.new()

      {new_state, response} =
        WindowManipulation.process_sequence(state, "\e[6t")

      assert new_state.stacking_order == :below
      assert response == ""
    end

    test ~c"handles window title setting" do
      state = WindowManipulation.new()

      {new_state, response} =
        WindowManipulation.process_sequence(state, "\e]0;New Title\a")

      assert new_state.title == "New Title"
      assert response == ""
    end

    test ~c"handles window icon setting" do
      state = WindowManipulation.new()

      {new_state, response} =
        WindowManipulation.process_sequence(state, "\e]1;New Icon\a")

      assert new_state.icon_name == "New Icon"
      assert response == ""
    end

    test ~c"handles window size report request" do
      state = WindowManipulation.new()

      {new_state, response} =
        WindowManipulation.process_sequence(state, "\e[18t")

      assert new_state == state
      assert response == "\e[8;24;80t"
    end

    test ~c"handles window position report request" do
      state = WindowManipulation.new()

      {new_state, response} =
        WindowManipulation.process_sequence(state, "\e[13t")

      assert new_state == state
      assert response == "\e[3;0;0t"
    end

    test ~c"handles invalid sequences gracefully" do
      state = WindowManipulation.new()

      {new_state, response} =
        WindowManipulation.process_sequence(state, "\e[999t")

      assert new_state == state
      assert response == ""
    end
  end
end
