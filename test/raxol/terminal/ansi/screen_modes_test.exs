defmodule Raxol.Terminal.ANSI.ScreenModesTest do
  use ExUnit.Case
  alias Raxol.Terminal.ANSI.ScreenModes

  describe "new/0" do
    test "creates a new screen mode state with default values" do
      state = ScreenModes.new()
      assert state.mode == :normal
      assert state.saved_state == nil
      assert state.auto_wrap == true
      assert state.insert_mode == false
      assert state.origin_mode == false
      assert state.cursor_visible == true
      assert state.line_feed_mode == false
      assert state.column_width_mode == :normal
      assert state.auto_repeat_mode == false
      assert state.interlacing_mode == false
    end
  end

  describe "switch_mode/2" do
    test "switches from normal to alternate mode" do
      state = ScreenModes.new()

      new_state =
        ScreenModes.switch_mode(state, :alternate)

      assert new_state.mode == :alternate
      assert is_map(new_state.saved_state)
      assert new_state.saved_state[:auto_wrap] == true
    end

    test "switches from alternate to normal mode" do
      state = ScreenModes.new()
      state = %{state | mode: :alternate, saved_state: %{origin_mode: true}}

      new_state =
        ScreenModes.switch_mode(state, :normal)

      assert new_state.mode == :normal
      assert new_state.saved_state == nil
      assert new_state.origin_mode == true
    end

    test "returns same state when switching to current mode" do
      state = ScreenModes.new()

      new_state =
        ScreenModes.switch_mode(state, :normal)

      assert new_state == state
    end

    @tag :skip
    test "restores saved state flags when switching back" do
      state = ScreenModes.new()
      state = ScreenModes.set_mode(state, :origin_mode)
      state = ScreenModes.switch_mode(state, :alternate)
      state = ScreenModes.reset_mode(state, :origin_mode)

      state =
        ScreenModes.switch_mode(state, :normal)

      assert state.mode == :normal
      assert state.origin_mode == true
    end
  end

  describe "set_mode/2" do
    test "sets various screen modes" do
      state = ScreenModes.new()
      state = ScreenModes.set_mode(state, :insert_mode)
      assert state.insert_mode == true

      state = ScreenModes.set_mode(state, :origin_mode)
      assert state.origin_mode == true

      state = ScreenModes.set_mode(state, :auto_wrap)
      assert state.auto_wrap == true
      state = ScreenModes.set_mode(state, :wide_column)
      assert state.column_width_mode == :wide
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

      state = %{
        state
        | insert_mode: true,
          origin_mode: true,
          auto_wrap: false
      }

      state = ScreenModes.reset_mode(state, :insert_mode)
      assert state.insert_mode == false

      state = ScreenModes.reset_mode(state, :origin_mode)
      assert state.origin_mode == false

      state = ScreenModes.reset_mode(state, :auto_wrap)
      assert state.auto_wrap == false
      state = %{state | column_width_mode: :wide}
      state = ScreenModes.reset_mode(state, :wide_column)
      assert state.column_width_mode == :normal
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

      state = ScreenModes.switch_mode(state, :alternate)
      assert ScreenModes.get_mode(state) == :alternate
    end
  end

  describe "mode_enabled?/2" do
    test "checks if specific modes are enabled" do
      state = ScreenModes.new()
      assert ScreenModes.mode_enabled?(state, :auto_wrap) == true
      assert ScreenModes.mode_enabled?(state, :insert_mode) == false
      assert ScreenModes.mode_enabled?(state, :cursor_visible) == true
      assert ScreenModes.mode_enabled?(state, :wide_column) == false
    end

    test "returns false for unknown modes" do
      state = ScreenModes.new()
      assert ScreenModes.mode_enabled?(state, :unknown_mode) == false
    end
  end
end
