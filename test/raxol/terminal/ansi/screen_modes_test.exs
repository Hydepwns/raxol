defmodule Raxol.Terminal.ANSI.ScreenModesTest do
  use ExUnit.Case
  alias Raxol.Terminal.ANSI.ScreenModes

  describe "new/0" do
    test "creates a new screen mode state with default values" do
      state = ScreenModes.new()
      assert state.current_mode == :normal
      assert state.saved_normal_state == nil
      assert state.saved_alternate_state == nil
      assert state.line_wrap == true
      assert state.insert_mode == false
      assert state.origin_mode == false
      assert state.auto_wrap == true
      assert state.cursor_visible == true
      assert state.reverse_video == false
      assert state.application_keypad == false
      assert state.application_cursor == false
    end
  end

  describe "switch_mode/3" do
    test "switches from normal to alternate mode" do
      state = ScreenModes.new()
      current_buffer = %{cells: %{{0, 0} => "test"}, cursor: {0, 0}}
      {new_state, new_buffer} = ScreenModes.switch_mode(state, :alternate, current_buffer)

      assert new_state.current_mode == :alternate
      assert new_state.saved_normal_state == current_buffer
      assert new_buffer.cells == %{}
      assert new_buffer.cursor == {0, 0}
    end

    test "switches from alternate to normal mode" do
      state = ScreenModes.new()
      state = %{state | current_mode: :alternate}
      current_buffer = %{cells: %{{0, 0} => "test"}, cursor: {0, 0}}
      {new_state, new_buffer} = ScreenModes.switch_mode(state, :normal, current_buffer)

      assert new_state.current_mode == :normal
      assert new_state.saved_alternate_state == current_buffer
      assert new_buffer.cells == %{}
      assert new_buffer.cursor == {0, 0}
    end

    test "returns same state and buffer when switching to current mode" do
      state = ScreenModes.new()
      current_buffer = %{cells: %{{0, 0} => "test"}, cursor: {0, 0}}
      {new_state, new_buffer} = ScreenModes.switch_mode(state, :normal, current_buffer)

      assert new_state == state
      assert new_buffer == current_buffer
    end

    test "restores saved state when switching back" do
      state = ScreenModes.new()
      normal_buffer = %{cells: %{{0, 0} => "normal"}, cursor: {0, 0}}
      {state, _} = ScreenModes.switch_mode(state, :alternate, normal_buffer)
      alternate_buffer = %{cells: %{{0, 0} => "alternate"}, cursor: {1, 1}}
      {state, buffer} = ScreenModes.switch_mode(state, :normal, alternate_buffer)

      assert state.current_mode == :normal
      assert buffer == normal_buffer
    end
  end

  describe "set_mode/2" do
    test "sets various screen modes" do
      state = ScreenModes.new()
      state = ScreenModes.set_mode(state, :insert_mode)
      assert state.insert_mode == true

      state = ScreenModes.set_mode(state, :origin_mode)
      assert state.origin_mode == true

      state = ScreenModes.set_mode(state, :application_cursor)
      assert state.application_cursor == true
    end

    test "ignores unknown modes" do
      state = ScreenModes.new()
      new_state = ScreenModes.set_mode(state, :unknown_mode)
      assert new_state == state
    end
  end

  describe "reset_mode/2" do
    test "resets various screen modes" do
      state = ScreenModes.new()
      state = %{state | insert_mode: true, origin_mode: true, application_cursor: true}

      state = ScreenModes.reset_mode(state, :insert_mode)
      assert state.insert_mode == false

      state = ScreenModes.reset_mode(state, :origin_mode)
      assert state.origin_mode == false

      state = ScreenModes.reset_mode(state, :application_cursor)
      assert state.application_cursor == false
    end

    test "ignores unknown modes" do
      state = ScreenModes.new()
      new_state = ScreenModes.reset_mode(state, :unknown_mode)
      assert new_state == state
    end
  end

  describe "get_mode/1" do
    test "returns current screen mode" do
      state = ScreenModes.new()
      assert ScreenModes.get_mode(state) == :normal

      {state, _} = ScreenModes.switch_mode(state, :alternate, %{})
      assert ScreenModes.get_mode(state) == :alternate
    end
  end

  describe "mode_enabled?/2" do
    test "checks if specific modes are enabled" do
      state = ScreenModes.new()
      assert ScreenModes.mode_enabled?(state, :line_wrap) == true
      assert ScreenModes.mode_enabled?(state, :insert_mode) == false
      assert ScreenModes.mode_enabled?(state, :auto_wrap) == true
      assert ScreenModes.mode_enabled?(state, :cursor_visible) == true
    end

    test "returns false for unknown modes" do
      state = ScreenModes.new()
      assert ScreenModes.mode_enabled?(state, :unknown_mode) == false
    end
  end
end 