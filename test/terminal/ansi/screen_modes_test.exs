defmodule Raxol.Terminal.ANSI.ScreenModesTest do
  use ExUnit.Case
  alias Raxol.Terminal.ANSI.ScreenModes

  describe "column width mode" do
    test "default column width mode is normal" do
      state = ScreenModes.new()
      assert ScreenModes.get_column_width_mode(state) == :normal
    end

    test "set_mode with :wide_column sets column width mode to wide" do
      state = ScreenModes.new()
      new_state = ScreenModes.set_mode(state, :wide_column)
      assert ScreenModes.get_column_width_mode(new_state) == :wide
    end

    test "reset_mode with :wide_column sets column width mode to normal" do
      state = ScreenModes.new()
      state = ScreenModes.set_mode(state, :wide_column)
      new_state = ScreenModes.reset_mode(state, :wide_column)
      assert ScreenModes.get_column_width_mode(new_state) == :normal
    end

    test "mode_enabled? with :wide_column returns true when wide column mode is enabled" do
      state = ScreenModes.new()
      state = ScreenModes.set_mode(state, :wide_column)
      assert ScreenModes.mode_enabled?(state, :wide_column) == true
    end

    test "mode_enabled? with :wide_column returns false when wide column mode is disabled" do
      state = ScreenModes.new()
      assert ScreenModes.mode_enabled?(state, :wide_column) == false
    end

    test "column width mode is saved and restored when switching screen modes" do
      state = ScreenModes.new()
      state = ScreenModes.set_mode(state, :wide_column)

      # Switch to alternate mode (saves state)
      state = ScreenModes.switch_mode(state, :alternate)
      assert ScreenModes.get_column_width_mode(state) == :wide

      # Switch back to normal mode (restores state)
      state = ScreenModes.switch_mode(state, :normal)
      assert ScreenModes.get_column_width_mode(state) == :wide
    end
  end
end
